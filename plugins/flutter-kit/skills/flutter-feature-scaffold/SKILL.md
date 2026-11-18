---
name: flutter-feature-scaffold
description: Flutter projesine yeni bir feature/ekran/modül ekler — model, service, repository, ViewModel, ekran, rota ve testleri doğru sırayla oluşturur. "Yeni ekran ekle", "X feature'ını oluştur", "sipariş listesi sayfası yap", "CRUD ekranı" gibi isteklerde kullan.
---

# Yeni Feature Oluşturma

Bu skill `flutter-architecture` kurallarına dayanır; o kurallar geçerlidir. Kod şablonları: `references/feature-template.md`.

## 0. Önce netleştir (eksikse kısaca sor)

- Feature adı (tekil iş alanı, `snake_case`): ör. `orders`
- Veri kaynağı: REST API mi (`flutter-api-data`), Firestore mu (`flutter-firebase`), lokal mi?
- Ekranlar: liste? detay? form (oluştur/düzenle)?
- Modelin alanları. Kullanıcı örnek JSON verebiliyorsa iste — alanları ondan çıkar.

Kullanıcı ayrıntı vermediyse makul varsayımla devam et ve varsayımları sonunda listele.

## 1. Mevcut projeyi oku

- `pubspec.yaml`: gerekli paketler var mı? Yoksa `flutter-architecture/references/project-setup.md`'deki komutlarla ekle.
- `lib/core/`: `AppException`, Dio provider, router, ortak widget'lar mevcut mu? Mevcut olanı kullan, kopyasını üretme.
- Benzer bir feature varsa onun stilini takip et.

## 2. Dosyaları bu sırayla oluştur

İçten dışa doğru, her katman bir öncekine dayanır:

1. `features/<f>/data/models/<model>.dart` — freezed model
2. `features/<f>/data/services/<f>_service.dart` — ham veri erişimi + provider
3. `features/<f>/data/repositories/<f>_repository.dart` — hata çevirme + provider
4. `features/<f>/ui/view_models/<ekran>_view_model.dart` — `@riverpod` AsyncNotifier/Notifier
5. `features/<f>/ui/widgets/...` — gerekiyorsa feature'a özel widget'lar
6. `features/<f>/ui/screens/<ekran>_screen.dart` — `ConsumerWidget`
7. `core/router/routes.dart` + `app_router.dart` — rota ekle
8. `test/features/<f>/...` — en az repository ve ViewModel testi (`flutter-testing`)

## 3. Codegen ve kontrol

```bash
dart run build_runner build -d
flutter analyze
flutter test test/features/<f>
```

Hata kalırsa düzelt ve tekrar çalıştır. Analyzer temiz olmadan bitmiş sayma. Son olarak `flutter-clean-code` teslim kontrol listesinden geçir (boyut sınırları, `_buildX` yok, gömülü değer yok).

## 4. Kullanıcıya rapor

Kısa bir özet ver:
- Oluşturulan/değiştirilen dosyalar (ağaç olarak)
- Yaptığın varsayımlar (ör. endpoint yolu, alan tipleri)
- Kullanıcının yapması gereken şey varsa (ör. backend endpoint'i, Firestore kuralı)

## Sık yapılan hatalar — yapma

- Ekranda doğrudan `ref.read(ordersRepositoryProvider)` çağırmak → ViewModel üzerinden git.
- ViewModel içinde `context.go(...)` → ViewModel `bool`/sonuç döner, navigasyonu ekran yapar.
- Liste + detay için tek dev ViewModel → her ekrana bir ViewModel; detay için `orderDetailViewModelProvider(id)` (family).
- Form state'ini `StatefulWidget` içinde `setState` ile tutmak → `TextEditingController`'lar widget'ta kalabilir ama doğrulama/gönderme durumu ViewModel'de.
- `part` satırını unutmak veya build_runner'ı çalıştırmamak.
