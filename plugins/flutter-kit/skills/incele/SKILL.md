---
name: incele
description: Flutter kodunu flutter-kit kurallarına göre inceler ve rapor verir — mimari katmanlar, temiz kod, tekrar eden widget'lar, testler, dokümanlar. Kod değiştirmez; düzeltmeyi kullanıcı onaylarsa yapar. "İncele", "review", "kurallara uyuyor mu", "kontrol et" isteklerinde ve /flutter-kit:incele komutuyla kullan.
argument-hint: "[dosya, klasör veya boş = son değişiklikler]"
---

# Kod İnceleme

Kapsam: $ARGUMENTS — boşsa `git status` ve `git diff` (son commit'e göre) ile değişen dosyalar; değişiklik yoksa tüm `lib/`.

**Bu aşamada dosya değiştirme.** Önce rapor, onay gelirse düzeltme.

## Kontroller

1. **Mimari** — `flutter-architecture` kontrol listesi: katman ihlalleri, `core → features` importu, legacy Riverpod, freezed `abstract/sealed`.
2. **Temiz kod** — `flutter-clean-code` teslim kontrol listesi: boyut sınırları, `_buildX`, `build` içinde mantık, gömülü değerler, `!`, boş `catch`, isimlendirme.
3. **Tekrar** — `flutter-ui-components` skill'ini yükle; onun dizinindeki `scripts/find_widget_duplicates.py lib/` script'ini çalıştır (Python 3).
4. **Test** — değişen repository/ViewModel'lerin testi var mı; çalıştırılabiliyorsa `flutter test`.
5. **Analiz** — çalıştırılabiliyorsa `flutter analyze`.
6. **Doküman** — yeni özellik `docs/MIMARI.md`'de var mı, yeni paket `docs/KARARLAR.md`'de var mı.
7. **Güvenlik** — koda gömülü şifre/anahtar/connection string (değeri yazma, sadece dosya:satır).

Proje taşınıyorsa (`docs/GECIS.md` var) eski yapıdaki dosyaları ihlal olarak sayma; ayrı bir "eski yapı" notu düş.

## Rapor formatı

```markdown
## İnceleme: <kapsam>

| # | Önem | Dosya:satır | Sorun | Öneri |
|---|---|---|---|---|
| 1 | 🔴 Yüksek | lib/features/stock/ui/screens/stock_screen.dart:12 | Ekranda Dio çağrısı | StockService + StockRepository'ye taşı |
| 2 | 🟡 Orta | ... | ... | ... |
| 3 | ⚪ Düşük | ... | ... | ... |

**Komutlar:** flutter analyze: <sonuç / çalıştırılmadı> · flutter test: <sonuç / çalıştırılmadı>
**Özet:** <1-2 cümle>. Düzeltmemi ister misin? (hepsi / sadece yüksek / seçtiklerin)
```

Önem: 🔴 katman ihlali, güvenlik, veri kaybı riski, derlenmeyen kod · 🟡 temiz kod kuralları, eksik test · ⚪ isimlendirme, doküman.
