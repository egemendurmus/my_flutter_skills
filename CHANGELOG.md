# Değişiklikler

## 1.8.0 — 2026-11-23

### Yeni
- `tests/hook_test.sh` + `tests/hook_fixtures/`: kural hook'u için hızlı testler (Flutter gerekmez). Her kural için doğru uyarı çıkıyor mu, yanlış alarm var mı; hook modu (JSON stdin) da test edilir. CI'da e2e'den önce çalışır.
- CI artık macOS'ta da çalışır (Linux, Windows, macOS).

### İyileştirmeler
- `new_feature.sh` 1065 → ~265 satır: Dart şablonları `templates/feature/*.dart.tmpl` dosyalarına taşındı. Üretilen kod birebir aynı.
- README: macOS / Linux / Windows (Git Bash) gereksinimleri netleşti; şablon biçimi belgelendi.

### Düzeltmeler
- Hook, yorum satırındaki `Dio()` / `FirebaseFirestore.instance` metnini de ihlal sayıyordu.
- `tests/e2e.sh`: `grep -E '\s'` macOS'un BSD grep'inde güvenilir değil → `[[:space:]]`.

## 1.7.0 — 2026-11-23

### Yeni
- `scripts/setup_core.sh`: `lib/core/`, `main.dart`, `app.dart` dosyalarını reference'lardaki koddan tek komutla kurar (`yeni-proje`, `flutter-migrate-existing`).
- `new_feature.sh` liste ekranının rotasını router'a ekler; ilk feature açılış ekranı olur.
- `new_feature.sh --with-detail`: detay ekranı + family ViewModel + test, listeden tıklayınca açılır.
- `new_feature.sh --with-form`: oluştur/düzenle formu + form ViewModel + test; service/repository'ye `create`/`update`, alt rotalar otomatik.
- `tests/e2e.sh` + GitHub Actions: skill kodu gerçek bir Flutter projesinde derleniyor, analizden ve testten geçiyor mu (her push + haftalık, Linux ve Windows).

### Düzeltmeler
- Windows: hook'lar `C:\...` yollarında hiç çalışmıyordu; Microsoft Store `python3` kısayolu artık atlanıyor.
- Windows: `find_widget_duplicates.py` Türkçe karakterde çöküyordu.
- Dio hata çevirici Dio 5.11 ile derlenmiyordu (`transformTimeout`); `logPrint: debugPrint` tip hatası.
- Firebase provider ve hata çevirici örneklerinde eksik import'lar.
- Script'in ürettiği Firebase ViewModel testi kırmızıydı (autoDispose provider dinleyicisiz kapanıyordu).
- Router örneği olmayan ekranlara işaret ediyordu; derlenen, işaretli başlangıç router'ı.
- `only_throw_errors` ve `no_runtimetype_tostring` uyarıları.
- `build_runner build -d` → `build_runner build` (yeni build_runner `-d`'yi kaldırdı).
- Örneklerdeki kişisel alan adları `example.com` ile değiştirildi.
