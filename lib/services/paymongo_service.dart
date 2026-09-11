import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A dynamic QR Ph payment created through PayMongo's Payment Intent API.
class PaymongoQrPayment {
  const PaymongoQrPayment({
    required this.intentId,
    required this.status,
    this.qrImageBytes,
  });

  final String intentId;

  /// `awaiting_payment_method`, `awaiting_next_action` (QR ready to scan),
  /// `processing` (customer paid, settling), `succeeded` (paid), or a
  /// failure state. `succeeded` is the only state that unlocks the session.
  final String status;

  /// The PNG bytes of the QR Ph code (decoded from PayMongo's base64 data
  /// URI). Only present once the QR is ready to scan.
  final Uint8List? qrImageBytes;

  bool get isSucceeded => status == 'succeeded';
  bool get hasQrImage => qrImageBytes != null && qrImageBytes!.isNotEmpty;
}

/// Client for the PayMongo APIs used by the kiosk to accept QR Ph payments:
///
/// 1. [createQrPhPayment] — creates a Payment Intent (secret key), a `qrph`
///    payment method (public key) and attaches the two. The attach response
///    carries the QR Ph image as a base64 PNG data URI.
/// 2. [retrievePayment] — polls the intent until it is `succeeded`.
///
/// QR Ph is free on PayMongo and scannable by any PH bank / e-wallet app
/// (GCash, Maya, and more). A GCash Sources/checkout QR is GCash-only and
/// requires the e-wallet to be enabled on the organization, which is why the
/// kiosk uses the bank-agnostic QR Ph flow instead.
class PaymongoService {
  PaymongoService({
    http.Client? client,
    String? publicKey,
    String? secretKey,
    String baseUrl = 'https://api.paymongo.com/v1',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        publicKey = publicKey ?? livePublicKey,
        secretKey = secretKey ?? liveSecretKey;

  /// PayMongo account keys, loaded from the git-ignored `.env` file at
  /// startup (see `.env.example` for the expected variable names). They are
  /// intentionally NOT hard-coded here so they never get committed.
  static String get livePublicKey => _envValue('PAYMONGO_PUBLIC_KEY');
  static String get liveSecretKey => _envValue('PAYMONGO_SECRET_KEY');

  /// Reads [name] from the loaded .env file, or '' when dotenv has not been
  /// initialized yet (e.g. in unit tests).
  static String _envValue(String name) {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(name, fallback: '') ?? '';
  }

  final http.Client _client;
  final String _baseUrl;
  final String publicKey;
  final String secretKey;

  /// Basic auth value per PayMongo's auth scheme (`base64(key + ':')`).
  static String authHeader(String apiKey) =>
      base64Encode(utf8.encode('$apiKey:'));

  /// Creates a dynamic QR Ph payment for [amountCentavos]. Returns the
  /// payment with its [PaymongoQrPayment.qrImageBytes] ready to display.
  Future<PaymongoQrPayment> createQrPhPayment({
    required int amountCentavos,
    String description = 'SkyeLoop photobooth session',
  }) async {
    _requireKeys();

    // 1. Payment Intent (secret key).
    final intent = _parseEnvelope(await _post(
      '/payment_intents',
      auth: authHeader(secretKey),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'attributes': <String, dynamic>{
            'amount': amountCentavos,
            'currency': 'PHP',
            'payment_method_allowed': <String>['qrph'],
            'description': description,
          },
        },
      },
    ));
    final intentId = intent['id'] as String;
    final intentAttributes = intent['attributes'] as Map<String, dynamic>;
    final clientKey = intentAttributes['client_key'] as String;

    // 2. QR Ph payment method (public key).
    final paymentMethod = _parseEnvelope(await _post(
      '/payment_methods',
      auth: authHeader(publicKey),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'attributes': <String, dynamic>{'type': 'qrph'},
        },
      },
    ));

    // 3. Attach: the response carries the QR image in next_action.
    final attached = _parseEnvelope(await _post(
      '/payment_intents/$intentId/attach',
      auth: authHeader(publicKey),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'attributes': <String, dynamic>{
            'payment_method': paymentMethod['id'] as String,
            'client_key': clientKey,
          },
        },
      },
    ));
    return _paymentFromEnvelope(attached, intentId);
  }

  /// Fetches the latest status of a payment intent. Poll this until
  /// [PaymongoQrPayment.isSucceeded].
  Future<PaymongoQrPayment> retrievePayment(String intentId) async {
    _requireKeys();
    final response = await _client.get(
      Uri.parse('$_baseUrl/payment_intents/$intentId'),
      headers: <String, String>{
        'Authorization': 'Basic ${authHeader(secretKey)}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymongoException.fromResponse(
        'Could not check the payment status',
        response.statusCode,
        response.body,
      );
    }
    return _paymentFromEnvelope(
      _parseEnvelope(jsonDecode(response.body) as Map<String, dynamic>),
      intentId,
    );
  }

  /// POSTs [body] to [path] and returns the raw decoded response body.
  /// Callers unwrap the `data` envelope themselves through [_parseEnvelope].
  Future<Map<String, dynamic>> _post(
    String path, {
    required String auth,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: <String, String>{
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymongoException.fromResponse(
        'PayMongo rejected the payment request',
        response.statusCode,
        response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _parseEnvelope(Map<String, dynamic> body) =>
      body['data'] as Map<String, dynamic>;

  PaymongoQrPayment _paymentFromEnvelope(
    Map<String, dynamic> data,
    String fallbackId,
  ) {
    final attributes = data['attributes'] as Map<String, dynamic>;
    final nextAction = attributes['next_action'] as Map<String, dynamic>?;
    final code = nextAction?['code'] as Map<String, dynamic>?;
    return PaymongoQrPayment(
      intentId: (data['id'] as String?) ?? fallbackId,
      status: attributes['status'] as String? ?? 'awaiting_payment_method',
      qrImageBytes: _decodeQrImage(code?['image_url'] as String?),
    );
  }

  /// Decodes `next_action.code.image_url` — a base64 PNG data URI such as
  /// `data:image/png;base64,iVBORw0...` — into raw image bytes. Returns null
  /// (instead of throwing) when no image is present or it cannot be decoded.
  static Uint8List? _decodeQrImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final payload = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
    try {
      final bytes = base64Decode(payload);
      return bytes.isEmpty ? null : bytes;
    } on FormatException {
      return null;
    }
  }

  /// The QR Ph flow needs the public key (payment method + attach) and the
  /// secret key (payment intent + status polling). Fail fast with a readable
  /// message when the `.env` keys were not loaded.
  void _requireKeys() {
    if (publicKey.isEmpty || secretKey.isEmpty) {
      throw PaymongoException(
        'PayMongo API keys are missing. Add PAYMONGO_PUBLIC_KEY and '
        'PAYMONGO_SECRET_KEY to the .env file (see .env.example).',
      );
    }
  }
}

class PaymongoException implements Exception {
  PaymongoException(this.message, [this.details]);

  /// Builds an exception from a PayMongo error response. PayMongo returns
  /// `{"errors": [{"code": "...", "detail": "..."}]}` — the human-readable
  /// `detail` is surfaced so problems like "organization is not allowed to
  /// process X payments" are visible instead of a generic network error.
  factory PaymongoException.fromResponse(
    String prefix,
    int statusCode,
    String body,
  ) {
    var details = '';
    try {
      final decoded = jsonDecode(body);
      final errors = decoded is Map<String, dynamic>
          ? decoded['errors'] as List<dynamic>?
          : null;
      if (errors != null && errors.isNotEmpty) {
        final messages = <String>[];
        for (final error in errors) {
          if (error is Map<String, dynamic>) {
            final detail = error['detail'];
            final code = error['code'];
            messages.add(code == null ? '$detail' : '[$code] $detail');
          }
        }
        if (messages.isNotEmpty) details = messages.join('; ');
      }
    } catch (_) {
      // Keep the plain HTTP status if the body is not parseable.
    }
    return PaymongoException(
      '$prefix (HTTP $statusCode).',
      details.isEmpty ? null : details,
    );
  }

  final String message;
  final String? details;

  @override
  String toString() => details == null ? message : '$message $details';
}