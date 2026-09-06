import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:skyeloop/services/paymongo_service.dart';

/// Fake http client that records requests and replays queued responses.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.responses);

  final List<http.Response> responses;
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  test('authHeader encodes the secret key with a trailing colon', () {
    expect(
      PaymongoService.authHeader('sk_test_abc'),
      base64Encode(utf8.encode('sk_test_abc:')),
    );
  });

  test('createGcashSource posts the GCash source and parses the checkout URL',
      () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'data': {
            'id': 'src_123',
            'type': 'source',
            'attributes': {
              'amount': 3000,
              'currency': 'PHP',
              'type': 'gcash',
              'status': 'pending',
              'redirect': {
                'checkout_url': 'https://payments.paymongo.com/checkout/abc',
                'success': 'https://paymongo.com/success',
                'failed': 'https://paymongo.com/failed',
              },
            },
          },
        }),
        200,
      ),
    ]);
    final service = PaymongoService(client: client);

    final source = await service.createGcashSource(amountCentavos: 3000);

    expect(source.id, 'src_123');
    expect(source.status, 'pending');
    expect(source.checkoutUrl, 'https://payments.paymongo.com/checkout/abc');
    expect(source.isChargeable, isFalse);

    final request = client.requests.single;
    expect(request.url.toString(), 'https://api.paymongo.com/v1/sources');
    expect(request.method, 'POST');
    expect(request.headers['Authorization'],
        'Basic ${PaymongoService.authHeader(PaymongoService.liveSecretKey)}');

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final attributes =
        body['data']['attributes'] as Map<String, dynamic>;
    expect(attributes['amount'], 3000);
    expect(attributes['currency'], 'PHP');
    expect(attributes['type'], 'gcash');
    expect((attributes['redirect'] as Map)['success'], isNotEmpty);
  });

  test('retrieveSource returns the latest chargeable status', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'data': {
            'id': 'src_123',
            'type': 'source',
            'attributes': {
              'amount': 2000,
              'status': 'chargeable',
              'redirect': {
                'checkout_url': 'https://payments.paymongo.com/checkout/abc',
              },
            },
          },
        }),
        200,
      ),
    ]);
    final service = PaymongoService(client: client);

    final source = await service.retrieveSource('src_123');

    expect(source.isChargeable, isTrue);
    expect(client.requests.single.url.toString(),
        'https://api.paymongo.com/v1/sources/src_123');
  });

  test('createGcashSource throws a descriptive error on HTTP failure',
      () async {
    final client = _FakeClient([
      http.Response('{"errors": []}', 401),
    ]);
    final service = PaymongoService(client: client);

    await expectLater(
      service.createGcashSource(amountCentavos: 1000),
      throwsA(isA<PaymongoException>()),
    );
  });
}
