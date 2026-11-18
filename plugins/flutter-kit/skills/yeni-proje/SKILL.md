---
name: yeni-proje
description: Sıfırdan yeni bir Flutter uygulaması oluşturur — flutter-kit klasör yapısı, paketler, core katmanı, ilk özellik, testler ve yeni gelen geliştirici dokümanları ile. "Uygulama yap", "yeni proje oluştur", "X takip uygulaması yap", "mobil app kur" isteklerinde (kullanıcı Flutter demese de, başka teknoloji istemediyse) ve /flutter-kit:yeni-proje komutuyla kullan.
argument-hint: "[uygulama açıklaması]"
---

# Yeni Flutter Projesi

Bu skill bir **sıralı kontrol listesidir**; diğer skill'leri doğru sırada çalıştırır. Adım atlama. Kullanıcının isteği: $ARGUMENTS

## 0. Netleştir (eksikse tek mesajda sor)

- Proje adı (`snake_case`) ve org (varsayılan `com.eliar`)
- Platformlar (varsayılan: android, ios)
- Backend: REST API mi (adres?), Firebase mi, henüz yok mu (yoksa sahte/mock repository ile başla)
- İlk özellikler (ör. barkod okuma, ürün listesi, stok hareketi) — en fazla 2-3 ile başla
- Özel ihtiyaç var mı: kamera/barkod, çevrimdışı çalışma, çok dil

Kullanıcı "sen karar ver" derse varsayılanları kullan ve sonunda listele.

## 1. Proje iskeleti — `flutter-architecture`

`flutter-architecture/references/project-setup.md` adımlarını **sırayla, eksiksiz** uygula:
1. `flutter create --org <org> --platforms <platformlar> <ad>`
2. **Varsayılan sayaç örneğini sil:** `lib/main.dart` içeriğini project-setup §5'teki bootstrap ile değiştir, `test/widget_test.dart`'ı sil.
3. Paketler, `analysis_options.yaml`, env dosyaları + `.gitignore`
4. `lib/core/`: config, constants, errors (`app-exception.md`), extensions, network veya firebase, router, theme, widgets + `CATALOG.md` (`flutter-ui-components/references/core-widgets.md`)
5. `lib/main.dart`, `lib/app.dart`

Bu adım bitmeden özellik yazmaya başlama.

## 2. Özellikler — `flutter-feature-scaffold`

Her özellik için ayrı ayrı: model → service → repository → ViewModel → ekran → rota → test. Barkod/kamera gibi paket gerektiren özelliklerde paketi sor veya en yaygın olanı öner ve `docs/KARARLAR.md`'ye yaz.

## 3. Dokümanlar — `flutter-project-docs`

`README.md`, `docs/MIMARI.md`, `docs/YENI_EKRAN.md`, `docs/KARARLAR.md` ve proje kökünde `CLAUDE.md` (project-setup §11). Gerçek dosya adlarıyla.

## 4. Doğrulama

```bash
dart run build_runner build -d
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
