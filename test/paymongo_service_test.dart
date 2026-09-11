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

/// Wraps [data] in PayMongo's `{"data": ...}` response envelope.
String _envelope(Map<String, dynamic> data) => jsonEncode({'data': data});

void main() {
  test('authHeader encodes the API key with a trailing colon', () {
    expect(
      PaymongoService.authHeader('sk_test_abc'),
      base64Encode(utf8.encode('sk_test_abc:')),
    );
  });

  test('createQrPhPayment runs the QR Ph payment intent flow', () async {
    final qrBytes = <int>[1, 2, 3, 4];
    final client = _FakeClient([
      // 1. Payment Intent.
      http.Response(
        _envelope({
          'id': 'pi_123',
          'type': 'payment_intent',
          'attributes': {
            'status': 'awaiting_payment_method',
            'client_key': 'pi_123_client',
          },
        }),
        200,
      ),
      // 2. QR Ph payment method.
      http.Response(
        _envelope({
          'id': 'pm_123',
          'type': 'payment_method',
          'attributes': {'type': 'qrph'},
        }),
        200,
      ),
      // 3. Attach: QR Ph image in next_action.code.image_url.
      http.Response(
        _envelope({
          'id': 'pi_123',
          'type': 'payment_intent',
          'attributes': {
            'status': 'awaiting_next_action',
            'next_action': {
              'type': 'consume_qr_code',
              'code': {
                'image_url': 'data:image/png;base64,${base64Encode(qrBytes)}',
              },
            },
          },
        }),
        200,
      ),
    ]);
    final service = PaymongoService(
      client: client,
      publicKey: 'pk_test_abc',
      secretKey: 'sk_test_abc',
    );

    final payment = await service.createQrPhPayment(
      amountCentavos: 15000,
      description: 'SkyeLoop Solo (P150)',
    );

    expect(payment.intentId, 'pi_123');
    expect(payment.status, 'awaiting_next_action');
    expect(payment.hasQrImage, isTrue);
    expect(payment.qrImageBytes, qrBytes);
    expect(payment.isSucceeded, isFalse);

    expect(client.requests, hasLength(3));

    // 1. Payment Intent — secret key, QR Ph only.
    final intentRequest = client.requests[0];
    expect(intentRequest.url.toString(),
        'https://api.paymongo.com/v1/payment_intents');
    expect(intentRequest.method, 'POST');
    expect(intentRequest.headers['Authorization'],
        'Basic ${PaymongoService.authHeader('sk_test_abc')}');
    final intentBody = jsonDecode(intentRequest.body) as Map<String, dynamic>;
    final intentAttributes =
        (intentBody['data'] as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>;
    expect(intentAttributes['amount'], 15000);
    expect(intentAttributes['currency'], 'PHP');
    expect(intentAttributes['payment_method_allowed'], ['qrph']);
    expect(intentAttributes['description'], 'SkyeLoop Solo (P150)');

    // 2. QR Ph payment method — public key.
    final methodRequest = client.requests[1];
    expect(methodRequest.url.toString(),
        'https://api.paymongo.com/v1/payment_methods');
    expect(methodRequest.headers['Authorization'],
        'Basic ${PaymongoService.authHeader('pk_test_abc')}');
    final methodBody = jsonDecode(methodRequest.body) as Map<String, dynamic>;
    final methodAttributes =
        (methodBody['data'] as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>;
    expect(methodAttributes['type'], 'qrph');

    // 3. Attach — public key plus the intent's client key.
    final attachRequest = client.requests[2];
    expect(attachRequest.url.toString(),
        'https://api.paymongo.com/v1/payment_intents/pi_123/attach');
    expect(attachRequest.headers['Authorization'],
        'Basic ${PaymongoService.authHeader('pk_test_abc')}');
    final attachBody = jsonDecode(attachRequest.body) as Map<String, dynamic>;
    final attachAttributes =
        (attachBody['data'] as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>;
    expect(attachAttributes['payment_method'], 'pm_123');
    expect(attachAttributes['client_key'], 'pi_123_client');
  });

  test('createQrPhPayment returns no image until the QR is ready', () async {
    final client = _FakeClient([
      http.Response(
        _envelope({
          'id': 'pi_123',
          'attributes': {
            'status': 'awaiting_payment_method',
            'client_key': 'pi_123_client',
          },
        }),
        200,
      ),
      http.Response(
        _envelope({'id': 'pm_123', 'attributes': {'type': 'qrph'}}),
        200,
      ),
      http.Response(
        _envelope({'id': 'pi_123', 'attributes': {'status': 'processing'}}),
        200,
      ),
    ]);
    final service = PaymongoService(
      client: client,
      publicKey: 'pk_test_abc',
      secretKey: 'sk_test_abc',
    );

    final payment = await service.createQrPhPayment(amountCentavos: 1000);

    expect(payment.status, 'processing');
    expect(payment.hasQrImage, isFalse);
    expect(payment.qrImageBytes, isNull);
  });

  test('retrievePayment polls the intent with the secret key', () async {
    final client = _FakeClient([
      http.Response(
        _envelope({
          'id': 'pi_123',
          'attributes': {'status': 'succeeded'},
        }),
        200,
      ),
    ]);
    final service = PaymongoService(
      client: client,
      publicKey: 'pk_test_abc',
      secretKey: 'sk_test_abc',
    );

    final payment = await service.retrievePayment('pi_123');

    expect(payment.isSucceeded, isTrue);
    expect(payment.hasQrImage, isFalse);

    final request = client.requests.single;
    expect(request.method, 'GET');
    expect(request.url.toString(),
        'https://api.paymongo.com/v1/payment_intents/pi_123');
    expect(request.headers['Authorization'],
        'Basic ${PaymongoService.authHeader('sk_test_abc')}');
  });

  test('surfaces the PayMongo error detail on HTTP failure', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'errors': [
            {
              'code': 'parameter_not_allowed',
              'detail': 'qrph is not allowed for this account.',
            },
          ],
        }),
        400,
      ),
    ]);
    final service = PaymongoService(
      client: client,
      publicKey: 'pk_test_abc',
      secretKey: 'sk_test_abc',
    );

    await expectLater(
      service.createQrPhPayment(amountCentavos: 1000),
      throwsA(isA<PaymongoException>()
          .having((error) => error.message, 'message', contains('HTTP 400'))
          .having((error) => error.details, 'details',
              contains('qrph is not allowed for this account.'))),
    );
  });

  test('fails fast when the .env keys are missing', () async {
    final client = _FakeClient([]);
    final service = PaymongoService(client: client, publicKey: '', secretKey: '');

    await expectLater(
      service.createQrPhPayment(amountCentavos: 1000),
      throwsA(isA<PaymongoException>()
          .having((error) => error.message, 'message', contains('.env'))),
    );
    expect(client.requests, isEmpty);
  });
}
