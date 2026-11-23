---
name: yeni-proje
description: "Sıfırdan Flutter uygulaması kurar: yapı, paketler, core, ilk özellikler, testler, dokümanlar. \"Uygulama yap\", \"yeni proje\" isteklerinde (Flutter denmese de) ve /flutter-kit:yeni-proje ile kullan."
argument-hint: "[uygulama açıklaması]"
---

# Yeni Flutter Projesi

Bu skill bir **sıralı kontrol listesidir**; diğer skill'leri doğru sırada çalıştırır. Adım atlama. Kullanıcının isteği: $ARGUMENTS

## 0. Netleştir (eksikse tek mesajda sor)

- Proje adı (`snake_case`) ve org (varsayılan `com.example`)
- Platformlar (varsayılan: android, ios)
- Backend: REST API mi (adres?), Firebase mi, henüz yok mu (yoksa sahte/mock repository ile başla)
- İlk özellikler (ör. barkod okuma, ürün listesi, stok hareketi) — en fazla 2-3 ile başla
- Özel ihtiyaç var mı: kamera/barkod, çevrimdışı çalışma, çok dil

Kullanıcı "sen karar ver" derse varsayılanları kullan ve sonunda listele.

## 1. Proje iskeleti — `flutter-architecture`

`flutter-architecture/references/project-setup.md` adımlarını **sırayla, eksiksiz** uygula:
1. `flutter create --org <org> --platforms <platformlar> <ad>`
2. `test/widget_test.dart`'ı sil.
3. Paketler, `analysis_options.yaml`, env dosyaları + `.gitignore`
4. **`lib/core/`, `lib/main.dart`, `lib/app.dart` — script ile, dosyaları elle yazma.** Plugin kökü bu skill dizininin iki üstüdür:
   ```bash
   bash "<bu skill dizini>/../../scripts/setup_core.sh" --source rest|firebase --force-entry
   ```
   `--force-entry` sayaç örneğini (`main.dart`) bootstrap ile değiştirir. Script reference'lardaki kodu kopyalar ve eksik paketleri listeler. Firebase ise ardından `flutterfire configure` ve `main.dart`'a `Firebase.initializeApp` (`flutter-firebase`).
5. `lib/core/widgets/CATALOG.md` (`flutter-ui-components/references/catalog-format.md`)
6. `.claude/settings.json` — üretilmiş dosyaları ve build klasörlerini okuma dışı bırak (project-setup §10d)

Bu adım bitmeden özellik yazmaya başlama.

## 2. Özellikler — `flutter-feature-scaffold`

Her özellik için `new_feature.sh` script'iyle iskelet üret, sonra doldur (adımlar `flutter-feature-scaffold`'da). Barkod/kamera gibi paket gerektiren özelliklerde paketi sor veya en yaygın olanı öner ve `docs/KARARLAR.md`'ye yaz.

## 3. Dokümanlar — `flutter-project-docs`

`README.md`, `docs/MIMARI.md`, `docs/YENI_EKRAN.md`, `docs/KARARLAR.md` ve proje kökünde `CLAUDE.md` (project-setup §11). Gerçek dosya adlarıyla.

## 4. Doğrulama

```bash
dart run build_runner build
dart format .
flutter analyze
flutter test
```

Hata kalırsa düzelt. Çalıştıramadığın komut varsa "çalıştırılmadı" de, geçti deme.

## 5. Teslim

Kullanıcıya kısa özet:
- Klasör ağacı (`lib/` iki seviye)
- Hangi özellikler hazır, hangileri sahte veriyle çalışıyor
- Yapılan varsayımlar
- Çalıştırma komutu: `flutter run --dart-define-from-file=env/dev.json`
- Sonraki adım önerisi (tek cümle)
