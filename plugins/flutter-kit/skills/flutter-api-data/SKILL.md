---
name: flutter-api-data
description: "Flutter REST API veri katmanı: Dio, token yenileme, AppException'a hata çevirme, sayfalama, dosya yükleme. Backend'e (ASP.NET, Node, SQL Server arkasındaki API) bağlanırken kullan."
---

# REST API Veri Katmanı

`flutter-architecture` kuralları geçerlidir. Kod: `references/dio-setup.md` (client + interceptor + hata çevirme), `references/patterns.md` (sayfalama, upload, cache, iptal).

## Temel kurallar

1. **Veritabanına doğrudan bağlanma.** Flutter uygulaması SQL Server, PostgreSQL, MySQL gibi bir veritabanına asla doğrudan bağlanmaz; arada her zaman bir backend API olur. Kullanıcı doğrudan bağlantı isterse nedenini kısaca açıkla (bağlantı bilgisi uygulamadan çıkarılabilir, yetki kontrolü yok) ve API katmanını öner.
2. **Tek Dio örneği:** `core/network/dio_provider.dart` içinde `@Riverpod(keepAlive: true)`. Feature'lar kendi Dio'sunu oluşturmaz.
3. **Base URL** `Env.apiBaseUrl`'den (`--dart-define-from-file`). Koda gömülü URL yok.
4. **Dio sadece Service'te.** Service ham veri/model döner, hata yakalamaz.
5. **Hata çevirme sadece Repository'de:** `DioException` → `mapDioException(e)` → tipli `AppException`. Üst katmanlar Dio tipini görmez.
6. **Token** `flutter_secure_storage`'da tutulur (`shared_preferences` değil). Header'a interceptor ekler.
7. **Log** sadece debug modda (`kDebugMode`); prod'da istek/yanıt gövdesi loglanmaz.
8. **Timeout** her zaman tanımlı (bağlantı 10 sn, yanıt 20–30 sn varsayılan).

## Hata hiyerarşisi (core/errors/app_exception.dart)

| Exception | Ne zaman | Kullanıcı mesajı (varsayılan) |
|---|---|---|
| `NetworkException` | timeout, bağlantı yok | "İnternet bağlantınızı kontrol edin." |
| `UnauthorizedException` | 401 / 403 | "Oturumunuzun süresi doldu, tekrar giriş yapın." |
| `NotFoundException` | 404 | "Kayıt bulunamadı." |
| `ValidationException` | 400 / 422 (alan hataları ile) | backend mesajı |
| `ServerException` | 5xx | "Sunucu hatası, daha sonra tekrar deneyin." |
| `UnknownException` | diğer | "Beklenmeyen bir hata oluştu." |

Backend hata gövdesinde mesaj dönüyorsa (`message`, `title`, `errors`) onu kullan. ASP.NET Core `ProblemDetails` formatı (`title`, `detail`, `errors`) `dio-setup.md`'deki mapper'da ele alınmıştır.

## Yeni endpoint eklerken

1. Modeli yaz (freezed + `fromJson`). Örnek JSON varsa alanları ondan çıkar.
2. Service'e metot ekle: tipli `get<Map<String, dynamic>>` / `get<List<dynamic>>`, sorgu parametreleri `queryParameters:` ile.
3. Repository'de `_guard` ile sar.
4. ViewModel'den çağır.
5. Repository testi yaz: başarılı yanıt + en az bir hata durumu (`flutter-testing`).

## Kontrol listesi

- [ ] URL string birleştirme yerine `queryParameters` kullanıldı mı?
- [ ] `res.data!` öncesi tip parametresi verildi mi (`get<Map<String, dynamic>>`)?
- [ ] 401'de oturum kapatma / token yenileme akışı var mı?
- [ ] Liste endpoint'leri büyükse sayfalama var mı?
- [ ] Ekrandan çıkınca iptal edilmesi gereken uzun istekler `CancelToken` + `ref.onDispose` ile iptal ediliyor mu?
