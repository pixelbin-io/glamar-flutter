/// A version lookup response, including failed HTTP requests or network errors.
class VersionApiResponse {
  const VersionApiResponse({
    required this.url,
    this.statusCode,
    this.body,
    this.error,
  });

  final String url;
  final int? statusCode;
  final Object? body;
  final String? error;
}
