package com.skyeloop.skyeloop

import android.Manifest
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.bluetooth.BluetoothManager
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
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = manager.adapter ?: throw IllegalStateException("Bluetooth is not available on this tablet.")
        if (!adapter.isEnabled) throw IllegalStateException("Turn on Bluetooth and try again.")
        val device = adapter.getRemoteDevice(address)
        adapter.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
        try {
            socket.connect()
            val output = socket.outputStream
            repeat(copies) {
                output.write(byteArrayOf(0x1B, 0x40)) // ESC @: initialize
                output.write(rasterBytes)
                output.write(byteArrayOf(0x0A, 0x0A, 0x0A, 0x0A, 0x0A))
                output.flush()
                Thread.sleep(350)
            }
        } finally {
            runCatching { socket.close() }
        }
    }

    private fun bitmapToEscPos(source: Bitmap): ByteArray {
        val targetWidth = 576
        val targetHeight = (source.height * (targetWidth.toDouble() / source.width))
            .roundToInt()
            .coerceAtLeast(1)
        val bitmap = Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
        val bytesPerRow = targetWidth / 8
        val output = ByteArrayOutputStream(bytesPerRow * targetHeight + 64)
        val pixels = IntArray(targetWidth * targetHeight)
        bitmap.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)

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
                        val color = pixels[y * targetWidth + x]
                        val alpha = color ushr 24 and 0xFF
                        val red = color ushr 16 and 0xFF
                        val green = color ushr 8 and 0xFF
                        val blue = color and 0xFF
                        val luminance = (red * 299 + green * 587 + blue * 114) / 1000
                        val threshold = 96 + BAYER_4[y and 3][x and 3] * 8
                        if (alpha > 32 && luminance < threshold) packed = packed or (1 shl (7 - bit))
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
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private val BAYER_4 = arrayOf(
            intArrayOf(0, 8, 2, 10),
            intArrayOf(12, 4, 14, 6),
            intArrayOf(3, 11, 1, 9),
            intArrayOf(15, 7, 13, 5),
        )
    }
}
