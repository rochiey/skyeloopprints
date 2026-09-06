import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A GCash payment source created through the PayMongo Sources API.
class PaymongoSource {
  const PaymongoSource({
    required this.id,
    required this.status,
    this.checkoutUrl,
  });

  final String id;

  /// `pending`, `chargeable`, `failed`, etc. `chargeable` means paid.
  final String status;

  /// The GCash checkout URL to render as a QR code on the kiosk screen.
  final String? checkoutUrl;

  bool get isChargeable => status == 'chargeable';
  bool get isFailed => status == 'failed';
}

/// Thin client for the parts of the PayMongo Sources API used by the kiosk:
/// creating a GCash source and polling it until the customer pays.
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

  static const gcashRedirectSuccessUrl = 'https://paymongo.com/success';
  static const gcashRedirectFailedUrl = 'https://paymongo.com/failed';

  final http.Client _client;
  final String _baseUrl;
  final String publicKey;
  final String secretKey;

  /// Basic auth value for the secret key, per PayMongo's auth scheme
  /// (`base64(secret_key + ':')`).
  static String authHeader(String secretKey) =>
      base64Encode(utf8.encode('$secretKey:'));

  /// Creates a GCash source for [amountCentavos] and returns it, including
  /// the checkout URL that should be rendered as a QR code.
  Future<PaymongoSource> createGcashSource({
    required int amountCentavos,
    String description = 'SkyeLoop photobooth session',
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/sources'),
      headers: <String, String>{
        'Authorization': 'Basic ${authHeader(secretKey)}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'attributes': <String, dynamic>{
            'amount': amountCentavos,
            'currency': 'PHP',
            'type': 'gcash',
            'redirect': <String, String>{
              'success': gcashRedirectSuccessUrl,
              'failed': gcashRedirectFailedUrl,
            },
          },
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymongoException(
        'PayMongo rejected the payment request '
        '(HTTP ${response.statusCode}).',
        response.body,
      );
    }
    return parseSource(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches the latest status of a source. Poll this until
  /// [PaymongoSource.isChargeable].
  Future<PaymongoSource> retrieveSource(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/sources/$id'),
      headers: <String, String>{
        'Authorization': 'Basic ${authHeader(secretKey)}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymongoException(
        'Could not check the payment status (HTTP ${response.statusCode}).',
        response.body,
      );
    }
    return parseSource(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Parses a PayMongo source JSON envelope into a [PaymongoSource].
  static PaymongoSource parseSource(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as Map<String, dynamic>;
    final redirect = attributes['redirect'] as Map<String, dynamic>?;
    return PaymongoSource(
      id: data['id'] as String,
      status: attributes['status'] as String? ?? 'pending',
      checkoutUrl: redirect?['checkout_url'] as String?,
    );
  }
}

class PaymongoException implements Exception {
  PaymongoException(this.message, [this.details]);

  final String message;
  final String? details;

  @override
  String toString() =>
      details == null ? message : '$message\n$details';
}