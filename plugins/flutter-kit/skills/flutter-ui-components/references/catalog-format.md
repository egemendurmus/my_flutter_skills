# lib/core/widgets/CATALOG.md biçimi

Bu dosya projedeki ortak bileşenlerin **tek listesidir**. Claude yeni UI yazmadan önce okur, bileşen ekleyince/değiştirince günceller. İnsanlar da yeni ekran yaparken önce buraya bakar.

```markdown
# Ortak bileşenler

Son güncelleme: 2026-11-18

## Durum görünümleri
| Bileşen | Dosya | Kullanım | Not |
|---|---|---|---|
| AppLoadingView | app_loading_view.dart | `const AppLoadingView()` | Ortalanmış progress |
| AppEmptyView | app_empty_view.dart | `AppEmptyView(message: ..., action: ...)` | Opsiyonel buton |
| AppErrorView | app_error_view.dart | `AppErrorView(error: e, onRetry: ...)` | AppException mesajını gösterir |

## Butonlar ve girişler
| Bileşen | Dosya | Kullanım | Not |
|---|---|---|---|
| AppButton | app_button.dart | `AppButton(label: ..., onPressed: ..., variant: AppButtonVariant.primary, isLoading: false)` | primary / secondary / text |
| AppTextField | app_text_field.dart | `AppTextField(label: ..., controller: ..., validator: ...)` | |

## Gösterim
| Bileşen | Dosya | Kullanım | Not |
|---|---|---|---|
| AppCard | app_card.dart | `AppCard(child: ..., onTap: ...)` | Tema köşe + boşluk |
| StatusBadge | status_badge.dart | `StatusBadge(label: ..., tone: StatusTone.success)` | |
| SectionHeader | section_header.dart | `SectionHeader(title: ..., onSeeAll: ...)` | |
```

Kurallar:
- Grup başlıkları sabit: Durum görünümleri, Butonlar ve girişler, Gösterim, Düzen, Diyaloglar.
- "Kullanım" sütunu kopyalanıp yapıştırılabilir tek satır olmalı.
- Silinen bileşen katalogdan da silinir.
