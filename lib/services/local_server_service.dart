import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class LocalShare {
  const LocalShare({
    required this.url,
    required this.address,
    this.candidates = const [],
  });

  final String url;
  final String address;

  /// Every detected non-loopback IPv4, best (hotspot) first, for diagnostics.
  final List<String> candidates;
}

class LocalServerService {
  HttpServer? _server;
  Uint8List? _imageBytes;
  String? _sessionId;

  Future<LocalShare?> serve({
    required String sessionId,
    required Uint8List imageBytes,
  }) async {
    _imageBytes = imageBytes;
    _sessionId = sessionId;
    await _server?.close(force: true);

    final router = Router()
      ..get('/<id>', _page)
      ..get('/<id>/photo.png', _photo);
    try {
      // anyIPv4 + shared: answer on every interface (hotspot, Wi‑Fi, Ethernet)
      // so the phone can reach the page no matter which network it is on.
      _server = await shelf_io.serve(
        const Pipeline()
            .addMiddleware(logRequests())
            .addHandler(router.call),
        InternetAddress.anyIPv4,
        8080,
        shared: true,
      );
    } on SocketException {
      return null;
    }

    final candidates = await _findLanAddresses();
    if (candidates.isEmpty) return null;
    return LocalShare(
      address: candidates.first,
      candidates: candidates,
      url: 'http://${candidates.first}:8080/$sessionId',
    );
  }

  Response _page(Request request, String id) {
    if (id != _sessionId || _imageBytes == null) {
      return Response.notFound('This SkyeLoop photo is no longer available.');
    }
    final safeId = Uri.encodeComponent(id);
    return Response.ok(
      buildDigitalCopyPageHtml(safeId),
      headers: {'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store'},
    );
  }

  Response _photo(Request request, String id) {
    if (id != _sessionId || _imageBytes == null) {
      return Response.notFound('Photo unavailable');
    }
    return Response.ok(
      _imageBytes!,
      headers: {
        'content-type': 'image/png',
        'content-disposition': 'inline; filename="skyeloop-photo.png"',
        'cache-control': 'no-store',
      },
    );
  }

  /// Collects every non-loopback IPv4 address, best (hotspot) first. Never
  /// throws: enumeration failures simply yield no candidates so the caller can
  /// show a friendly "no network" state.
  Future<List<String>> _findLanAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = interfaces
          .expand((interface) => interface.addresses)
          .map((address) => address.address);
      return rankLanAddresses(addresses);
    } catch (_) {
      return const [];
    }
  }

  Future<void> stop() async {
    _imageBytes = null;
    _sessionId = null;
    await _server?.close(force: true);
    _server = null;
  }
}

/// Renders the phone-facing digital-copy page.
///
/// iOS quirk: a plain `download` link makes Safari save to the Files app,
/// never the Photos gallery. The primary action therefore uses the Web Share
/// API (Level 2) with a File — on iOS the share sheet exposes "Save Image",
/// which writes straight to Photos; on Android it offers the share/save
/// sheet. The `download` link stays as a fallback for browsers without file
/// sharing (and is relabelled on iOS so users know where it lands), and the
/// hint text teaches the long-press path (iOS: "Save Image"; Android:
/// "Download image"), which respects the image's `content-disposition:
/// inline` header and already behaves correctly.
@visibleForTesting
String buildDigitalCopyPageHtml(String safeId) {
  return '''
<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta charset="utf-8">
<title>Your SkyeLoop photo</title>
<style>
body{margin:0;background:#f8efe5;color:#33210e;font-family:system-ui;text-align:center}
main{max-width:680px;margin:auto;padding:24px}
img{width:100%;border-radius:20px;box-shadow:0 12px 40px #33210e33;display:block}
.actions{display:flex;flex-wrap:wrap;gap:14px;justify-content:center;margin:24px 0 8px}
button,a.dl{font:inherit;font-weight:700;padding:16px 28px;border-radius:16px;text-decoration:none;border:none;cursor:pointer}
button{background:#09549b;color:white}
a.dl{background:#ffe7c2;color:#33210e}
.hint{color:#7a5a2e;font-size:15px;line-height:1.5}
</style></head><body><main>
<h1>Your SkyeLoop moment</h1>
<img id="photo" src="/$safeId/photo.png" alt="Your photo">
<div class="actions">
<button id="save" type="button">Save to Photos</button>
<a id="download" class="dl" href="/$safeId/photo.png" download="skyeloop-photo.png">Download file</a>
</div>
<p id="hint" class="hint"></p>
</main>
<script>
var photoUrl = '/$safeId/photo.png';
var photoFile = null;
var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
var isAndroid = /Android/i.test(navigator.userAgent);

// Pre-fetch the image as a File so navigator.share runs immediately inside
// the tap gesture (iOS is picky about that) and the sheet offers "Save Image".
fetch(photoUrl).then(function (res) { return res.blob(); }).then(function (blob) {
  photoFile = new File([blob], 'skyeloop-photo.png', { type: 'image/png' });
}).catch(function () {});

function hint(text) { document.getElementById('hint').textContent = text; }

function fallback() {
  hint(isIOS
    ? 'Touch and hold the photo above, then tap Save Image to add it to your Photos.'
    : 'Touch and hold the photo above, then tap Download image.');
}

function saveToPhotos() {
  if (photoFile && navigator.canShare && navigator.canShare({ files: [photoFile] })) {
    navigator.share({ files: [photoFile], title: 'Your SkyeLoop photo' })
      .catch(function (e) { if (e.name !== 'AbortError') { fallback(); } });
  } else {
    fallback();
  }
}

document.getElementById('save').addEventListener('click', saveToPhotos);

if (isIOS) {
  document.getElementById('download').textContent = 'Download file (goes to Files)';
  hint('Tap Save to Photos and choose Save Image, or touch and hold the photo and choose Save Image.');
} else if (isAndroid) {
  hint('Touch and hold the photo and choose Download image, or tap Save to Photos. Downloads appear in your gallery.');
} else {
  hint('Right-click or long-press the photo to save it, or use Download file.');
}
</script>
</body></html>''';
}

/// Ranks candidate IPv4 addresses for the digital-copy QR, best (hotspot) first:
/// Android/Samsung hotspot AP subnets, then other AP ranges, then other private
/// ranges, then anything else. Link-local (169.254.x) addresses are dropped.
@visibleForTesting
List<String> rankLanAddresses(Iterable<String> addresses) {
  int rank(String ip) {
    if (ip.startsWith('192.168.43.') ||
        ip.startsWith('192.168.44.') ||
        ip.startsWith('10.42.')) {
      return 0; // Android / Linux hotspot soft-AP subnet
    }
    if (ip.startsWith('192.168.')) return 1; // typical home / café router
    if (ip.startsWith('10.')) return 2;
    if (ip.startsWith('172.')) return 3;
    return 4;
  }

  final list = addresses.where((ip) => !ip.startsWith('169.254.')).toSet().toList();
  list.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.compareTo(b); // stable tie-break
  });
  return list;
}

