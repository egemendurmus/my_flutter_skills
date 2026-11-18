# Rapor formatları

## Tasarım analizi (koda başlamadan kullanıcıya göster)

```markdown
## Ekran: Sipariş Listesi

### Token'lar
| Tasarımda | Eşleşen | Not |
|---|---|---|
| Arka plan #F5F7FA | colorScheme.surfaceContainerLowest | yaklaşık |
| Kart köşe ~12px | AppRadius.card | |
| Kart iç boşluk ~14px | AppSpacing.md (16) | yuvarlandı |
| Başlık 18px semibold | textTheme.titleMedium | |
| Durum rozeti yeşil #2E7D32 | YENİ: AppColors.success → temaya extension | onay gerek |

### Bileşen ağacı
OrdersScreen
├── AppBar (standart)
├── OrderFilterBar            [feature]  yeni   — 3 FilterChip
├── ListView
│   └── OrderTile ×N          [feature]  yeni
│       ├── StatusBadge       [core]     yeni   — tasarımda 3 ekranda görülüyor
│       └── PriceText         [core]     katalogda var ✓
└── AppEmptyView              [core]     katalogda var ✓  (tasarımda yok, eklendi)

### Yeni ortak bileşenler
| Bileşen | Yer | İmza |
|---|---|---|
| StatusBadge | core/widgets/status_badge.dart | `StatusBadge({required String label, StatusTone tone = StatusTone.neutral})` |

### Varsayımlar / sorular
- Rozet renkleri tahmini; kesin hex değerleri var mı?
- Liste sonsuz kaydırma mı, sayfalı mı?
```

Figma'dan okunuyorsa token'lar kesin değerdir — "yaklaşık" işareti kullanma, Figma'daki stil/variable adlarını da not al (ör. `color/success/600` → `AppColors.success`).

## Tekrar raporu (B akışı sonunda)

```markdown
## Tekrar eden widget'lar — öneri

### 1. Durum rozeti (4 yerde, %87–94 benzer)
- lib/features/orders/ui/widgets/order_tile.dart:42
- lib/features/orders/ui/screens/order_detail_screen.dart:88
- lib/features/invoices/ui/widgets/invoice_tile.dart:37
- lib/features/shipments/ui/widgets/shipment_card.dart:51

Farklar: renk (3 farklı), metin. → **Öneri:** `core/widgets/status_badge.dart`,
`StatusBadge({required String label, required StatusTone tone})`, `StatusTone { success, warning, danger, neutral }`.
Kazanç: ~60 satır silinir, rozet görünümü tek yerden yönetilir.

### 2. Bölüm başlığı + "Tümünü gör" (2 yerde)
→ Şimdilik bırak (2 kullanım). Üçüncüsü gelirse `SectionHeader`.

### 3. order_detail_screen.dart — `_buildHeader`, `_buildItems`, `_buildSummary`
→ Private widget sınıflarına çevir (aynı dosya). Dosya 412 satır → `widgets/` altına 3 dosya.

### Diğer bulgular
- 23 gömülü `EdgeInsets` değeri, 9 `Color(0x...)`: AppSpacing / tema ile değiştir.
```
