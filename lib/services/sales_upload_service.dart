import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/upload_config.dart';
import 'sales_database_service.dart';

/// Represents the payload for one day's upload.
class DailySalesPayload {
  final String date; // YYYY-MM-DD
  final DailySummary summary;
  final List<SessionDetail> sessions;

  DailySalesPayload({
    required this.date,
    required this.summary,
    required this.sessions,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'summary': summary.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
}

class DailySummary {
  final int totalSessions;
  final int totalRevenue;
  final int singleCount;
  final int stripCount;
  final int gridCount;
  final int singleRevenue;
  final int stripRevenue;
  final int gridRevenue;

  DailySummary({
    required this.totalSessions,
    required this.totalRevenue,
    required this.singleCount,
    required this.stripCount,
    required this.gridCount,
    required this.singleRevenue,
    required this.stripRevenue,
    required this.gridRevenue,
  });

  Map<String, dynamic> toJson() => {
        'total_sessions': totalSessions,
        'total_revenue': totalRevenue,
        'tier_breakdown': {
          'single': {'count': singleCount, 'revenue': singleRevenue},
          'strip': {'count': stripCount, 'revenue': stripRevenue},
          'grid': {'count': gridCount, 'revenue': gridRevenue},
        },
      };
}

class SessionDetail {
  final String sessionId;
  final String startedAt;
  final String pricingTier;
  final int price;
  final int photoCount;
  final int copies;

  SessionDetail({
    required this.sessionId,
    required this.startedAt,
    required this.pricingTier,
    required this.price,
    required this.photoCount,
    required this.copies,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'started_at': startedAt,
        'pricing_tier': pricingTier,
        'price': price,
        'photo_count': photoCount,
        'copies': copies,
      };

  factory SessionDetail.fromRecord(SalesRecord r) => SessionDetail(
        sessionId: r.sessionId,
        startedAt: r.startedAt.toIso8601String(),
        pricingTier: r.pricingTier,
        price: r.price,
        photoCount: r.photoCount,
        copies: r.copies,
      );
}

class SalesUploadService {
  final SalesDatabaseService _db;

  SalesUploadService(this._db);

  /// Upload sales data for all pending dates to the configured API.
  /// Returns a result describing what happened.
  Future<UploadResult> uploadPending(UploadConfig config) async {
    if (config.apiBaseUrl.isEmpty) {
      return UploadResult(success: false, message: 'API base URL is not configured.');
    }

    final pendingDates = await _db.getPendingDates();
    if (pendingDates.isEmpty) {
      return UploadResult(success: true, message: 'No pending sales data to upload.');
    }

    // Build URL — ensure no double slash
    final baseUrl = config.apiBaseUrl.endsWith('/')
        ? config.apiBaseUrl.substring(0, config.apiBaseUrl.length - 1)
        : config.apiBaseUrl;
    final uploadUrl = '$baseUrl/api/sales/upload';

    int uploaded = 0;
    int failed = 0;

    for (final date in pendingDates) {
      final sessions = await _db.getSessionsByDate(date);
      if (sessions.isEmpty) continue;

      // Build summary
      int singleCount = 0, stripCount = 0, gridCount = 0;
      int singleRevenue = 0, stripRevenue = 0, gridRevenue = 0;

      for (final s in sessions) {
        switch (s.pricingTier) {
          case 'single':
            singleCount++;
            singleRevenue += s.price;
            break;
          case 'strip':
            stripCount++;
            stripRevenue += s.price;
            break;
          case 'grid':
            gridCount++;
            gridRevenue += s.price;
            break;
        }
      }

      final payload = DailySalesPayload(
        date: date,
        summary: DailySummary(
          totalSessions: sessions.length,
          totalRevenue: sessions.fold(0, (sum, s) => sum + s.price),
          singleCount: singleCount,
          stripCount: stripCount,
          gridCount: gridCount,
          singleRevenue: singleRevenue,
          stripRevenue: stripRevenue,
          gridRevenue: gridRevenue,
        ),
        sessions: sessions.map(SessionDetail.fromRecord).toList(),
      );

      final body = jsonEncode(payload.toJson());

      try {
        final request = http.Request('POST', Uri.parse(uploadUrl))
          ..headers['Content-Type'] = 'application/json';

        if (config.apiToken.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer ${config.apiToken}';
        }

        request.body = body;

        final response = await request.send().timeout(
              const Duration(seconds: 30),
            );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Mark all sessions for this date as uploaded
          for (final s in sessions) {
            if (s.id != null) await _db.markUploaded(s.id!);
          }
          uploaded += sessions.length;
        } else {
          final responseBody = await response.stream.bytesToString();
          // Mark each session as failed
          for (final s in sessions) {
            if (s.id != null) {
              await _db.markFailed(
                s.id!,
                error: 'HTTP ${response.statusCode}: ${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}',
              );
            }
          }
          failed += sessions.length;
        }
      } catch (error) {
        for (final s in sessions) {
          if (s.id != null) {
            await _db.markFailed(s.id!, error: error.toString());
          }
        }
        failed += sessions.length;
      }
    }

    final message = failed == 0
        ? 'Successfully uploaded $uploaded session(s).'
        : 'Uploaded $uploaded, failed $failed session(s). Check logs.';
    return UploadResult(
      success: failed == 0,
      message: message,
      uploaded: uploaded,
      failed: failed,
    );
  }
}

class UploadResult {
  final bool success;
  final String message;
  final int uploaded;
  final int failed;

  UploadResult({
    required this.success,
    required this.message,
    this.uploaded = 0,
    this.failed = 0,
  });
}
