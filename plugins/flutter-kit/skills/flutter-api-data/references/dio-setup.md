# Dio kurulumu

## core/errors/app_exception.dart

Tanım: `flutter-architecture/references/app-exception.md`. Bu dosyadaki mapper o tipleri kullanır.

## core/network/dio_exception_mapper.dart

```dart
import 'package:dio/dio.dart';

import 'package:my_app/core/errors/app_exception.dart';

AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return NetworkException('İnternet bağlantınızı kontrol edin.', e);
    case DioExceptionType.cancel:
      return UnknownException('İstek iptal edildi.', e);
    case DioExceptionType.badCertificate:
      return UnknownException('Güvenli bağlantı kurulamadı.', e);
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.unknown:
      return UnknownException('Beklenmeyen bir hata oluştu.', e);
  }
}

AppException _fromResponse(Response<dynamic>? res) {
  final status = res?.statusCode ?? 0;
  final body = res?.data;
  final serverMessage = _extractMessage(body);

  return switch (status) {
    401 || 403 => const UnauthorizedException(),
    404 => NotFoundException(serverMessage ?? 'Kayıt bulunamadı.'),
    400 || 422 => ValidationException(
        serverMessage ?? 'Gönderilen bilgiler geçersiz.',
        fieldErrors: _extractFieldErrors(body),
      ),
    >= 500 => ServerException(
        serverMessage ?? 'Sunucu hatası, daha sonra tekrar deneyin.', status),
    _ => UnknownException(serverMessage ?? 'Beklenmeyen bir hata oluştu.'),
  };
}

/// `message`, ASP.NET ProblemDetails `detail`/`title` alanlarını dener.
String? _extractMessage(Object? body) {
  if (body is Map) {
    for (final key in const ['message', 'detail', 'title', 'error']) {
      final v = body[key];
      if (v is String && v.isNotEmpty) return v;
    }
  }
  if (body is String && body.isNotEmpty && body.length < 300) return body;
  return null;
}

Map<String, List<String>> _extractFieldErrors(Object? body) {
  if (body is Map && body['errors'] is Map) {
    final errors = body['errors'] as Map;
    return {
      for (final entry in errors.entries)
        entry.key.toString(): switch (entry.value) {
          final List<dynamic> list => list.map((e) => e.toString()).toList(),
          final Object other => [other.toString()],
          null => <String>[],
        },
    };
  }
  return const {};
}
```

## core/network/dio_provider.dart

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/config/env.dart';
import 'package:my_app/core/network/interceptors/auth_interceptor.dart';

part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    if (kDebugMode)
      LogInterceptor(requestBody: true, responseBody: true, logPrint: debugPrint),
  ]);

  ref.onDispose(dio.close);
  return dio;
}
```

## Token deposu — core/network/token_storage.dart

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_storage.g.dart';

class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> save({required String access, String? refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    if (refresh != null) await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() => _storage.deleteAll();
}

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage(const FlutterSecureStorage());
```

## core/network/interceptors/auth_interceptor.dart

Token ekler; 401 gelirse refresh token ile **bir kez** yenilemeyi dener, başarısızsa oturumu temizler.

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/config/env.dart';
import 'package:my_app/core/network/token_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._ref);
  final Ref _ref;

  TokenStorage get _tokens => _ref.read(tokenStorageProvider);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.readAccess();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!isUnauthorized || alreadyRetried) return handler.next(err);

    final refresh = await _tokens.readRefresh();
    if (refresh == null) return handler.next(err);

    try {
      // Ayrı, interceptor'suz Dio: sonsuz döngüyü önler.
      final res = await Dio(BaseOptions(baseUrl: Env.apiBaseUrl))
          .post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
      final newAccess = res.data!['accessToken'] as String;
      await _tokens.save(access: newAccess, refresh: res.data!['refreshToken'] as String?);

      final retry = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..extra['retried'] = true;
      final response = await Dio(BaseOptions(baseUrl: Env.apiBaseUrl)).fetch<dynamic>(retry);
      return handler.resolve(response);
    } on DioException {
      await _tokens.clear();
      return handler.next(err);
    }
  }
}
```

> `/auth/refresh` yolu ve alan adları (`accessToken`, `refreshToken`) backend'e göre değiştirilir. Backend refresh token desteklemiyorsa `onError` içinde sadece `_tokens.clear()` yap ve hatayı geçir; router redirect kullanıcıyı login'e atar.
