import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import '../../models/pricing_tier.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final app = AppScope.of(context, listen: false);
    _venueController = TextEditingController(text: app.config.venueName);
  }

  @override
  void dispose() {
    _venueController.dispose();
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

  Future<void> _pickQr(PricingTier tier) async {
    await _withBusy(() async {
      final app = AppScope.of(context, listen: false);
      final path = await app.configService.chooseAndSaveImage('payment_${tier.storageKey}');
      if (path == null) return;
      await app.configService.setPaymentQrPath(tier, path);
      app.refreshConfig();
    });
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
                Text('Payment QR images', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Upload one static payment QR for each price. SkyeLoop does not verify payment.'),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 800 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final tier in PricingTier.values)
                          SizedBox(
                            width: width,
                            child: _QrConfigCard(
                              tier: tier,
                              imagePath: config.paymentQrPaths[tier],
                              onUpload: _busy ? null : () => _pickQr(tier),
                            ),
                          ),
                      ],
                    );
                  },
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

class _QrConfigCard extends StatelessWidget {
  const _QrConfigCard({required this.tier, required this.imagePath, required this.onUpload});

  final PricingTier tier;
  final String? imagePath;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('${tier.priceLabel} • ${tier.shotCount} photo${tier.shotCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: hasImage ? SkyeColors.blue : SkyeColors.rose, width: 2)),
                child: hasImage
                    ? ClipRRect(borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(imagePath!), fit: BoxFit.contain))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 72, color: SkyeColors.ink),
                          SizedBox(height: 8),
                          Text('Placeholder QR', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(onPressed: onUpload,
                icon: const Icon(Icons.upload_file_outlined), label: Text(hasImage ? 'Replace QR' : 'Upload QR')),
          ],
        ),
      ),
    );
  }
}

