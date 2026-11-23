# Hata tipleri — core/errors/app_exception.dart

Her projede (REST veya Firebase fark etmez) ilk kurulan dosyalardan biridir. Repository'ler bu tipleri fırlatır, UI `messageOf(error)` ile kullanıcıya mesaj gösterir.

```dart
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  // runtimeType release derlemesinde küçültülür, güvenilmez.
  @override
  String toString() => 'AppException: $message';
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'İnternet bağlantınızı kontrol edin.', Object? cause])
      : super(cause: cause);
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Oturumunuzun süresi doldu, tekrar giriş yapın.']);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Kayıt bulunamadı.']);
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {this.fieldErrors = const {}});
  final Map<String, List<String>> fieldErrors;
}

final class ServerException extends AppException {
  const ServerException([super.message = 'Sunucu hatası, daha sonra tekrar deneyin.', this.statusCode]);
  final int? statusCode;
}

final class UnknownException extends AppException {
  const UnknownException([super.message = 'Beklenmeyen bir hata oluştu.', Object? cause])
      : super(cause: cause);
}

/// UI'da gösterilecek mesaj.
String messageOf(Object error) =>
    error is AppException ? error.message : const UnknownException().message;
```
