import 'package:flutter_test/flutter_test.dart';
import 'package:skyeloop/services/local_server_service.dart';

void main() {
  group('rankLanAddresses', () {
    test('puts the Android hotspot subnet first even when Wi-Fi is also present', () {
      expect(
        rankLanAddresses(['192.168.1.5', '192.168.43.1']),
        ['192.168.43.1', '192.168.1.5'],
      );
    });

    test('ranks hotspot AP ranges ahead of other private ranges', () {
      final result =
          rankLanAddresses(['10.0.0.7', '10.42.0.1', '192.168.44.1', '172.20.10.2']);
      // Both AP subnets sort before every other private range (ties broken lexically).
      expect(result.take(2).toSet(), {'10.42.0.1', '192.168.44.1'});
      expect(result[2], '10.0.0.7');
      expect(result[3], '172.20.10.2');
    });

    test('drops link-local addresses and de-duplicates', () {
      expect(
        rankLanAddresses(['169.254.1.1', '192.168.43.1', '192.168.43.1']),
        ['192.168.43.1'],
      );
    });

    test('returns empty when only link-local addresses exist', () {
      expect(rankLanAddresses(['169.254.1.1']), isEmpty);
    });
  });

  group('buildDigitalCopyPageHtml', () {
    test('serves the photo, a Save-to-Photos button and a download fallback', () {
      final html = buildDigitalCopyPageHtml('abc123');
      expect(html, contains('src="/abc123/photo.png"'));
      expect(html, contains('id="save"'));
      expect(html, contains('Save to Photos'));
      expect(html, contains('navigator.share'));
      expect(html, contains('navigator.canShare'));
      expect(html, contains('href="/abc123/photo.png" download="skyeloop-photo.png"'));
      expect(html, contains('Download file'));
    });

    test('keeps the download link labelled for iOS so users know it goes to Files', () {
      final html = buildDigitalCopyPageHtml('abc123');
      expect(html, contains('Download file (goes to Files)'));
    });
  });
}
