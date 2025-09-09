class VersionResponse {
  final bool success;
  final String? sdkVersion;

  VersionResponse({required this.success, this.sdkVersion});

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      success: json['success'] == true,
      sdkVersion: json['sdkVersion'] as String?,
    );
  }
}
