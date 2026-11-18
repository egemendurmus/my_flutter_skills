---
name: flutter-migrate-existing
description: Mevcut, çalışan bir Flutter projesine flutter-kit yapısını bozmadan, adım adım uygular — önce analiz ve rapor (kod değiştirmeden), sonra temel kurulum, sonra ekran ekran taşıma; hangi kısmın eski hangisinin yeni olduğunu docs/GECIS.md'de tutar. "Bu projeyi yeni yapıya geçir", "mevcut projeye uygula", "refactor et", "eski kodu düzenle" isteklerinde ve flutter-kit yapısında olmayan bir projede ilk kez çalışırken kullan.
---

# Mevcut Projeye Uygulama

Amaç: uygulama **hiçbir an bozulmadan** yeni yapıya geçer; geçiş sürerken projeye gelen biri hangi kodun eski hangisinin yeni olduğunu tek bakışta anlar. Rapor ve GECIS.md formatı: `references/migration-report.md`.

## Altın kurallar

1. **İlk adımda kod değiştirme.** Önce analiz, rapor, kullanıcı onayı.
2. **Hepsini birden yeniden yazma.** Bir seferde bir özellik (dikey dilim). Her özellik ayrı branch/commit.
3. **Davranış aynı kalır.** Taşınan ekran kullanıcı açısından birebir aynı çalışmalı; tasarım veya iş kuralı değişikliği ayrı iş.
4. **Dokunma (açık onay olmadan):** backend API sözleşmesi, veritabanı şeması, Firestore koleksiyon/alan adları, `shared_preferences`/secure storage anahtarları, uygulama kimliği (applicationId / bundle id), imzalama, Firebase proje ayarları. Bunları değiştirmek kullanıcıların mevcut verisini bozar.
5. **Canlı sisteme dokunma.** Gerçek veritabanına yazma, canlı API'de silme/güncelleme, cihaz/donanıma komut gönderme — test ortamı ve açık onay olmadan yok.
6. **Kural: yeni kod yeni yerde.** Yeni ve taşınmış kod `lib/core/` ve `lib/features/` altında; eski kod taşınana kadar **olduğu yerde kalır**. Böylece yeni gelen için tek kural yeter: *"`lib/core` ve `lib/features` dışındaki her şey eski yapıdır."*
7. **Her adımın sonunda uygulama derlenir ve çalışır.** Yarım kalmış taşıma commit'lenmez.

## Adım 1 — Analiz (sadece oku)

Şunları çıkar:
- Flutter/Dart sürümü (`pubspec.yaml` `environment`), paketler, state management (setState / Provider / Bloc / GetX / Riverpod / karışık)
- Klasör yapısı ve dosya sayıları; en büyük 10 dosya (satır)
- Veri erişimi: HTTP paketi, Firebase, **doğrudan veritabanı bağlantısı** (ör. `mssql_connection`, `sql_conn`, `mysql1`, `postgres`) var mı
- Navigasyon yöntemi (Navigator 1.0, named routes, go_router, auto_route)
- Testler var mı, `flutter analyze` kaç uyarı veriyor (çalıştırılabiliyorsa)
- `flutter-ui-components/scripts/find_widget_duplicates.py lib/` çıktısı
- Gizli bilgi koda gömülmüş mü (şifre, connection string, API key) — değeri rapora **yazma**, sadece dosya:satır

## Adım 2 — Rapor ve plan (kullanıcı onayı)

`references/migration-report.md` formatında: mevcut durum, uyumlu olanlar, uyumsuzluklar, riskler, önerilen sıra. Kullanıcıyla şunları netleştir:
- **State management:** varsayılan hedef Riverpod 3. İstisna: proje büyük ve tutarlı şekilde Bloc kullanıyorsa Bloc'u koruyup sadece klasör/katman yapısını uygulamayı öner — iki farklı state management'ın uzun süre yan yana olması yeni gelenin kafasını en çok karıştıran şeydir. Karar `docs/KARARLAR.md`'ye yazılır.
- **Taşıma sırası:** önce en az bağımlı, en sık değişen özellik (kazanç hemen görülür); en riskli (ödeme, giriş) en son.

## Adım 3 — Temel kurulum (tek PR)

Mevcut kodu değiştirmeden eklenir:
- Paketler (`flutter-architecture/references/project-setup.md` §2) — mevcut paketlerle sürüm çakışması varsa raporla.
- `ProviderScope` ile `runApp` sarılır (mevcut Provider/Bloc ile yan yana çalışır).
- `lib/core/`: `errors/app_exception.dart`, `network/` (Dio) veya `firebase/` provider'ları, `theme/` (mevcut renklerden türet — görünüm değişmesin), `constants/`, `extensions/`, `widgets/` + `CATALOG.md`.
- **Lint:** mevcut `analysis_options.yaml`'ı koru. `very_good_analysis`'e geçiş, kodun çoğu taşındıktan sonra ayrı bir adım (yoksa binlerce uyarı gerçek sorunları gizler).
- **Navigasyon:** mevcut yöntem korunur; yeni ekranlar mevcut yönteme kaydedilir. go_router'a geçiş, özelliklerin çoğu taşındıktan sonra tek, ayrı bir adım.
- Dokümanlar: `docs/GECIS.md` (yeni), `docs/MIMARI.md` (hedef yapı + "geçiş sürüyor, bkz. GECIS.md" notu), `docs/KARARLAR.md`, `CLAUDE.md` — `flutter-project-docs`.

## Adım 4 — Özellik özellik taşıma

Her özellik için:
1. **Mevcut davranışı yakala:** en az repository seviyesinde (veya kritik ekranın widget testi) test yaz; test yazılamıyorsa manuel kontrol listesi çıkar (hangi ekranda ne görünmeli).
2. Yeni yapıyı `lib/features/<özellik>/` altında kur (`flutter-feature-scaffold`). Mevcut model/servis mantığını **kopyala ve düzenle**, yeniden icat etme.
3. Eski ekranın kullanıldığı yeri yeni ekrana yönlendir.
4. Testler + `flutter analyze` + manuel kontrol listesi.
5. Eski dosyaları **sil** (artık kullanılmayan kod bırakma — yeni gelen hangisinin geçerli olduğunu bilemez).
6. `docs/GECIS.md` tablosunda özelliği "Yeni" yap; `MIMARI.md` özellik tablosunu güncelle.
7. Commit: `refactor(<özellik>): flutter-kit yapısına taşındı`.

## Doğrudan veritabanı bağlantısı bulunursa

Uygulama SQL Server vb. veritabanına doğrudan bağlanıyorsa:
- Raporda **en yüksek risk** olarak belirt (bağlantı bilgisi uygulama paketinden çıkarılabilir, yetki kontrolü yok).
- Hemen kaldırma — backend API hazır değilse uygulama çalışmaz.
- Geçiş süresince tüm veritabanı erişimini tek bir Service sınıfına topla (`features/<x>/data/services/<x>_db_service.dart`). Repository bu Service'i kullanır; API hazır olunca sadece Service değişir, üst katmanlar değişmez.
- Backend API ihtiyacını (endpoint listesi) rapora ekle.

## Geçiş bitince

- go_router'a geçiş (ayrı adım), `very_good_analysis`'e geçiş (ayrı adım).
- `lib/core` ve `lib/features` dışında kod kalmadıysa `docs/GECIS.md`'yi "Tamamlandı" olarak işaretle, `MIMARI.md`'den geçiş notunu kaldır.
