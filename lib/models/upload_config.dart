class UploadConfig {
  final String apiBaseUrl;
  final String apiToken;
  final bool autoUploadEnabled;
  final int scheduledHour; // 0-23, default 23 (11 PM)
  final int scheduledMinute; // 0-59, default 0

  const UploadConfig({
    this.apiBaseUrl = '',
    this.apiToken = '',
    this.autoUploadEnabled = false,
    this.scheduledHour = 23,
    this.scheduledMinute = 0,
  });

  UploadConfig copyWith({
    String? apiBaseUrl,
    String? apiToken,
    bool? autoUploadEnabled,
    int? scheduledHour,
    int? scheduledMinute,
  }) =>
      UploadConfig(
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        apiToken: apiToken ?? this.apiToken,
        autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
        scheduledHour: scheduledHour ?? this.scheduledHour,
        scheduledMinute: scheduledMinute ?? this.scheduledMinute,
      );

  String get scheduledTimeLabel {
    final hour = scheduledHour.toString().padLeft(2, '0');
    final minute = scheduledMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> toJson() => {
        'api_base_url': apiBaseUrl,
        'api_token': apiToken,
        'auto_upload_enabled': autoUploadEnabled,
        'scheduled_hour': scheduledHour,
        'scheduled_minute': scheduledMinute,
      };

  factory UploadConfig.fromJson(Map<String, dynamic> json) => UploadConfig(
        apiBaseUrl: json['api_base_url'] as String? ?? '',
        apiToken: json['api_token'] as String? ?? '',
        autoUploadEnabled: json['auto_upload_enabled'] as bool? ?? false,
        scheduledHour: json['scheduled_hour'] as int? ?? 23,
        scheduledMinute: json['scheduled_minute'] as int? ?? 0,
      );
}
