import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class RequestSigningInterceptor extends Interceptor {
  RequestSigningInterceptor({
    this.signingKey = '1234567',
    this.headerPrefix = 'x-ebg-',
  });

  final String signingKey;
  final String headerPrefix;

  static final List<RegExp> _headersToInclude = [
    RegExp(r'^x-ebg-.*$'),
    RegExp(r'^host$'),
  ];

  @override
  Future onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // ---- required headers for canonical
    final now = DateTime.now().toUtc();
    final formatted = '${DateFormat('yyyyMMddTHHmmss').format(now)}Z';

    // EXACT: host without port (matches OkHttp usage in your Kotlin)
    options.headers['host'] = options.uri.host;
    options.headers['${headerPrefix}param'] = formatted; // raw for canonical

    // canonical string (same order/format as Kotlin)
    final canonical = _canonicalString(options);

    // signature = HMAC_SHA256( signingKey, formatted + "\n" + SHA256(canonical) )
    final toSign = '$formatted\n${sha256.convert(utf8.encode(canonical))}';
    final sig = _hmacSha256(signingKey, toSign);

    // final headers (param becomes base64)
    options.headers['${headerPrefix}signature'] = 'v1:$sig';
    options.headers['${headerPrefix}param'] = base64.encode(
      utf8.encode(formatted),
    );

    handler.next(options);
  }

  String _canonicalString(RequestOptions o) {
    final content = () {
      final d = o.data;
      if (d == null) return '';
      if (d is Map || d is List) return json.encode(d);
      if (d is String) return d;
      return d.toString();
    }();
    final contentHash = sha256.convert(utf8.encode(content)).toString();

    final method = o.method.toUpperCase();
    final path = o.uri.path.isEmpty
        ? '/'
        : o.uri.path; // encodedPath equivalent

    final query = _sortedAndEncodedQuery(o);
    final canonHeaders = _canonicalHeaders(o);
    final signedHeaders = _signedHeaders(o);

    return [
      method,
      path,
      query,
      canonHeaders,
      '', // blank line
      signedHeaders,
      contentHash,
    ].join('\n');
  }

  String _sortedAndEncodedQuery(RequestOptions o) {
    // Combine URL query and explicit queryParameters, join multi-values with ","
    final Map<String, List<String>> all = {};
    // from URL
    final urlMap = Uri.splitQueryString(o.uri.query, encoding: utf8);
    urlMap.forEach((k, v) {
      all[k] = (all[k] ?? [])..add(v);
    });
    // from options
    o.queryParameters.forEach((k, v) {
      if (v is Iterable) {
        all[k] = (all[k] ?? [])..addAll(v.map((e) => e.toString()));
      } else {
        all[k] = (all[k] ?? [])..add(v.toString());
      }
    });

    final keys = all.keys.toList()..sort();
    return keys
        .map((k) {
          final joined = all[k]!.join(',');
          return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(joined)}';
        })
        .join('&');
  }

  String _canonicalHeaders(RequestOptions o) {
    final entries =
        o.headers.entries
            .where(
              (h) => _headersToInclude.any(
                (re) => re.hasMatch(h.key.toLowerCase()),
              ),
            )
            .map(
              (e) => MapEntry(e.key.toLowerCase(), e.value.toString().trim()),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}:${e.value}').join('\n');
  }

  String _signedHeaders(RequestOptions o) {
    final names =
        o.headers.keys
            .where(
              (k) =>
                  _headersToInclude.any((re) => re.hasMatch(k.toLowerCase())),
            )
            .map((k) => k.toLowerCase())
            .toList()
          ..sort();
    return names.join(';');
  }

  String _hmacSha256(String key, String message) {
    final h = Hmac(sha256, utf8.encode(key));
    return h.convert(utf8.encode(message)).toString();
  }
}

class CurlLogger extends Interceptor {
  final bool convertFormData;
  final bool logResponse;

  CurlLogger({this.convertFormData = true, this.logResponse = false});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log(
      _cURLRequestRepresentation(err.requestOptions) +
          (logResponse
              ? (err.response != null
                    ? _cURLResponseRepresentation(err.response!)
                    : '${err.type} ${err.message} ${err.error}')
              : ''),
    );
    return handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log(
      _cURLRequestRepresentation(response.requestOptions) +
          (logResponse ? _cURLResponseRepresentation(response) : ''),
    );
    return handler.next(response); //continue
  }

  String _cURLRequestRepresentation(RequestOptions options) {
    List<String> components = ['\n\ncurl -i'];
    if (options.method.toUpperCase() != 'GET') {
      components.add('-X ${options.method}');
    }

    options.headers.forEach((k, v) {
      components.add('-H "$k: $v"');
    });

    if (options.data != null) {
      // FormData can't be JSON-serialized, so keep only their fields attributes
      if (options.data is FormData && convertFormData == true) {
        options.data = Map.fromEntries(options.data.fields);
      }

      final data = _parseBody(options.data).replaceAll('"', '\\"');
      components.add('-d "$data"');
    }

    components.add('"${options.uri.toString()}"\n');

    return components.join(' \\\n');
  }

  String _cURLResponseRepresentation(Response response) {
    List<String> components = [
      '\n${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri.toString()} HTTP/2 ${response.statusCode}/${response.statusMessage}',
    ];
    response.headers.forEach((k, v) {
      components.add('$k: ${v.join(', ')}');
    });
    final data = '\n${_parseBody(response.data)}';
    components.add(data);
    components.add('\n');
    return components.join('\n');
  }

  String _parseBody(dynamic data) {
    try {
      return json.encode(data);
    } catch (e) {
      return data.toString();
    }
  }
}
