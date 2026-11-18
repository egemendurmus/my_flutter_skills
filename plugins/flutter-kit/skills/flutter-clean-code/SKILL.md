---
name: flutter-clean-code
description: "Flutter kodunda okunabilirlik kuralları: boyut sınırları, widget çıkarma, build içinde mantık olmaması, gömülü değer yasağı, isimlendirme. Her Flutter kod yazımında, refactor'da ve \"spagetti oldu / temizle\" isteklerinde kullan."
---

# Temiz Kod

Her dosya tek iş yapar; yabancı biri 30 saniyede anlar. Kullanıcı istemedikçe ihlal eden kod yazma. Bu kuralların çoğu `.dart` dosyası yazılınca otomatik kontrol edilir; ihlal bildirilirse düzelt.

## Sınırlar (tek kaynak — diğer dosyalar buraya atıf yapar)

| Ne | Hedef | Üst sınır |
|---|---|---|
| Dosya | 200 satır | **300** → böl |
| `build` metodu | 40 satır | **60** → alt widget'lara böl |
| Fonksiyon | 25 satır | **40** |
| Parametre | 4 | fazlası → parametre nesnesi |
| İç içe if/for | 2 seviye | early return |

## Kurallar

- Bir dosyada bir public widget. `_buildX()` gibi widget döndüren metot yok → ayrı `StatelessWidget`.
- `build` içinde hesaplama, filtreleme, formatlama yok → ViewModel, model getter'ı veya `core/extensions/`.
- Ekran dosyası sadece iskelet (`Scaffold` + duruma göre bölüm); içerik `widgets/` altında. Mümkün her yerde `const`.
- Gömülü değer yok: boşluk `AppSpacing`/`AppGap`, renk `context.colors`, yazı `context.textTheme`, metin l10n/`AppStrings`, asset `AppAssets`. Şablonlar: `references/constants-and-extensions.md`.
- İsimler tam kelime; bool `is/has/can`; metot fiil; callback `onX`; liste çoğul.
- `!`, `dynamic` (JSON sınırı hariç), boş `catch`, yorum satırına alınmış kod, kullanılmayan import yok.
- Import: `dart:` → `package:` (uygulamanınki dahil, alfabetik) → `part`; `lib/` içinde göreli import yok.
- Bitirirken: `dart fix --apply && dart format . && flutter analyze` sıfır uyarı.

Ayrıntılar (yorum, git ve commit alışkanlıkları, refactor adımları): `references/rules-detail.md`. Önce/sonra örnekleri: `references/examples.md`.
