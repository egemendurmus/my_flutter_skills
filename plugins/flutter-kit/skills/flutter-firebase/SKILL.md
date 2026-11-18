---
name: flutter-firebase
description: Flutter + Firebase — FlutterFire kurulumu, Firebase Auth (giriş, auth state, go_router redirect), Cloud Firestore Service/Repository desenleri (withConverter, stream, sorgu, batch/transaction), Timestamp dönüşümü, güvenlik kuralları ve emulator. Flutter projesinde Firebase/Firestore/Firebase Auth/Storage kullanılırken kullan.
---

# Flutter + Firebase

`flutter-architecture` kuralları geçerlidir: Firestore/Auth SDK'sı sadece **Service** katmanında kullanılır; widget'lar ve ViewModel'ler `FirebaseFirestore` görmez. Kod: `references/firestore-patterns.md`, `references/auth-patterns.md`.

## Kurulum

```bash
dart pub global activate flutterfire_cli
flutterfire configure            # lib/firebase_options.dart üretir
flutter pub add firebase_core firebase_auth cloud_firestore
# gerekirse: firebase_storage, firebase_messaging, firebase_crashlytics, firebase_analytics
```

`main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: App()));
}
```

Birden çok ortam (dev/prod) varsa iki ayrı Firebase projesi kullan; `flutterfire configure --project=<id> --out=lib/firebase_options_dev.dart` ve `main`'de `Env.appEnv`'e göre seç.

## SDK provider'ları — core/firebase/firebase_providers.dart

```dart
@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;
```

Service'ler bu provider'ları `ref.watch` ile alır; testte bu sayede `fake_cloud_firestore` / `firebase_auth_mocks` ile değiştirilebilir.

## Temel kurallar

1. **Tipli koleksiyonlar:** Her koleksiyona `withConverter<T>()` ile erişilir; `Map<String, dynamic>` UI'a kadar taşınmaz.
2. **Doküman id'si** modelde `id` alanıdır; Firestore'a yazarken `toJson`'dan çıkarılır.
3. **Tarih:** Firestore `Timestamp` ↔ `DateTime` dönüşümü `TimestampConverter` ile. Sunucu zamanı gerekiyorsa `FieldValue.serverTimestamp()`.
4. **Gerçek zamanlı veri** `Stream` olarak döner ve Riverpod `StreamProvider` (codegen: `Stream<T>` dönen `@riverpod`) ile izlenir. Tek seferlik okuma için `Future`.
5. **Filtreleme sunucuda:** `.where(...)` ve `.limit(...)` kullan; tüm koleksiyonu çekip istemcide filtreleme yapma.
6. **Bileşik sorgular** index ister: hata mesajındaki linki kullanıcıya ver veya `firestore.indexes.json`'a ekle.
7. **Birden çok yazma** atomik olmalıysa `WriteBatch`; okuyup-yazma ise `runTransaction`.
8. **Güvenlik kuralları zorunlu:** Yeni koleksiyon eklediğinde `firestore.rules` için kural öner. İstemci tarafı kontrol güvenlik değildir.
9. **Hata çevirme:** Repository'de `FirebaseException` → `AppException` (`mapFirebaseException`).
10. **Sırlar:** `firebase_options.dart` gizli değildir (commit'lenebilir); asıl koruma güvenlik kurallarıdır. Servis hesabı anahtarları asla istemciye konmaz.

## Firestore hata çevirme

| `FirebaseException.code` | AppException |
|---|---|
| `permission-denied`, `unauthenticated` | `UnauthorizedException` |
| `not-found` | `NotFoundException` |
| `unavailable`, `deadline-exceeded` | `NetworkException` |
| `invalid-argument`, `failed-precondition` | `ValidationException` (failed-precondition genelde eksik index) |
| diğer | `UnknownException` |

Auth hataları (`FirebaseAuthException.code`) için Türkçe mesaj tablosu: `references/auth-patterns.md`.

## Test ve emulator

- Unit test: `flutter pub add dev:fake_cloud_firestore dev:firebase_auth_mocks`; `firestoreProvider.overrideWithValue(FakeFirebaseFirestore())`.
- Lokal geliştirme: `firebase emulators:start`, debug modda `FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080)` ve `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` (Android emulator için host `10.0.2.2`).
- Güvenlik kurallarını emulator'de test et.
