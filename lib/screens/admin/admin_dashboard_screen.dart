import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import '../../models/upload_config.dart';
import '../../services/printer_service.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/brand_mark.dart';
import '../production/tap_to_start_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final TextEditingController _venueController;
  late final TextEditingController _uploadUrlController;
  late final TextEditingController _uploadTokenController;
  UploadConfig _uploadConfig = const UploadConfig();
  bool _busy = false;
  bool _uploadingNow = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    final app = AppScope.of(context, listen: false);
    _venueController = TextEditingController(text: app.config.venueName);
    _uploadConfig = app.configService.loadUploadConfig();
    _uploadUrlController = TextEditingController(text: _uploadConfig.apiBaseUrl);
    _uploadTokenController = TextEditingController(text: _uploadConfig.apiToken);
    _uploadStatus = app.uploadSchedulerService!.lastStatus;
    app.uploadSchedulerService!.addListener(_onSchedulerUpdate);
  }

  void _onSchedulerUpdate() {
    if (mounted) {
      final app = AppScope.of(context, listen: false);
      setState(() {
        _uploadStatus = app.uploadSchedulerService!.lastStatus;
      });
    }
  }

  @override
  void dispose() {
    _venueController.dispose();
    _uploadUrlController.dispose();
    _uploadTokenController.dispose();
    AppScope.of(context, listen: false)
        .uploadSchedulerService!.removeListener(_onSchedulerUpdate);
    super.dispose();
  }

  Future<void> _saveVenueName() async {
    final app = AppScope.of(context, listen: false);
    await app.configService.setVenueName(_venueController.text);
    app.refreshConfig();
    _message('Venue name saved.');
  }

  Future<void> _pickBranding() async {
    await _withBusy(() async {
      final app = AppScope.of(context, listen: false);
      final path = await app.configService.chooseAndSaveImage('branding');
      if (path == null) return;
      await app.configService.setBrandingPath(path);
      app.refreshConfig();
    });
  }

  Future<void> _setPaymentTestMode(bool testMode) async {
    final app = AppScope.of(context, listen: false);
    await app.configService.setPaymentTestMode(testMode);
    app.refreshConfig();
    _message(testMode
        ? 'Test mode on: PayMongo QR payments are bypassed.'
        : 'Live mode on: customers must pay through the GCash QR.');
  }

  Future<void> _choosePrinter() async {
    final app = AppScope.of(context, listen: false);
    if (await app.printerService.isEmulator) {
      _message('The emulator uses SkyeLoop\'s simulated printer. Pair the real printer in Android Settings later.');
      return;
    }
    await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    try {
      final printers = await app.printerService.listBondedPrinters();
      if (!mounted) return;
      final selected = await showDialog<BondedPrinter>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select paired printer'),
          content: SizedBox(
            width: 420,
            child: printers.isEmpty
                ? const Text('No paired Bluetooth devices found. Pair the printer in Android Settings first.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: printers.length,
                    itemBuilder: (_, index) {
                      final printer = printers[index];
                      return ListTile(
                        leading: const Icon(Icons.print_outlined),
                        title: Text(printer.name),
                        subtitle: Text(printer.address),
                        onTap: () => Navigator.pop(context, printer),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        ),
      );
      if (selected == null) return;
      await app.configService.setPrinter(address: selected.address, name: selected.name);
      app.refreshConfig();
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not read paired Bluetooth devices.');
    }
  }

  Future<void> _changePassword() async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change admin password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: first, obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
            TextField(controller: second, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (first.text.length < 6 || first.text != second.text) return;
              Navigator.pop(context, first.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    if (result == null || !mounted) return;
    await AppScope.of(context, listen: false).configService.setPassword(result);
    _message('Password changed.');
  }

  Future<void> _saveUploadConfig() async {
    final app = AppScope.of(context, listen: false);
    final config = _uploadConfig.copyWith(
      apiBaseUrl: _uploadUrlController.text.trim(),
      apiToken: _uploadTokenController.text.trim(),
    );
    await app.configService.saveUploadConfig(config);
    _uploadConfig = config;
    app.uploadSchedulerService!.onConfigChanged(config);
    _message('Upload settings saved.');
  }

  Future<void> _pickUploadTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _uploadConfig.scheduledHour,
        minute: _uploadConfig.scheduledMinute,
      ),
      helpText: 'Select daily upload time',
    );
    if (time == null || !mounted) return;
    setState(() {
      _uploadConfig = _uploadConfig.copyWith(
        scheduledHour: time.hour,
        scheduledMinute: time.minute,
      );
    });
    await _saveUploadConfig();
  }

  Future<void> _triggerManualUpload() async {
    final app = AppScope.of(context, listen: false);
    setState(() => _uploadingNow = true);
    await app.uploadSchedulerService!.triggerManualUpload();
    if (mounted) {
      setState(() {
        _uploadingNow = false;
        _uploadStatus = app.uploadSchedulerService!.lastStatus;
      });
    }
  }

  Future<void> _exitAdmin() async {
    final app = AppScope.of(context, listen: false);
    app.refreshConfig();
    await app.printerService.enterKioskMode();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TapToStartScreen()),
      (_) => false,
    );
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SkyeLoop Admin'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: _exitAdmin,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Return to kiosk'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Text('Venue setup', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('Changes apply when the next customer session begins.'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BrandMark(imagePath: config.brandingPath, size: 150),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Branding', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _venueController,
                                decoration: const InputDecoration(
                                  labelText: 'Venue or kiosk name',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _saveVenueName(),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: _busy ? null : _pickBranding,
                                    icon: const Icon(Icons.image_outlined),
                                    label: const Text('Upload logo/background'),
                                  ),
                                  OutlinedButton(onPressed: _saveVenueName, child: const Text('Save name')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Payments (PayMongo)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                    'Customers pay with GCash. SkyeLoop asks PayMongo for a QR on the '
                    'spot and only starts the session after PayMongo confirms the payment. '
                    'No QR images need to be uploaded.'),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment mode', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('Test mode'),
                              icon: Icon(Icons.science_outlined),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Live'),
                              icon: Icon(Icons.verified_outlined),
                            ),
                          ],
                          selected: {config.paymentTestMode},
                          onSelectionChanged: (selection) =>
                              _setPaymentTestMode(selection.first),
                          showSelectedIcon: false,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: config.paymentTestMode
                                ? SkyeColors.amber.withValues(alpha: .18)
                                : Colors.green.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                config.paymentTestMode
                                    ? Icons.science_outlined
                                    : Icons.verified_outlined,
                                color: config.paymentTestMode ? Colors.brown : Colors.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  config.paymentTestMode
                                      ? 'TEST MODE — the PayMongo QR is bypassed so you can '
                                          'test the camera and image previews without paying. '
                                          'Turn this off before going live.'
                                      : 'LIVE — customers scan a GCash QR generated by PayMongo '
                                          'and the session starts only after payment is confirmed.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const CircleAvatar(backgroundColor: SkyeColors.mist, child: Icon(Icons.print_outlined)),
                    title: const Text('80 mm Bluetooth printer', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(config.printerName == null
                        ? 'No physical printer selected. Emulator printing is simulated.'
                        : '${config.printerName}\n${config.printerAddress}'),
                    isThreeLine: config.printerName != null,
                    trailing: FilledButton.tonal(onPressed: _choosePrinter, child: const Text('Choose paired device')),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const CircleAvatar(backgroundColor: SkyeColors.mist, child: Icon(Icons.password_outlined)),
                    title: const Text('Admin password', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Stored as a salted hash on this tablet.'),
                    trailing: OutlinedButton(onPressed: _changePassword, child: const Text('Change password')),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Auto sales upload', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Sends completed session data to your server daily. Only uploads over Wi‑Fi.'),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Enable auto-upload',
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            Switch(
                              value: _uploadConfig.autoUploadEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _uploadConfig = _uploadConfig.copyWith(
                                      autoUploadEnabled: value);
                                });
                                _saveUploadConfig();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _uploadUrlController,
                          decoration: const InputDecoration(
                            labelText: 'API base URL',
                            hintText: 'https://your-server.com',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _uploadTokenController,
                          decoration: const InputDecoration(
                            labelText: 'API auth token (optional)',
                            hintText: 'Bearer token',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key),
                          ),
                          obscureText: true,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickUploadTime,
                              icon: const Icon(Icons.schedule),
                              label: Text('Schedule: ${_uploadConfig.scheduledTimeLabel}'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _saveUploadConfig,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _uploadStatus.isNotEmpty ? _uploadStatus : 'No uploads yet today.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: SkyeColors.ink.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: (_busy || _uploadingNow) ? null : _triggerManualUpload,
                              icon: _uploadingNow
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(_uploadingNow ? 'Uploading…' : 'Upload now'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(child: FilledButton.icon(onPressed: _exitAdmin,
                    icon: const Icon(Icons.check_circle_outline), label: const Text('Save and return to kiosk'))),
                const SizedBox(height: 32),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}



