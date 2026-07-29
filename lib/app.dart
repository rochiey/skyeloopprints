import 'package:flutter/material.dart';

import 'screens/production/tap_to_start_screen.dart';
import 'state/app_controller.dart';
import 'theme/skyeloop_theme.dart';

class SkyeLoopApp extends StatelessWidget {
  const SkyeLoopApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'SkyeLoop',
        debugShowCheckedModeBanner: false,
        theme: buildSkyeLoopTheme(),
        home: const TapToStartScreen(),
      ),
    );
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context, {bool listen = true}) {
    if (!listen) {
      final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
      return (element!.widget as AppScope).notifier!;
    }
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}

