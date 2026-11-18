---
name: flutter-feature-scaffold
description: "Flutter projesine yeni özellik/ekran ekler. İskeleti script ile üretir (model, service, repository, ViewModel, ekran, widget, testler), sonra alanları ve iş mantığını doldurur. \"Yeni ekran ekle\", \"X özelliğini oluştur\", \"liste sayfası yap\" isteklerinde kullan."
---

# Yeni Özellik

`flutter-architecture` kuralları geçerli.

## 1. Netleştir (eksikse kısaca sor)

Özellik adı (`snake_case`, çoğul: `products`), veri kaynağı (REST / Firebase), ekranlar (liste, detay, form), model alanları (örnek JSON varsa iste). Ayrıntı yoksa makul varsay, sonunda listele.

## 2. İskeleti script ile üret — dosyaları elle yazma

Plugin kökü bu skill dizininin iki üstüdür:

```bash
bash "<bu skill dizini>/../../scripts/new_feature.sh" <feature> [--model <tekil_ad>] [--source rest|firebase]
```

8 dosya oluşur: model, service, repository, liste ViewModel'i, liste ekranı, tile widget'ı, repository ve ViewModel testleri. Var olan dosyaya dokunmaz. Script eksik `core/` dosyası bildirirse önce onları kur (`flutter-architecture/references/project-setup.md`).

## 3. Doldur

- Model alanları (`TODO(flutter-kit)` satırları), endpoint yolu / koleksiyon adı
- Tile'da gösterilecek alanlar
- Test verisindeki örnek nesneyi yeni alanlara göre güncelle
- Detay ekranı, form, silme gibi script'in üretmediği parçalar: deseni `references/feature-template.md`'den al (sadece gerektiğinde oku)
- Rota: `core/router/routes.dart` + `app_router.dart`

## 4. Kontrol

```bash
dart run build_runner build -d && dart fix --apply && dart format .
flutter analyze
flutter test test/features/<feature>
```

Hata kalırsa düzelt. Çalıştıramadığın komutu "çalıştırılmadı" diye bildir.

## 5. Doküman ve rapor

`docs/MIMARI.md` özellik tablosuna satır; yeni paket varsa `docs/KARARLAR.md`. Kullanıcıya: oluşan dosyalar, varsayımlar, onun yapması gerekenler (endpoint, Firestore kuralı).

## Yapma

- Ekrandan repository çağırmak → ViewModel üzerinden.
- ViewModel'de `context.go` → ViewModel sonuç döner, navigasyonu ekran yapar.
- Liste + detay için tek ViewModel → her ekrana bir ViewModel; detay için family (`productDetailViewModelProvider(id)`).
