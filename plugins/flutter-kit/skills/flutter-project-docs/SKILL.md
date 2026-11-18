---
name: flutter-project-docs
description: "Projeye yeni gelen geliştirici için README, docs/MIMARI.md, YENI_EKRAN.md, KARARLAR.md oluşturur ve güncel tutar. Proje kurulurken, yapı değişince ve doküman isteklerinde kullan."
---

# Proje Dokümantasyonu (insanlar için)

Diğer skill'ler Claude'a nasıl kod yazacağını söyler. Bu skill, projeye **sonradan gelen bir geliştiricinin** ilk gün okuyup "nerede ne var, yeni ekranı nasıl eklerim, neden böyle yapılmış" sorularının cevabını bulacağı dokümanları üretir.

## Hedef: ilk gün 30 dakika

Yeni gelen biri sadece bu dosyaları okuyarak 30 dakikada şunları yapabilmeli:
1. Projeyi çalıştırmak (README)
2. Bir isteğin ekrandan API'ye nasıl gittiğini gerçek dosya adlarıyla takip etmek (MIMARI)
3. Kimseye sormadan yeni bir ekran eklemek (YENI_EKRAN)
4. "Neden X kullanılmış?" sorusunun cevabını bulmak (KARARLAR)

## Dosyalar

| Dosya | Ne anlatır | Şablon |
|---|---|---|
| `README.md` (proje kökü) | Proje nedir, nasıl çalıştırılır, komutlar, dokümanlara linkler | `references/templates.md` §1 |
| `docs/MIMARI.md` | Katmanlar, gerçek bir örnekle veri akışı, klasör haritası, "nereye ne konur" tablosu, feature listesi | §2 |
| `docs/YENI_EKRAN.md` | Yeni ekran/feature ekleme rehberi, adım adım, projeden gerçek örnekle | §3 |
| `docs/KARARLAR.md` | Mimari kararlar: ne, neden, alternatifler | §4 |
| `lib/core/widgets/CATALOG.md` | Ortak bileşenler (`flutter-ui-components`) | — |
| `docs/GECIS.md` | Sadece mevcut proje taşınıyorsa: hangi kısım eski, hangisi yeni (`flutter-migrate-existing`) | — |
| `CLAUDE.md` | Claude için kısa kurallar; insanlar için olan dokümanlara link verir | `flutter-architecture/references/project-setup.md` §11 |

## Yazım kuralları

1. **Türkçe, sade, kısa.** Her dosya ≤ 150 satır. Paragraf yerine tablo ve madde.
2. **Genel laf yok, projenin kendisi.** "Repository veri katmanıdır" yazma; "`OrdersRepository` (`lib/features/orders/data/repositories/orders_repository.dart`) siparişleri API'den çeker ve hataları `AppException`'a çevirir" yaz. Örnekler projedeki **gerçek** dosya ve sınıf adlarıyla.
3. **Dosyada yazan her şey doğru olmalı.** Yazmadan önce yolu ve sınıfı kontrol et (dosya var mı, isim aynı mı). Yanlış doküman, dokümansızlıktan kötüdür.
4. **Komutlar kopyala-yapıştır çalışmalı.** Env dosyası, codegen, test komutları tam haliyle.
5. **Kod tekrarlama.** Skill'lerdeki uzun kuralları dokümana kopyalama; kısa özet + "detay için şu dosyaya bak".
6. Her dosyanın en üstünde `Son güncelleme: YYYY-AA-GG`.

## Ne zaman güncellenir (zorunlu)

Bu tetikleyiciler olduğunda ilgili dokümanı **aynı iş içinde** güncelle; ayrı bir göreve bırakma:

| Olay | Güncellenecek |
|---|---|
| Yeni feature eklendi | `MIMARI.md` feature listesi |
| Yeni paket eklendi / paket değişti | `KARARLAR.md` yeni kayıt + `README.md` gerekiyorsa |
| Klasör yapısı, katman kuralı değişti | `MIMARI.md`, `YENI_EKRAN.md`, `CLAUDE.md` |
| Çalıştırma/env/komut değişti | `README.md` |
| Ortak widget eklendi | `CATALOG.md` |
| Eski kısım yeni yapıya taşındı | `GECIS.md` |

İşi bitirirken kullanıcıya hangi dokümanı güncellediğini bir satırla söyle.

## Doküman denetimi ("dokümanlar güncel mi?")

1. `MIMARI.md`'deki feature listesini `lib/features/` klasörleriyle karşılaştır.
2. Dokümanlarda geçen her dosya yolunun var olduğunu kontrol et.
3. `README.md`'deki komutları `pubspec.yaml` ve `env/` ile karşılaştır.
4. `KARARLAR.md`'de olmayan ama `pubspec.yaml`'da olan ana paketleri listele.
5. Farkları raporla, onay alınca düzelt.
