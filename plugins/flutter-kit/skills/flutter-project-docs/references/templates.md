# Doküman şablonları

`<...>` alanlarını projenin gerçek bilgileriyle doldur. Projede karşılığı olmayan bölümü sil, boş başlık bırakma.

---

## §1. README.md (proje kökü)

~~~markdown
# <Uygulama adı>

<Bir cümle: uygulama ne işe yarıyor, kim kullanıyor.>

Son güncelleme: <YYYY-AA-GG>

## Hızlı başlangıç

1. Flutter <3.x> kurulu olmalı: `flutter --version`
2. Ortam dosyası: `cp env/example.json env/dev.json` ve değerleri doldur (değerleri <kimden/nereden> al)
3. Paketler ve kod üretimi:
   ```bash
   flutter pub get
   dart run build_runner build
   ```
4. Çalıştır: `flutter run --dart-define-from-file=env/dev.json`

## Komutlar

| İş | Komut |
|---|---|
| Kod üretimi (model/provider değişince) | `dart run build_runner build` |
| Kod üretimini izle | `dart run build_runner watch -d` |
| Biçimlendir | `dart format .` |
| Analiz | `flutter analyze` |
| Test | `flutter test` |

## Backend

- <REST API adresi ve dokümanı / Firebase proje adı>
- <Test hesabı nereden alınır>

## Dokümanlar — ilk gün bunları oku

1. [Mimari](docs/MIMARI.md) — kod nasıl organize edilmiş (15 dk)
2. [Yeni ekran ekleme](docs/YENI_EKRAN.md) — adım adım rehber (10 dk)
3. [Kararlar](docs/KARARLAR.md) — neden bu paketler/yapı (5 dk)
4. [Ortak bileşenler](lib/core/widgets/CATALOG.md) — yeni widget yazmadan önce bak
~~~

---

## §2. docs/MIMARI.md

~~~markdown
# Mimari

Son güncelleme: <YYYY-AA-GG>

## Tek cümlede

Her özellik `lib/features/<özellik>/` altında kendi klasöründe durur; içinde `data/` (veri) ve `ui/` (ekran) katmanları vardır. Ekranlar veriye doğrudan erişmez.

## Katmanlar

    Ekran (Screen/Widget)  →  ViewModel  →  Repository  →  Service  →  API / Firebase
         ne gösterilir        durum + aksiyon   tek doğruluk     dış dünya
                                                kaynağı, hata
                                                çevirme

| Katman | Görevi | Yapamaz |
|---|---|---|
| Screen / Widget | Durumu göster, kullanıcı aksiyonunu ViewModel'e ilet | API/Firebase çağırmak |
| ViewModel | Ekranın durumunu tutar (yükleniyor/veri/hata), aksiyonları çalıştırır | `BuildContext`, navigasyon, Dio |
| Repository | Veriyi getirir/kaydeder, hataları `AppException`'a çevirir | UI'ı bilmek |
| Service | Tek bir kaynağa (API, Firestore) ham istek atar | Hata yorumlamak |

## Gerçek örnek: <Sipariş listesi> ekranı açılınca ne olur?

1. `<OrdersScreen>` (`lib/features/<orders>/ui/screens/<orders_screen.dart>`) `ref.watch(<ordersViewModelProvider>)` ile durumu izler.
2. `<OrdersViewModel>.build()` → `<OrdersRepository>.fetchOrders()` çağırır.
3. Repository → `<OrdersService>.getOrders()` → `GET <API_BASE_URL>/orders`.
4. Hata olursa Repository `DioException`'ı `NetworkException` vb.'ye çevirir; ekran `AppErrorView` gösterir.
5. Başarılıysa ekran listeyi `<OrderTile>` widget'larıyla çizer.

## Klasör haritası

    lib/
    ├── main.dart / app.dart     uygulama girişi, tema, router
    ├── core/                    tüm özelliklerin ortak kullandığı kod
    │   ├── config/              ortam değişkenleri (env)
    │   ├── constants/           boşluk, köşe, süre, asset sabitleri
    │   ├── errors/              AppException tipleri
    │   ├── extensions/          tarih/para formatlama, context kısayolları
    │   ├── network/             Dio, token interceptor
    │   ├── router/              tüm rotalar (routes.dart)
    │   ├── theme/               renk ve yazı tipleri
    │   └── widgets/             ortak widget'lar (CATALOG.md)
    └── features/
        └── <özellik>/
            ├── data/  models/ services/ repositories/
            └── ui/    view_models/ screens/ widgets/

## Nereye ne konur?

| Yazacağım şey | Yeri |
|---|---|
| Yeni ekran | `features/<özellik>/ui/screens/` |
| Sadece bu özellikte kullanılan widget | `features/<özellik>/ui/widgets/` |
| 2+ özellikte kullanılan widget | `core/widgets/` + CATALOG.md |
| API çağrısı | `features/<özellik>/data/services/` |
| Model (JSON) | `features/<özellik>/data/models/` (freezed) |
| Renk, yazı stili | `core/theme/` — widget'a renk yazılmaz |
| Kullanıcıya görünen metin | <l10n .arb / core/constants/app_strings.dart> |
| Yeni rota | `core/router/routes.dart` + `app_router.dart` |

## Özellikler

| Özellik | Klasör | Ne yapar | Veri kaynağı |
|---|---|---|---|
| <auth> | `features/auth` | <Giriş, kayıt, şifre sıfırlama> | <Firebase Auth> |
| <orders> | `features/orders` | <Sipariş listesi ve detayı> | <REST /orders> |

## Temel kurallar (özet)

- Ekran veri çekmez; ViewModel üzerinden gider.
- Dosya ≤ 300 satır, `build` ≤ 60 satır; büyüyorsa widget'lara böl.
- Gömülü renk/padding/metin yok.
- Model ve provider değişince `dart run build_runner build`.
- Commit öncesi: `dart format . && flutter analyze && flutter test`.
~~~

---

## §3. docs/YENI_EKRAN.md

~~~markdown
# Yeni ekran / özellik ekleme

Son güncelleme: <YYYY-AA-GG>

Örnek olarak mevcut `<orders>` özelliğine bak; aynı yapıyı kopyala.

## Adımlar

1. **Klasör:** `lib/features/<yeni_ozellik>/data/` ve `ui/` aç.
2. **Model:** `data/models/<model>.dart` — freezed. Örnek: `<lib/features/orders/data/models/order.dart>`
3. **Service:** `data/services/<x>_service.dart` — API/Firestore çağrıları. Örnek: `<...>`
4. **Repository:** `data/repositories/<x>_repository.dart` — Service'i çağırır, hataları çevirir. Örnek: `<...>`
5. **ViewModel:** `ui/view_models/<ekran>_view_model.dart` — `@riverpod` sınıfı. Örnek: `<...>`
6. **Ekran:** `ui/screens/<ekran>_screen.dart` — `ConsumerWidget`, loading/hata/boş durumları `AppLoadingView` / `AppErrorView` / `AppEmptyView` ile.
7. **Rota:** `core/router/routes.dart`'a sabit, `app_router.dart`'a `GoRoute` ekle.
8. **Kod üretimi:** `dart run build_runner build`
9. **Test:** `test/features/<yeni_ozellik>/` altına en az repository ve ViewModel testi.
10. **Kontrol:** `dart format . && flutter analyze && flutter test`
11. **Doküman:** `docs/MIMARI.md` → Özellikler tablosuna satır ekle.

## Sık yapılan hatalar

| Hata | Doğrusu |
|---|---|
| Ekranda `Dio()` veya `FirebaseFirestore.instance` | ViewModel → Repository → Service |
| `_buildHeader()` metodu | Ayrı widget sınıfı |
| `Color(0xFF...)`, `EdgeInsets.all(13)` | Tema ve `AppSpacing` |
| `part` satırını unutmak / build_runner çalıştırmamak | Her model/provider dosyasında `part '<dosya>.g.dart';` |

## Claude Code ile

"<özellik> için liste ve detay ekranı ekle, veri <kaynak>'tan geliyor" yazmak yeterli; flutter-kit skill'leri bu adımları uygular. Sonucu yine de bu listeyle kontrol et.
~~~

---

## §4. docs/KARARLAR.md

~~~markdown
# Mimari kararlar

Son güncelleme: <YYYY-AA-GG>

Yeni bir paket eklerken veya yapıyı değiştirirken buraya kısa bir kayıt ekle. Eski kararları silme; değiştiyse "Yerine geçen: #N" yaz.

| # | Tarih | Karar | Neden | Değerlendirilen alternatifler |
|---|---|---|---|---|
| 1 | <tarih> | Feature-first klasör yapısı + MVVM (Flutter resmi mimari rehberi) | Her özellik kendi klasöründe; yeni gelen ilgili kodu tek yerde bulur | Katman-first (lib/ui, lib/data) |
| 2 | <tarih> | State yönetimi ve DI: Riverpod 3 (codegen) | Az kod, test edilebilir, DI dahili | Bloc, Provider, GetX |
| 3 | <tarih> | Navigasyon: go_router | Resmi destekli, deep link, redirect | Navigator 1.0, auto_route |
| 4 | <tarih> | HTTP: Dio | Interceptor, iptal, timeout | http |
| 5 | <tarih> | Modeller: freezed + json_serializable | Immutable, copyWith, JSON | Elle yazılmış sınıflar |
| 6 | <tarih> | Lint: very_good_analysis | Sıkı ve yaygın kural seti | flutter_lints |
| 7 | <tarih> | <Backend: REST API / Firebase> | <neden> | <...> |
~~~
