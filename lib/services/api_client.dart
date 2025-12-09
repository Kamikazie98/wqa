import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import 'exceptions.dart';

typedef TokenProvider = String? Function();

class ApiClient {
  ApiClient({required this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  static const _baseUrl = 'https://wqai.morvism.ir';

  final TokenProvider tokenProvider;
  final http.Client _client;

  Uri _uri(
    String path, {
    Map<String, dynamic>? query,
  }) {
    if (path.startsWith('https')) {
      return Uri.parse(path);
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalized');
    if (query == null || query.isEmpty) {
      return uri;
    }
    final queryParams = <String, String>{
      ...uri.queryParameters,
      ...query.map(
        (key, value) => MapEntry(key, value == null ? '' : value.toString()),
      ),
    };
    return uri.replace(queryParameters: queryParams);
  }

  Map<String, String> _headers({
    required bool authRequired,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authRequired) {
      final token = tokenProvider();
      if (token == null) {
        throw const ApiException('برای این درخواست باید وارد شوید.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.get(
      _uri(path, query: query),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postJsonRaw(
    String path,
    String rawBody, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: rawBody,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Stream<ChatSseEvent> streamChat(ChatRequest request) async* {
    final httpRequest = http.Request('POST', _uri('/chat/stream'))
      ..headers.addAll(
        _headers(authRequired: true)..['Accept'] = 'text/event-stream',
      )
      ..body = jsonEncode(request.toJson());

    final streamedResponse = await _client.send(httpRequest);
    if (streamedResponse.statusCode >= 400) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw ApiException(
        _extractErrorMessage(errorBody) ?? 'ارتباط با سرور برقرار نشد.',
        statusCode: streamedResponse.statusCode,
      );
    }

    final stream = streamedResponse.stream.transform(utf8.decoder).transform(
          const LineSplitter(),
        );
    String? currentEvent;
    final buffer = StringBuffer();

    await for (final line in stream) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trim());
      } else if (line.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          final data = buffer.toString().trim();
          yield ChatSseEvent.fromEvent(currentEvent ?? 'message', data);
          buffer.clear();
        }
        currentEvent = null;
      }
    }
    if (buffer.isNotEmpty) {
      yield ChatSseEvent.fromEvent(
          currentEvent ?? 'message', buffer.toString());
    }
  }

  Stream<ChatSseEvent> streamChatWithFiles(
    ChatRequest request,
    List<String> filePaths, {
    String path = '/chat/stream/form',
  }) async* {
    final payload = jsonEncode(request.toJson());
    final multipart = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(
        _headers(authRequired: true)..['Accept'] = 'text/event-stream',
      )
      ..fields['payload'] = payload;

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException('فایل یافت نشد: $filePath');
      }
      multipart.files.add(await http.MultipartFile.fromPath('files', filePath));
    }

    final streamedResponse = await multipart.send();
    if (streamedResponse.statusCode >= 400) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw ApiException(
        _extractErrorMessage(errorBody) ?? 'در ارسال فایل/پیام خطا رخ داد.',
        statusCode: streamedResponse.statusCode,
      );
    }

    final stream = streamedResponse.stream.transform(utf8.decoder).transform(
          const LineSplitter(),
        );
    String? currentEvent;
    final buffer = StringBuffer();

    await for (final line in stream) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trim());
      } else if (line.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          final data = buffer.toString().trim();
          yield ChatSseEvent.fromEvent(currentEvent ?? 'message', data);
          buffer.clear();
        }
        currentEvent = null;
      }
    }
    if (buffer.isNotEmpty) {
      yield ChatSseEvent.fromEvent(
          currentEvent ?? 'message', buffer.toString());
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }

    final message = _extractErrorMessage(response.body) ??
        'خطای غیرمنتظره (${response.statusCode})';
    throw ApiException(message, statusCode: status);
  }

  String? _extractErrorMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            body;
      }
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString();
      }
    } catch (_) {
      // ignore json error
    }
    return body;
  }

  Future<List<Map<String, String>>> getSuggestedPrompts({
    String? category,
    String language = 'fa',
    int limit = 5,
  }) async {
    final query = <String, String>{
      if (category != null) 'category': category,
      'language': language,
      'limit': limit.toString(),
    };

    final response = await getJson(
      '/chat/suggested-prompts',
      query: query,
    );

    final prompts = response['prompts'] as List<dynamic>? ?? [];
    return prompts
        .map((item) => Map<String, String>.from(item as Map))
        .toList();
  }

  void close() {
    _client.close();
  }

  Future<String> uploadFile(String filePath) async {
    final uri = _uri('/files/upload');
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ApiException('فایل پیدا نشد.');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(authRequired: true))
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final url =
              decoded['url']?.toString() ?? decoded['file_url']?.toString();
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      } catch (_) {
        // fall through to error
      }
      throw const ApiException('پاسخ نامعتبر از سرور برای آپلود فایل.');
    }
    final message = _extractErrorMessage(body) ?? 'آپلود فایل ناموفق بود';
    throw ApiException(message, statusCode: streamed.statusCode);
  }
}
