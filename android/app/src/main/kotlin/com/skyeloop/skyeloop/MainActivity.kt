package com.skyeloop.skyeloop

import android.Manifest
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val channelName = "com.skyeloop.kiosk/hardware"
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Long-lived Bluetooth socket, kept open across prints (see [getPrinterSocket]). */
    @Volatile
    private var printerSocketInstance: BluetoothSocket? = null
    private var printerSocketAddress: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEmulator" -> result.success(isProbablyEmulator())
                    "enterKioskMode" -> result.success(enterKioskMode())
                    "leaveKioskMode" -> result.success(leaveKioskMode())
                    "listBondedPrinters" -> listBondedPrinters(result)
                    "printImage" -> {
                        val pngBytes = call.argument<ByteArray>("pngBytes")
                        val address = call.argument<String>("address")
                        val copies = call.argument<Int>("copies") ?: 1
                        if (pngBytes == null || address.isNullOrBlank()) {
                            result.error("INVALID_JOB", "The print image or printer address is missing.", null)
                        } else {
                            printImage(address, pngBytes, copies.coerceIn(1, 2), result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun listBondedPrinters(result: MethodChannel.Result) {
        if (!hasBluetoothConnectPermission()) {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices, then try again.", null)
            return
        }
        try {
            val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val devices = manager.adapter?.bondedDevices.orEmpty().map { device ->
                mapOf("name" to (device.name ?: "Bluetooth device"), "address" to device.address)
            }.sortedBy { it["name"] }
            result.success(devices)
        } catch (error: Exception) {
            result.error("BLUETOOTH_LIST", error.message ?: "Could not read paired devices.", null)
        }
    }

    private fun printImage(
        address: String,
        pngBytes: ByteArray,
        copies: Int,
        result: MethodChannel.Result,
    ) {
        if (!hasBluetoothConnectPermission()) {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices, then retry printing.", null)
            return
        }
        ioExecutor.execute {
            try {
                val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
                    ?: throw IllegalArgumentException("The prepared print image is invalid.")
                val escPos = bitmapToEscPos(bitmap)
                var lastError: Exception? = null
                for (attempt in 0..1) {
                    try {
                        sendToPrinter(address, escPos, copies)
                        lastError = null
                        break
                    } catch (error: Exception) {
                        lastError = error
                        if (attempt == 0) Thread.sleep(900)
                    }
                }
                if (lastError != null) throw lastError as Exception
                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "PRINT_FAILED",
                        error.message ?: "The printer did not accept the job.",
                        null,
                    )
                }
            }
        }
    }

    @Suppress("MissingPermission")
    private fun sendToPrinter(address: String, rasterBytes: ByteArray, copies: Int) {
        val socket = getPrinterSocket(address)
        try {
            val output = socket.outputStream
            repeat(copies) {
                output.write(byteArrayOf(0x1B, 0x40)) // ESC @: reset parser + buffer
                writePaced(output, rasterBytes)
                output.write(byteArrayOf(0x0A, 0x0A, 0x0A)) // small gap between strips
                output.flush()
                Thread.sleep(350)
            }
            // Feed a tail buffer so the complete strip clears the tear bar before
            // the paper is cut. GS v 0 is the feed command this printer demonstrably
            // honors (it drives the images) and advances exactly one dot row per
            // raster row; blank bytes print nothing. ESC J is avoided because this
            // printer prints its raw bytes as text instead of feeding.
            writeTailFeed(output)
            output.flush()
            // Give the printer time to physically consume every byte before the
            // next job starts. If the link is torn down mid-stream, the printer is
            // left waiting for raster data and the next job's bytes get eaten as
            // image data, which prints as garbage until the paper runs out.
            Thread.sleep(1500)
        } catch (error: Exception) {
            dropPrinterSocket(socket)
            throw error
        }
    }

    /**
     * Returns a long-lived socket to the printer, connecting on first use and
     * reusing it for every print. Reconnecting for each print is unreliable on
     * this hardware: a torn-down link leaves buffered bytes / a half-open session
     * in the printer, and the next job's command stream desyncs — the printer then
     * prints raw bytes as text until the spool runs out. Keeping one connection
     * for the whole kiosk session avoids that entirely.
     */
    @Synchronized
    @Suppress("MissingPermission")
    private fun getPrinterSocket(address: String): BluetoothSocket {
        val held = printerSocketInstance
        if (held != null && held.isConnected && printerSocketAddress == address) {
            return held
        }
        closePrinterSocket(held)
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = manager.adapter ?: throw IllegalStateException("Bluetooth is not available on this tablet.")
        if (!adapter.isEnabled) throw IllegalStateException("Turn on Bluetooth and try again.")
        val device = adapter.getRemoteDevice(address)
        adapter.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
        socket.connect()
        // Let the printer's firmware finish bringing the link up before data flows.
        Thread.sleep(300)
        printerSocketInstance = socket
        printerSocketAddress = address
        return socket
    }

    @Synchronized
    private fun closePrinterSocket(socket: BluetoothSocket?) {
        if (socket == null) return
        runCatching { socket.close() }
        if (printerSocketInstance === socket) {
            printerSocketInstance = null
            printerSocketAddress = null
        }
    }

    private fun dropPrinterSocket(socket: BluetoothSocket) {
        if (printerSocketInstance === socket) closePrinterSocket(socket)
    }

    /**
     * Writes [bytes] in small chunks with a short pause between chunks. The
     * printer's receive buffer is tiny; a single large write overflows it, the
     * ESC/POS parser desyncs, and the printer spews image bytes as text (garbage)
     * while cutting the image off. Chunking keeps the parser in sync.
     */
    private fun writePaced(output: java.io.OutputStream, bytes: ByteArray) {
        val chunkSize = 4096
        var offset = 0
        while (offset < bytes.size) {
            val end = minOf(offset + chunkSize, bytes.size)
            output.write(bytes, offset, end - offset)
            output.flush()
            offset = end
            if (offset < bytes.size) Thread.sleep(8)
        }
    }

    /** Feeds [END_FEED_DOTS] dot rows of blank paper using banded GS v 0 rasters. */
    private fun writeTailFeed(output: java.io.OutputStream) {
        val bytesPerRow = PRINT_DOTS_WIDE / 8
        var remaining = END_FEED_DOTS
        while (remaining > 0) {
            val bandHeight = minOf(192, remaining)
            output.write(
                byteArrayOf(
                    0x1D, 0x76, 0x30, 0x00,
                    (bytesPerRow and 0xFF).toByte(),
                    ((bytesPerRow shr 8) and 0xFF).toByte(),
                    (bandHeight and 0xFF).toByte(),
                    ((bandHeight shr 8) and 0xFF).toByte(),
                ),
            )
            writePaced(output, ByteArray(bytesPerRow * bandHeight))
            remaining -= bandHeight
        }
    }

    private fun bitmapToEscPos(source: Bitmap): ByteArray {
        val targetWidth = PRINT_DOTS_WIDE
        val targetHeight = (source.height * (targetWidth.toDouble() / source.width))
            .roundToInt()
            .coerceAtLeast(1)
        val bitmap = Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
        val bytesPerRow = targetWidth / 8
        val output = ByteArrayOutputStream(bytesPerRow * targetHeight + 64)
        val pixels = IntArray(targetWidth * targetHeight)
        bitmap.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)

        // 1-bit grayscale halftone. Pipeline: luminance → (optional local contrast)
        // → tone curve (levels + shadow-lift gamma + ink-range cap) → error
        // diffusion. The tone curve is the key fix for "faces print too dark": it
        // lifts shadows out of solid black and keeps highlight/skin gradation
        // instead of clipping it to paper.
        val dithered = ByteArray(targetWidth * targetHeight) // 1 = black
        val luma = FloatArray(targetWidth * targetHeight)
        for (i in 0 until targetWidth * targetHeight) {
            val color = pixels[i]
            val alpha = color ushr 24 and 0xFF
            luma[i] = if (alpha > 32) {
                val red = color ushr 16 and 0xFF
                val green = color ushr 8 and 0xFF
                val blue = color and 0xFF
                ((red * 299 + green * 587 + blue * 114) / 1000).toFloat()
            } else {
                255f // transparent pixels print as paper
            }
        }
        // Optional local-contrast: a light 3×3 unsharp mask restores face detail
        // that 1-bit quantization flattens. Set PRINT_SHARPEN to 0 to disable.
        if (PRINT_SHARPEN > 0f) {
            val blurred = FloatArray(luma.size)
            for (y in 0 until targetHeight) {
                for (x in 0 until targetWidth) {
                    var sum = 0f
                    var count = 0
                    for (dy in -1..1) {
                        val ny = y + dy
                        if (ny !in 0 until targetHeight) continue
                        for (dx in -1..1) {
                            val nx = x + dx
                            if (nx in 0 until targetWidth) {
                                sum += luma[ny * targetWidth + nx]
                                count++
                            }
                        }
                    }
                    blurred[y * targetWidth + x] = sum / count
                }
            }
            for (i in luma.indices) {
                luma[i] = (luma[i] + PRINT_SHARPEN * (luma[i] - blurred[i])).coerceIn(0f, 255f)
            }
        }
        // Tone curve: input levels compression, shadow-lifting gamma, output ink cap.
        for (i in luma.indices) {
            var t = (luma[i] - INPUT_BLACK_POINT) / (INPUT_WHITE_POINT - INPUT_BLACK_POINT)
            t = t.coerceIn(0f, 1f)
            val lifted = Math.pow(t.toDouble(), 1.0 / PRINT_GAMMA.toDouble()).toFloat()
            luma[i] = PRINT_MIN_OUT + (PRINT_MAX_OUT - PRINT_MIN_OUT) * lifted
        }
        // Atkinson error diffusion: 1/8 of the error is pushed to six neighbors
        // (3/4 total diffused). It prints visibly lighter than Floyd–Steinberg with
        // open highlights and fine texture — the classic choice for 1-bit photos.
        val errors = FloatArray(targetWidth * targetHeight)
        for (y in 0 until targetHeight) {
            for (x in 0 until targetWidth) {
                val idx = y * targetWidth + x
                var value = luma[idx] + errors[idx]
                if (value >= 255f) value = 255f
                val black = value < PRINT_THRESHOLD
                if (black) dithered[idx] = 1
                val quantError = value - if (black) 0f else 255f
                val eighth = quantError / 8f
                if (x + 1 < targetWidth) errors[idx + 1] += eighth
                if (x + 2 < targetWidth) errors[idx + 2] += eighth
                if (y + 1 < targetHeight) {
                    if (x > 0) errors[idx + targetWidth - 1] += eighth
                    errors[idx + targetWidth] += eighth
                    if (x + 1 < targetWidth) errors[idx + targetWidth + 1] += eighth
                }
                if (y + 2 < targetHeight) errors[idx + 2 * targetWidth] += eighth
            }
        }

        var startY = 0
        while (startY < targetHeight) {
            val bandHeight = minOf(192, targetHeight - startY)
            output.write(
                byteArrayOf(
                    0x1D, 0x76, 0x30, 0x00,
                    (bytesPerRow and 0xFF).toByte(),
                    ((bytesPerRow shr 8) and 0xFF).toByte(),
                    (bandHeight and 0xFF).toByte(),
                    ((bandHeight shr 8) and 0xFF).toByte(),
                ),
            )
            for (y in startY until startY + bandHeight) {
                for (byteX in 0 until bytesPerRow) {
                    var packed = 0
                    for (bit in 0..7) {
                        val x = byteX * 8 + bit
                        if (dithered[y * targetWidth + x] == 1.toByte()) {
                            packed = packed or (1 shl (7 - bit))
                        }
                    }
                    output.write(packed)
                }
            }
            startY += bandHeight
        }
        if (bitmap !== source) bitmap.recycle()
        return output.toByteArray()
    }

    private fun enterKioskMode(): Boolean {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (isProbablyEmulator()) return false
        return try {
            val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            if (policy.isDeviceOwnerApp(packageName)) {
                policy.setLockTaskPackages(ComponentName(this, KioskDeviceAdminReceiver::class.java), arrayOf(packageName))
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE
            ) {
                startLockTask()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun leaveKioskMode(): Boolean = try {
        stopLockTask()
        true
    } catch (_: Exception) {
        false
    }

    private fun hasBluetoothConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun isProbablyEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("sdk_gphone") ||
            Build.MODEL.contains("Emulator") ||
            Build.MANUFACTURER.contains("Genymotion")

    override fun onDestroy() {
        closePrinterSocket(printerSocketInstance)
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        /** Printable dot width of the Vozy G80 (80 mm paper at 203 DPI). */
        private const val PRINT_DOTS_WIDE = 576

        /** sRGB input black/white points for the tone-curve levels compression. */
        private const val INPUT_BLACK_POINT = 25f
        private const val INPUT_WHITE_POINT = 235f

        /** Shadow-lifting gamma: output = input^(1/gamma), lightens midtones/shadows. */
        private const val PRINT_GAMMA = 1.8f

        /**
         * Output ink-range cap (dot-gain compensation): shadows map to ~90% ink,
         * highlights to ~4%, so thermal dot bleed can never fuse details into a
         * solid black field and whites never go fully solid.
         */
        private const val PRINT_MIN_OUT = 25f
        private const val PRINT_MAX_OUT = 245f

        /** Dithering threshold: pixels darker than this print as black. */
        private const val PRINT_THRESHOLD = 128f

        /** Local-contrast sharpen amount applied to luminance before dithering (0 = off). */
        private const val PRINT_SHARPEN = 0.3f

        /** Blank raster rows fed after the last copy (320 rows = 40 mm at 8 dots/mm). */
        private const val END_FEED_DOTS = 320
    }
}
