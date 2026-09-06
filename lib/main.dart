import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Missing or unreadable .env: still boot the kiosk, but PayMongo
    // payments will fail until the keys are provided (see .env.example).
  }
  final controller = AppController();
  await controller.initialize();
  runApp(SkyeLoopApp(controller: controller));
}

