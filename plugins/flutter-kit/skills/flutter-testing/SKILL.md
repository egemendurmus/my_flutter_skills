---
name: flutter-testing
description: "Flutter testleri: repository (mocktail), ViewModel (ProviderContainer), widget testleri, Firebase fake'leri. Test yazarken veya test çalışmıyorken kullan."
---

# Flutter Testleri

`flutter-architecture` katmanları test stratejisini belirler: her katman bir alttakini mock'layarak test edilir. Şablonlar: `references/test-templates.md`.

## Ne test edilir (öncelik sırası)

1. **Repository** — hata çevirme ve dönüşümler. En ucuz, en değerli test.
2. **ViewModel** — state geçişleri: yükleniyor → veri / hata, aksiyonlardan sonra state.
3. **Widget/Ekran** — kritik ekranlarda: veri gösteriliyor mu, hata ve boş durum görünüyor mu, buton doğru ViewModel metodunu çağırıyor mu.
4. **Integration test** (`integration_test/`) — sadece giriş, ödeme gibi kritik akışlar için, kullanıcı isterse.

Service'leri unit test etme (Dio/Firestore'u sarmaktan başka iş yapmazlar); onları repository testinde mock'la.

## Araçlar

- `flutter_test` + `mocktail` (codegen'siz mock).
- Riverpod: `ProviderContainer.test(overrides: [...])` — test bitince otomatik dispose olur. `new_feature.sh` tüm Riverpod 3 sürümlerinde çalışsın diye `ProviderContainer(retry: ..., overrides: [...])` + `addTearDown(container.dispose)` üretir; ikisi eşdeğerdir, dosya içinde tek biçim kullan.
- Widget: `ProviderScope(overrides: [...], child: MaterialApp(home: ...))`.
- Firebase: `fake_cloud_firestore`, `firebase_auth_mocks`.

## Kurallar

- Test dosyası `lib/` yolunu aynalar: `lib/features/orders/data/repositories/orders_repository.dart` → `test/features/orders/data/repositories/orders_repository_test.dart`.
- Override'lar **en dar katmanda**: ViewModel testinde repository'yi, widget testinde ViewModel'i veya repository'yi override et. Dio/Firestore'u widget testinde override etme.
- `setUp` içinde her test için yeni mock oluştur.
- Gerçek ağ çağrısı, gerçek Firebase, `Future.delayed` ile bekleme yok.
- Riverpod 3 başarısız provider'ları otomatik yeniden dener; hata testlerinde bunu kapat: `ProviderContainer.test(retry: (_, _) => null, ...)` / `ProviderScope(retry: (_, _) => null, ...)`.
- Test isimleri davranışı anlatır: `'404 gelince NotFoundException fırlatır'`.
- Ortak mock'lar ve `pumpApp` yardımcısı `test/helpers/` altında.

## Komutlar

```bash
flutter test                                   # tümü
flutter test test/features/orders              # bir feature
flutter test --coverage                        # coverage/lcov.info
flutter test --name "NotFoundException"        # isimle filtre
```

Test yazdıktan sonra çalıştır; kırmızı test bırakma. Test, gerçek bir hatayı gösteriyorsa testi değil kodu düzelt ve kullanıcıya bildir.
