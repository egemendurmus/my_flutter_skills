---
name: flutter-clean-code
description: Flutter/Dart kodunda okunabilirlik ve temiz kod kuralları — dosya/widget/fonksiyon boyut sınırları, widget'ı ayrı sınıfa çıkarma, build içinde mantık olmaması, isimlendirme, sabitler (spacing, renk, metin), import düzeni, yorum ve git alışkanlıkları. Her Flutter kodu yazımında, refactor'da, "bu kod spagetti oldu / temizle / düzenle" isteklerinde ve kod incelemede kullan.
---

# Flutter Temiz Kod Kuralları

Amaç: her dosya tek bir şey yapar, bir yabancı açtığında 30 saniyede ne yaptığını anlar. `flutter-architecture` katmanları **nerede** duracağını, bu skill **nasıl** yazılacağını belirler. Kötü/iyi örnekler: `references/examples.md`.

Bu kurallar öneri değil, varsayılandır. Kullanıcı açıkça istemedikçe ihlal eden kod yazma; mevcut kodda ihlal görürsen raporla.

## 1. Boyut sınırları

| Ne | Hedef | Üst sınır → ne yap |
|---|---|---|
| Dosya | ≤ 200 satır | 300 → parçala (widget'ları `widgets/`, yardımcıları ayrı dosyaya) |
| `build` metodu | ≤ 40 satır | 60 → alt widget'lara böl |
| Fonksiyon / metot | ≤ 25 satır | 40 → yardımcı metotlara böl |
| Parametre sayısı | ≤ 4 | fazlası → parametre nesnesi (freezed) veya named parametreler |
| İç içe girinti (if/for) | ≤ 2 seviye | early return, guard clause |
| Widget ağacı derinliği (tek build'de) | ≤ 5–6 seviye | alt widget'a çıkar |

Satır sayımına üretilmiş dosyalar (`*.g.dart`, `*.freezed.dart`) dahil değildir.

## 2. Widget kuralları

1. **Bir dosyada bir public widget.** Sadece o dosyada kullanılan çok küçük private widget'lar (≤ 20 satır) aynı dosyada kalabilir.
2. **`_buildHeader()` gibi widget döndüren metotlar yazma** → ayrı `StatelessWidget` sınıfı yap (`_Header` veya `widgets/order_header.dart`). Sebep: ayrı sınıf `const` olabilir, kendi başına rebuild edilir, test edilebilir, okunur.
3. **Mümkün olan her yerde `const`** constructor ve `const` kullanımı.
4. **Widget'a ihtiyacından fazlasını verme:** `OrderTile` tüm `Order`'ı alabilir, ama `PriceText` sadece `double amount` almalı.
5. **`build` içinde mantık yok:** hesaplama, filtreleme, sıralama, tarih/para formatlama, uzun koşullar → ViewModel'e, modelde getter'a veya `core/extensions/` altındaki extension'a.
6. **Ekran (`screens/`) sadece iskelettir:** `Scaffold` + state'e göre hangi bölümün gösterileceği. İçerik `widgets/` altındaki bileşenlerde.
7. **Callback'leri isimlendir:** `onPressed: () { ...10 satır... }` yazma; ViewModel metodu çağır veya private bir metoda taşı.
8. `StatefulWidget` sadece widget'a ait geçici UI durumu için (animasyon controller'ı, `TextEditingController`, `FocusNode`, açık/kapalı). İş verisi ViewModel'de.

## 3. Sabit değerler — gömülü sayı/renk/metin yok

| Tür | Nerede | Kullanım |
|---|---|---|
| Boşluk/padding | `core/constants/app_spacing.dart` | `AppSpacing.md`, `AppGap.md` |
| Köşe yarıçapı, süre | `core/constants/app_radius.dart`, `app_durations.dart` | `AppRadius.card` |
| Renk | Tema (`ColorScheme`) | `context.colors.primary` |
| Yazı stili | Tema (`TextTheme`) | `context.textTheme.titleMedium` |
| Kullanıcıya görünen metin | `gen-l10n` (`.arb`), tek dilliyse `core/constants/app_strings.dart` | `context.l10n.ordersTitle` |
| Asset yolu | `core/constants/app_assets.dart` | `AppAssets.logo` |
| API yolu | İlgili Service içinde `static const` | `_path = '/orders'` |

`Color(0xFF...)`, `EdgeInsets.all(13)`, `TextStyle(fontSize: 17)` gibi değerlerin widget içinde görülmesi ihlaldir (tema ve sabit dosyaları hariç). Şablonlar: `references/constants-and-extensions.md`.

## 4. İsimlendirme

- Tam kelime kullan, kısaltma yok: `customerName`, `cn` değil. Kabul edilen kısaltmalar: `id`, `url`, `api`, `dto`, `ui`.
- `bool` → `is/has/can/should`: `isLoading`, `hasMore`, `canSubmit`.
- Metotlar fiil: `fetchOrders`, `submit`, `toggleFavorite`. Getter'lar isim: `totalAmount`, `isEmpty`.
- Event callback'leri `on` + olay: `onOrderTap`, `onRetry`.
- Liste değişkenleri çoğul: `orders`, tekil eleman `order`. `list`, `data`, `item`, `temp`, `value2` gibi isimler yok.
- Private üyeler `_` ile; bir dosya dışından kullanılmayan her şey private.
- Kod ve tanımlayıcılar İngilizce; kullanıcıya görünen metinler ve (gerekirse) yorumlar Türkçe olabilir.

## 5. Fonksiyon ve akış

- Tek sorumluluk: isminde "ve" geçiyorsa (`validateAndSave`) ikiye böl.
- Early return / guard clause:
  ```dart
  if (current == null || !current.hasMore) return;
  ```
- `!` (null assertion) kullanma; `if (x case final value?)`, `?.`, `??` veya erken return kullan. İstisna: doğrulanmış API yanıtında `res.data!`.
- Uzun `if-else` zincirleri yerine `switch` ifadesi ve pattern matching.
- Boş `catch {}` yasak. Ya çevir ve fırlat, ya logla ve kullanıcıya göster.
- `dynamic` kullanma (JSON parse sınırı hariç); tip belirt.

## 6. Import ve dosya düzeni

- `lib/` içinde her zaman `package:<uygulama>/...` import'u (very_good_analysis bunu zorunlu kılar).
- Sıra: `dart:` → `package:` (üçüncü parti) → `package:<uygulama>/` → `part`. Gruplar arasında boş satır.
- Dosya içi sıra: sabitler → constructor → alanlar → public metotlar → private metotlar → provider tanımı (en altta).
- Kullanılmayan import, değişken, metot ve **yorum satırına alınmış kod bırakma**. Git geçmişi zaten saklar.

## 7. Yorumlar

- "Ne" yaptığını yazma, kod söylüyor. "Neden" yaptığını yaz: iş kuralı, backend tuhaflığı, geçici çözüm.
- `core/` altındaki public API'lere `///` dartdoc.
- `// TODO(serdar): ...` formatında, sahipli ve açıklamalı TODO.

## 8. Biçim ve araçlar

- `dart format .` — tartışmasız tek biçim. Çok satırlı argüman listelerinde sondaki virgül.
- `flutter analyze` sıfır uyarı. Uyarıyı `// ignore:` ile susturma; zorunluysa nedenini yanına yaz.
- `dart fix --apply` otomatik düzeltmeler için.

## 9. Çalışma alışkanlıkları (git)

- Her feature/bug için ayrı branch: `feature/orders-list`, `fix/login-timeout`.
- Küçük, tek amaçlı commit'ler. Mesaj formatı (Conventional Commits): `feat(orders): sipariş listesi eklendi`, `fix(auth): token yenileme döngüsü`, `refactor:`, `test:`, `chore:`.
- Commit öncesi: `dart format .` → `flutter analyze` → `flutter test`.
- Üretilen kod (`*.g.dart`, `*.freezed.dart`) ayrı ve okunmayan değişikliklerdir; review'da atla.

## Refactor isteği gelince

1. Dosyayı oku, yukarıdaki kurallara göre ihlalleri listele (dosya:satır).
2. Önce davranışı koruyan mekanik adımlar: widget çıkarma, sabitleri taşıma, isimlendirme.
3. Sonra katman ihlallerini düzelt (`flutter-architecture`): widget'taki veri çağrısını ViewModel'e taşı vb.
4. Her adımdan sonra `flutter analyze`; test varsa `flutter test`.
5. Kullanıcıya önce/sonra özetini ver: hangi dosyalar oluştu, ne taşındı.

## Teslim öncesi kontrol listesi

- [ ] Hiçbir dosya 300 satırı, hiçbir `build` 60 satırı geçmiyor
- [ ] Widget döndüren `_buildX()` metodu yok
- [ ] `build` içinde formatlama/hesaplama yok
- [ ] Gömülü renk, padding, font boyutu, kullanıcı metni yok
- [ ] `!`, `dynamic`, boş `catch` yok
- [ ] İsimler tam ve anlamlı, bool'lar `is/has/can`
- [ ] Yorum satırına alınmış kod, kullanılmayan import yok
- [ ] `dart format` + `flutter analyze` temiz
