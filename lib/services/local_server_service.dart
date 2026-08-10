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

