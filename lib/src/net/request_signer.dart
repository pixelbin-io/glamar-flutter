import 'dart:convert';

import 'package:crypto/crypto.dart';

class RequestSigner {
  RequestSigner({required this.signingKey, this.headerPrefix = 'x-ebg-'});

  final String signingKey;
  final String headerPrefix;

  /// Returns headers to add: { x-ebg-param, x-ebg-signature, host }
  Map<String, String> sign({
    required Uri url,
    required String method,
    Map<String, String>? headers,
    String body = '',
  }) {
    final now = _utcNowCompact(); // yyyyMMdd'T'HHmmss'Z'
    final contentHash = _sha256Hex(utf8.encode(body));
    final canonical = _canonicalString(
      method: method,
      url: url,
      headers: {...?headers, 'host': url.host, '${headerPrefix}param': now},
      contentHash: contentHash,
    );

    final toSign = '$now\n${_sha256Hex(utf8.encode(canonical))}';
    final sig = _hmacSha256Hex(signingKey, toSign);

    return {
      'host': url.host,
      '${headerPrefix}param': base64Encode(utf8.encode(now)),
      '${headerPrefix}signature': 'v1:$sig',
    };
  }

  String _canonicalString({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    required String contentHash,
  }) {
    final path = url.path.isEmpty ? '/' : url.path;

    // Sort query params, encode
    final qp = <String, String>{};
    for (final key in url.queryParametersAll.keys) {
      final value = url.queryParametersAll[key]!.join(',');
      qp[_enc(key)] = _enc(value);
    }
    final qpSorted = (qp.keys.toList()..sort())
        .map((k) => '$k=${qp[k]}')
        .join('&');

    // Only include headers matching prefix or host
    include(String name) =>
        name.toLowerCase() == 'host' ||
        name.toLowerCase().startsWith(headerPrefix);
    final filtered = headers.entries
        .where((e) => include(e.key))
        .map((e) => MapEntry(e.key.toLowerCase(), e.value.trim()));

    final sorted = filtered.toList()..sort((a, b) => a.key.compareTo(b.key));

    final canonicalHeaders = sorted
        .map((e) => '${e.key}:${e.value}')
        .join('\n');
    final signedHeaders = sorted.map((e) => e.key).join(';');

    return [
      method.toUpperCase(),
      path,
      qpSorted,
      canonicalHeaders,
      '',
      signedHeaders,
      contentHash,
    ].join('\n');
  }

  String _enc(String s) => Uri.encodeQueryComponent(s);

  String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  String _hmacSha256Hex(String key, String message) {
    final h = Hmac(sha256, utf8.encode(key));
    return h.convert(utf8.encode(message)).toString();
  }

  String _utcNowCompact() {
    final now = DateTime.now().toUtc();
    // yyyyMMdd'T'HHmmss'Z'
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        'T${two(now.hour)}${two(now.minute)}${two(now.second)}Z';
  }
}
