import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class LocalShare {
  const LocalShare({required this.url, required this.address});

  final String url;
  final String address;
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

    final address = await _findLanAddress();
    if (address == null) return null;
    return LocalShare(
      address: address,
      url: 'http://$address:8080/$sessionId',
    );
  }

  Response _page(Request request, String id) {
    if (id != _sessionId || _imageBytes == null) {
      return Response.notFound('This SkyeLoop photo is no longer available.');
    }
    final safeId = Uri.encodeComponent(id);
    return Response.ok(
      '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Your SkyeLoop photo</title><style>
body{margin:0;background:#f8efe5;color:#33210e;font-family:system-ui;text-align:center}
main{max-width:680px;margin:auto;padding:24px}img{width:100%;border-radius:20px;box-shadow:0 12px 40px #33210e33}
a{display:inline-block;margin:24px;padding:16px 28px;background:#09549b;color:white;text-decoration:none;border-radius:16px;font-weight:700}
</style></head><body><main><h1>Your SkyeLoop moment</h1>
<img src="/$safeId/photo.png" alt="Your photo"><br>
<a href="/$safeId/photo.png" download="skyeloop-photo.png">Save photo</a>
<p>Keep this page open until your download finishes.</p></main></body></html>''',
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

  Future<String?> _findLanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final candidates = interfaces
        .expand((interface) => interface.addresses)
        .map((address) => address.address)
        .where((address) => !address.startsWith('169.254.'))
        .toList();
    if (candidates.isEmpty) return null;
    return candidates.firstWhere(
      (address) => address.startsWith('192.168.') || address.startsWith('10.'),
      orElse: () => candidates.first,
    );
  }

  Future<void> stop() async {
    _imageBytes = null;
    _sessionId = null;
    await _server?.close(force: true);
    _server = null;
  }
}

