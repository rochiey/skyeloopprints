import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SessionFileService {
  Future<Directory> sessionDirectory(String sessionId) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'sessions', sessionId));
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> saveFinalImage(String sessionId, Uint8List bytes) async {
    final directory = await sessionDirectory(sessionId);
    final file = File(p.join(directory.path, 'final.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> cleanupOldSessions() async {
    final root = await getApplicationSupportDirectory();
    final sessions = Directory(p.join(root.path, 'sessions'));
    if (!await sessions.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in sessions.list()) {
      if (entity is! Directory) continue;
      final modified = await entity.stat().then((value) => value.modified);
      if (modified.isBefore(cutoff)) await entity.delete(recursive: true);
    }
  }
}

