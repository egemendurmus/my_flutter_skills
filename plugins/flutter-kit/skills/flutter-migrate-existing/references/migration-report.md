# Analiz raporu ve GECIS.md formatı

## Analiz raporu (Adım 2 — kullanıcıya gösterilir, dosyaya yazılmaz)

```markdown
## <Proje> — flutter-kit uyum analizi

### Mevcut durum
| Konu | Durum |
|---|---|
| Flutter / Dart | 3.24 / 3.5 → hedef 3.27+ / 3.7+ (güncelleme gerekli) |
| State management | setState (32 ekran) + Provider (4 ekran) |
| Veri erişimi | `mssql_connection` ile doğrudan SQL Server ⚠️ |
| Navigasyon | Navigator.push (named routes yok) |
| Klasör yapısı | lib/screens, lib/models, lib/helpers (katman-first) |
| Test | yok |
| En büyük dosyalar | home_screen.dart 1.240 satır, report_screen.dart 860 satır |
| Tekrar eden widget | 4 grup (script çıktısı özeti) |
| Gizli bilgi | lib/helpers/db.dart:12 — connection string koda gömülü ⚠️ |

### Zaten uyumlu
- Modeller ayrı klasörde
- Tema tek dosyada

### Riskler (önem sırasıyla)
1. Doğrudan DB bağlantısı + gömülü şifre — güvenlik
2. 1.000+ satırlık ekranlar — taşıma sırasında davranış kaybı riski; önce test/kontrol listesi
3. Test yok — her taşımada manuel kontrol listesi şart

### Önerilen plan
| Sıra | Adım | Tahmini büyüklük |
|---|---|---|
| 0 | Temel kurulum (core/, ProviderScope, dokümanlar) | Küçük |
| 1 | `settings` özelliği (bağımsız, küçük) | Küçük |
| 2 | `reports` | Orta |
| 3 | `orders` | Orta |
| 4 | `home` (en büyük, en çok bağımlılık) | Büyük |
| 5 | go_router'a geçiş | Orta |
| 6 | very_good_analysis'e geçiş | Küçük |

### Karar gereken konular
- State management hedefi: Riverpod 3 (önerilen)
- Backend API: DB erişimi için API yazılacak mı, ne zaman?
```

## docs/GECIS.md (projede kalıcı dosya)

```markdown
# Yeni yapıya geçiş durumu

Son güncelleme: <YYYY-AA-GG>

Bu proje adım adım flutter-kit yapısına taşınıyor (bkz. [MIMARI.md](MIMARI.md)).

## Tek kural

**`lib/core/` ve `lib/features/` altındaki kod yeni yapıdır. Bunların dışındaki her şey eski yapıdır ve taşınmayı bekler.**

- Yeni kod her zaman yeni yapıyla yazılır.
- Eski bir ekranda **küçük** düzeltme → olduğu yerde yap.
- Eski bir ekranda **büyük** değişiklik → önce o özelliği taşı (bkz. aşağıdaki adımlar), sonra değiştir.

## Durum

| Özellik | Eski konum | Durum | Not |
|---|---|---|---|
| settings | lib/screens/settings_screen.dart | ✅ Yeni | features/settings |
| reports | lib/screens/report_screen.dart | 🔄 Taşınıyor | branch: refactor/reports |
| orders | lib/screens/orders/ | ⏳ Eski | |
| home | lib/screens/home_screen.dart | ⏳ Eski | En son taşınacak |

## Geçici durumlar (bilinmesi gerekenler)

- Navigasyon şimdilik `Navigator.push`; go_router'a geçiş tüm özellikler bitince.
- Veritabanı erişimi `features/<x>/data/services/*_db_service.dart` içinde toplandı; backend API gelince sadece bu dosyalar değişecek.
- Lint: şimdilik `flutter_lints`; geçiş bitince `very_good_analysis`.

## Bir özelliği taşıma adımları

1. Mevcut davranış için test veya manuel kontrol listesi
2. `lib/features/<özellik>/` altında yeni yapı
3. Eski ekranın çağrıldığı yeri yeni ekrana bağla
4. Test + `flutter analyze` + kontrol listesi
5. Eski dosyaları sil
6. Bu tabloyu güncelle
```
