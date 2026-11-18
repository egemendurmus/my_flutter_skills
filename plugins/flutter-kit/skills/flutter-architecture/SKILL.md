---
name: flutter-architecture
description: Flutter/Dart projelerinin mimari kuralları — feature-first klasör yapısı, MVVM (View + Riverpod ViewModel), Repository/Service katmanları, paket seçimi ve proje kurulumu. Flutter kodu yazarken, yeni Flutter projesi kurarken, mevcut kodu incelerken veya "bu dosya nereye gider / hangi paketi kullanayım" sorularında kullan.
---

# Flutter Mimarisi

Proje kökünde `docs/GECIS.md` varsa önce onu oku: `lib/core` ve `lib/features` dışındaki kod eski yapıdır, bu kurallar ona geçiş yapılana kadar zorla uygulanmaz.

Bu skill, Flutter ekibinin resmi mimari rehberini (MVVM: UI katmanı = View + ViewModel, veri katmanı = Repository + Service) feature-first klasör yapısı ve Riverpod 3 ile uygular. Kod yazmadan önce bu kurallara uy; kullanıcı açıkça başka bir şey istemedikçe sapma.

## Minimum sürümler

Flutter **3.27+**, Dart **3.7+** (Column/Row `spacing:`, `(_, _)` wildcard parametreleri, Riverpod 3). Proje daha eskiyse bu özellikleri kullanma veya önce kullanıcıya SDK güncellemesini öner.

## Standart paketler

| İhtiyaç | Paket | Not |
|---|---|---|
| State / DI | `flutter_riverpod`, `riverpod_annotation` + dev: `riverpod_generator` | Her zaman codegen (`@riverpod`) kullan |
| Routing | `go_router` | Rotalar `core/router/` altında |
| HTTP | `dio` | Sadece Service sınıflarında kullanılır |
| Model | `freezed_annotation`, `json_annotation` + dev: `freezed`, `json_serializable` | Freezed 3: `abstract class` / `sealed class` zorunlu |
| Codegen | dev: `build_runner` | `dart run build_runner build -d` |
| Lint | dev: `very_good_analysis` | |
| Test | `flutter_test` + dev: `mocktail` | |
| Lokal depolama | `shared_preferences`; token/şifre için `flutter_secure_storage` | |

Paketleri **versiyon yazmadan** `flutter pub add` ile ekle; böylece güncel uyumlu sürüm gelir. Listede olmayan bir paket eklemeden önce kullanıcıya sor. Kurulum adımları: `references/project-setup.md`.

Kullanılmayacaklar (kullanıcı istemedikçe): `GetX`, `provider` + `ChangeNotifier` yeni kodda, `StateNotifier`/`StateProvider` (Riverpod legacy), `http` paketi (Dio varken), `get_it`.

## Klasör yapısı (özet)

```
lib/
├── main.dart              # bootstrap: ProviderScope + runApp
├── app.dart               # MaterialApp.router, tema
├── core/                  # feature'lara bağımlı OLMAYAN ortak kod
│   ├── config/            # env (dart-define)
│   ├── constants/         # spacing, radius, süre, asset yolları
│   ├── errors/            # AppException hiyerarşisi
│   ├── extensions/        # BuildContext, tarih/para formatlama
│   ├── network/           # Dio provider, interceptor'lar
│   ├── router/            # go_router
│   ├── theme/
│   └── widgets/           # birden çok feature'da kullanılan widget'lar
└── features/
    └── <feature>/
        ├── data/
        │   ├── models/        # freezed modeller
        │   ├── services/      # dış dünya: API / Firestore / lokal DB
        │   └── repositories/  # tek doğruluk kaynağı, hata çevirme
        └── ui/
            ├── view_models/   # @riverpod Notifier / AsyncNotifier
            ├── screens/       # route'a bağlı sayfalar
            └── widgets/       # feature'a özel widget'lar
test/                      # lib/ ile aynı yapı
```

Ayrıntılar ve isimlendirme: `references/folder-structure.md`.

## Bağımlılık kuralları (en önemli kısım)

Ok yönünde bağımlılık serbest, tersi **yasak**:

```
Screen/Widget → ViewModel → Repository → Service → (Dio / Firestore / SDK)
```

1. **Widget'lar veri çekmez.** `Dio`, `FirebaseFirestore`, repository ya da service'i widget içinde asla çağırma. Widget sadece `ref.watch(xViewModelProvider)` yapar ve ViewModel metodlarını çağırır.
2. **ViewModel** sadece repository'leri bilir; Service'i, Dio'yu, `BuildContext`'i bilmez. Navigasyon ve SnackBar UI'da yapılır.
3. **Repository** bir veya birden çok service'i kullanır, DTO → model dönüşümünü ve hata çevirmeyi (`DioException`/`FirebaseException` → `AppException`) yapar. Repository'ler birbirini çağırmaz; iki repository birleşecekse bunu ViewModel ya da (gerekirse) bir use-case yapar.
4. **Service** durumsuzdur, tek bir veri kaynağını sarar, ham veri (DTO/JSON) döner, hata çevirmez.
5. `core/` hiçbir `features/` klasörünü import etmez. Feature'lar birbirinin `ui/` klasörünü import etmez; paylaşılan şey `core/`'a taşınır.
6. Domain/use-case katmanı **opsiyoneldir**: sadece birden çok repository'yi birleştiren veya ViewModel'ler arasında tekrar eden iş mantığı varsa `features/<x>/domain/use_cases/` aç. Varsayılan olarak açma.

## Hata yönetimi

- Repository'ler hata durumunda `core/errors/app_exception.dart` içindeki tipli `AppException` alt sınıflarını **fırlatır** (throw). Tanım: `references/app-exception.md`.
- ViewModel'ler `AsyncValue.guard(...)` kullanır; hata `AsyncError` olarak UI'a gider.
- UI, `AsyncValue`'yu `switch` ile tam olarak ele alır (data / error / loading). Kullanıcıya gösterilen mesaj `AppException.message`'dan gelir, ham `e.toString()` gösterilmez.

## Kod stili

- Modeller `freezed` ile, immutable. JSON gerekiyorsa `fromJson`.
- Provider'lar codegen ile: fonksiyonel provider'da parametre tipi `Ref ref`.
- Provider'lar varsayılan olarak autoDispose'dur; uygulama ömrü boyunca yaşaması gerekenler (Dio, auth, router) `@Riverpod(keepAlive: true)`.
- `async` işlemden sonra state yazmadan önce `if (!ref.mounted) return;`.
- `print` yerine `debugPrint` veya `dart:developer` `log`.
- Sabit metinleri doğrudan widget'a gömme; uygulama çok dilli olacaksa `gen-l10n` (bkz. project-setup).
- `.g.dart` ve `.freezed.dart` dosyalarını elle düzenleme; değişiklikten sonra build_runner çalıştır.

Desen örnekleri (provider, ViewModel, UI'da AsyncValue): `references/riverpod-patterns.md`.

## İş akışı

- **Yeni proje:** `references/project-setup.md` adımlarını sırayla uygula; dokümanlar için `flutter-project-docs`.
- **Mevcut (flutter-kit yapısında olmayan) proje:** önce `flutter-migrate-existing` — doğrudan kural uygulamaya başlama.
- **Yeni feature:** `flutter-feature-scaffold` skill'ini kullan.
- **REST API / backend:** `flutter-api-data` skill'i.
- **Firebase:** `flutter-firebase` skill'i.
- **Test:** `flutter-testing` skill'i.
- **Tasarımdan ekran / ortak widget'lar / tekrar analizi:** `flutter-ui-components` skill'i.
- **Kod seviyesi temizlik** (boyut sınırları, widget çıkarma, sabitler, isimlendirme): `flutter-clean-code` skill'i — her kod yazımında geçerlidir.
- Kod ürettikten sonra: `dart run build_runner build -d`, ardından `flutter analyze`. Analyzer uyarısı bırakma.

## Kod inceleme kontrol listesi

Mevcut kodu incelerken şunlara bak ve ihlalleri dosya:satır ile raporla:
- [ ] Widget içinde Dio/Firestore/repository çağrısı var mı?
- [ ] ViewModel'de `BuildContext`, navigasyon veya Service kullanımı var mı?
- [ ] Hata yakalanmadan UI'a ham exception mı gidiyor?
- [ ] `AsyncValue`'nun loading/error durumu ele alınmış mı?
- [ ] Legacy Riverpod (`StateNotifierProvider`, `StateProvider`, `ChangeNotifierProvider`) var mı?
- [ ] Freezed sınıfları `abstract`/`sealed` mi?
- [ ] `core/` → `features/` importu var mı?
- [ ] Gizli bilgi (API key, şifre) koda gömülmüş mü?
