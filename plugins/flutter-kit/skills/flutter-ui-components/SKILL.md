---
name: flutter-ui-components
description: Flutter UI'ı yeniden kullanılabilir widget'lara ayırma — tasarımdan (ekran görüntüsü, mockup, Figma) widget ağacı, tasarım token'ları ve ortak bileşen çıkarma; mevcut kodda tekrar eden widget'ları bulup core/widgets'a taşıma; bileşen kataloğunu güncel tutma. "Bu tasarımı koda dök", "tekrar eden widget'ları bul", "ortak bileşen çıkar", "UI kit / design system" isteklerinde kullan.
---

# UI Bileşenleri: Tasarımdan Widget'a, Tekrardan Ortak Bileşene

`flutter-architecture` ve `flutter-clean-code` kuralları geçerlidir. Bu skill'in iki iş akışı ve bir kalıcı kaydı var:

- **A. Tasarım → widget'lar:** görselden bileşen ağacı ve token'lar çıkar, sonra kodla.
- **B. Tekrar analizi:** mevcut kodda benzer widget'ları bul, ortak bileşene çevir.
- **Katalog:** `lib/core/widgets/CATALOG.md` — projedeki ortak bileşenlerin listesi. Her iki akış da önce bunu okur, sonunda günceller. Biçim: `references/catalog-format.md`.

## Ortak bileşen nereye gider?

| Kullanım | Yer |
|---|---|
| Sadece bir ekranda | O ekranın dosyasında private (`_OrderHeader`) veya `features/<f>/ui/widgets/` |
| Bir feature'da birden çok ekranda | `features/<f>/ui/widgets/` |
| 2+ feature'da | `core/widgets/` + katalog kaydı |

**Erken soyutlama yapma:** Bir şey ikinci kez görüldüğünde not al, **üçüncü** kullanımda (veya tasarımda açıkça aynı bileşen olduğu belliyse) `core/widgets/`'a çıkar. Görünüşü benzeyen ama farklı amaçları olan iki widget'ı zorla birleştirip 10 parametreli bir canavar yaratma.

## A. Tasarımdan widget'lara

Girdi: ekran görüntüsü / mockup görseli, Figma linki veya frame'i (Figma MCP bağlıysa oradan oku), ya da yazılı tarif.

1. **Kataloğu oku.** `core/widgets/CATALOG.md` varsa mevcut bileşenleri öğren; tasarımdaki bir parça mevcut bir bileşenle eşleşiyorsa onu kullan, yenisini yazma.
2. **Token'ları çıkar** (renkler, boşluklar, köşe yarıçapı, yazı boyutları). Mevcut tema/`AppSpacing` değerleriyle eşleştir; ölçekteki en yakın değere yuvarla (13px → `AppSpacing.md` = 16). Gerçekten yeni bir değer gerekiyorsa temaya/sabitlere ekle — widget'a gömme.
3. **Bileşen ağacını çıkar** ve koda başlamadan kullanıcıya göster (`references/design-to-widgets.md` formatında): ekran → bölümler → bileşenler; her bileşenin yeri (private / feature / core), parametreleri, tasarımda kaç kez tekrarlandığı, katalogdan eşleşen var mı.
4. **Kullanıcı onaylarsa kodla**, içten dışa: önce `core/widgets/` bileşenleri, sonra feature widget'ları, en son ekran.
5. **Durumları unutma:** tasarımda sadece "dolu" hal varsa bile yükleniyor / boş / hata hallerini ortak `AppLoadingView`, `AppEmptyView`, `AppErrorView` ile ekle.
6. **Kataloğu güncelle.**

Görselden okurken tahmin ettiğin değerleri (renk kodu, piksel) "yaklaşık" olarak işaretle; kesin değer için kullanıcıdan Figma/hex iste.

## B. Mevcut koddaki tekrarı bulma

1. Script'i çalıştır (Python 3, ek paket gerekmez):
   ```bash
   python3 <bu skill'in dizini>/scripts/find_widget_duplicates.py lib/
   ```
   Çıktı: birbirine benzeyen widget blokları (iç içe olanlar dahil — ör. farklı kartların içindeki aynı rozet), benzerlik oranı ve dosya:satır; widget döndüren `_buildX` metotları; 300 satırı aşan dosyalar; gömülü renk/padding/font sayısı. Hassasiyet: `--min-similarity 0.8`, `--min-lines 5` (varsayılanlar). Makine okunur çıktı: `--json`.
2. Sonuçları **sen yorumla** — script sadece aday gösterir. Her grup için karar ver:
   - Aynı amaç, küçük farklar → ortak bileşen, farklar parametre olur.
   - Benzer görünüm, farklı amaç → ayrı kalsın, sadece ortak token'ları kullansınlar.
   - Aynı dosyada tekrar → private widget.
3. Kullanıcıya **öneri raporu** sun (`references/design-to-widgets.md` §Tekrar raporu): grup, önerilen bileşen adı ve imzası, etkilenen dosyalar, tahmini kazanç. Onay almadan büyük refactor yapma.
4. Onaylanınca: bileşeni yaz → kullanım yerlerini tek tek değiştir → her adımda `flutter analyze` → varsa testler → kataloğu güncelle.

## Ortak bileşen yazım kuralları

- İsim **amaçtan** gelir, görünüşten değil: `StatusBadge`, `SectionHeader`, `PrimaryButton` — `BlueRoundedBox` değil.
- Ön ek: proje geneli bileşenler `App` ile başlar (`AppCard`, `AppTextField`); feature'a özel olanlar feature adıyla (`OrderTile`).
- Parametreler minimum: zorunlu içerik `required`, görünüm varyantları `enum` (`AppButtonVariant.primary/secondary/text`) — 5 ayrı `bool` değil.
- Renk/boşluk parametresi alma; varyant al, değeri temadan çöz.
- Her `core/widgets/` bileşeni `const` constructor'a sahip, tek dosyada, ≤ 150 satır, iş mantığı ve provider erişimi **yok** (sadece parametre ve callback).
- Her yeni `core/widgets/` bileşeni için en az bir widget testi (`flutter-testing`).

Örnek bileşen seti ve kod: `references/core-widgets.md`.
