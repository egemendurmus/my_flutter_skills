---
name: flutter-architecture
description: "Flutter ve mobil uygulama projelerinin mimari kuralları (kullanıcı Flutter demese de): feature-first klasörler, MVVM + Riverpod 3, Repository/Service katmanları, paketler. Her Flutter kod işinde kullan."
---

# Flutter Mimarisi

Flutter'ın resmi MVVM rehberi + feature-first + Riverpod 3. Kullanıcı açıkça istemedikçe sapma. `docs/GECIS.md` varsa önce onu oku: `lib/core` ve `lib/features` dışı eski yapıdır, ona bu kurallar dayatılmaz.

**Minimum:** Flutter 3.27+, Dart 3.7+. **Paketler:** flutter_riverpod + riverpod_annotation (+ riverpod_generator), go_router, dio, freezed + json_serializable, very_good_analysis, mocktail; depolama: shared_preferences, sırlar için flutter_secure_storage. Versiyon yazmadan `flutter pub add`. Listede olmayan paketi eklemeden sor. **Kullanma:** GetX, get_it, http, yeni kodda provider/ChangeNotifier, Riverpod legacy (StateProvider, StateNotifier).

## Klasörler

```
lib/
├── main.dart, app.dart
├── core/      config · constants · errors · extensions · firebase · models · network · router · theme · utils · widgets
└── features/<özellik>/
    ├── data/  models/ · services/ · repositories/
    └── ui/    view_models/ · screens/ · widgets/
test/          lib/ ile aynı yapı
```

Kesin (otomatik kontrol edilir): feature içinde dosya sadece bu 6 klasörde durur (gerekirse `domain/use_cases`), açıkta dosya yok. İsimler: `*_view_model.dart`/`XViewModel` (controller/notifier değil), `*_screen.dart`/`XScreen` (page/view değil), `*_service.dart`, `*_repository.dart`. Ayrıntı: `references/folder-structure.md`.

## Katmanlar

```
Screen/Widget → ViewModel → Repository → Service → Dio / Firestore
```

1. Widget veri çekmez; sadece `ref.watch(xViewModelProvider)` ve ViewModel metotları.
2. ViewModel sadece repository bilir; `BuildContext`, navigasyon, Service, Dio yok.
3. Repository: service'leri kullanır, DTO → model, hatayı `AppException`'a çevirir (`references/app-exception.md`). Repository'ler birbirini çağırmaz.
4. Service: durumsuz, tek kaynak, ham veri döner, hata çevirmez.
5. `core/` → `features/` importu yok; feature'lar birbirinin `ui/`'ını import etmez.

## Kod

- Model: freezed (`abstract`/`sealed` class). Provider: `@riverpod` codegen, fonksiyonda `Ref ref`; uygulama ömürlü olanlar `keepAlive: true`.
- ViewModel `AsyncValue.guard`; UI `AsyncValue`'yu `switch` ile tam ele alır; mesaj `AppException.message`'dan. Async sonrası `if (!ref.mounted) return;`.
- `.g.dart`/`.freezed.dart` elle düzenlenmez; değişiklikten sonra `dart run build_runner build -d` ve `flutter analyze`.
- Desenler: `references/riverpod-patterns.md`. Temiz kod sınırları: `flutter-clean-code`.

## Hangi iş, hangi skill

Yeni proje → `yeni-proje` (adımlar: `references/project-setup.md`) · Mevcut proje → `flutter-migrate-existing` · Yeni özellik → `flutter-feature-scaffold` · REST → `flutter-api-data` · Firebase → `flutter-firebase` · Tasarım/ortak widget → `flutter-ui-components` · Test → `flutter-testing` · Dokümanlar → `flutter-project-docs` · İnceleme → `incele`
