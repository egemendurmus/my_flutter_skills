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
bash "<bu skill dizini>/../../scripts/new_feature.sh" <feature> [--model <tekil_ad>] [--source rest|firebase] [--with-detail] [--with-form]
```

Kullanıcı detay veya form istediyse bayrağı ver; sonradan elle yazma.

| Bayrak | Ek dosyalar |
|---|---|
| (yok) — 8 dosya | model, service, repository, liste ViewModel'i, liste ekranı, tile, repository + ViewModel testleri |
| `--with-detail` +4 | detay ViewModel'i (family), detay ekranı, detay widget'ı, test; listeden tıklayınca açılır |
| `--with-form` +4 | form state + ViewModel (oluştur/düzenle), form ekranı, form widget'ı, test; service/repository'ye `create`/`update`, listede "+" butonu, detayda düzenle butonu |

Var olan dosyaya dokunmaz. Script eksik `core/` dosyası bildirirse önce `scripts/setup_core.sh` çalıştır.

Rota: router'da `// flutter-kit:` işaretleri varsa script liste rotasını ve detay/form alt rotalarını kendisi ekler (çıktıdaki "Rota:" satırı). İşaret yoksa (ör. taşınan proje) rotaları elle ekle (`project-setup.md` §6); script bu durumda ekranlara navigasyon satırı koymaz, rotayı ekleyince bağla.

## 3. Doldur

- Model alanları (`TODO(flutter-kit)` satırları), endpoint yolu / koleksiyon adı
- Tile'da, detay widget'ında ve formda gösterilecek alanlar (form state'ine alan + setter ekle)
- Test verisindeki örnek nesneyi yeni alanlara göre güncelle
- Silme gibi script'in üretmediği parçalar: deseni `references/feature-template.md`'den al (sadece gerektiğinde oku)

## 4. Kontrol

```bash
dart run build_runner build && dart fix --apply && dart format .
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
