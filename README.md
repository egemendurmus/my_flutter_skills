# my_flutter_skills

Flutter projelerim için Claude skill'leri. Repo bir **Claude Code plugin marketplace**'i olarak düzenlenmiştir. İçinde tek bir plugin var: `flutter-kit`.

## İçerik

| Skill | Ne zaman devreye girer |
|---|---|
| `flutter-architecture` | Flutter kodu yazarken, proje kurarken, kod incelerken; klasör yapısı, katman kuralları, paket seçimi |
| `flutter-clean-code` | Her kod yazımında ve refactor'da: dosya/widget/fonksiyon boyut sınırları, widget çıkarma, `build` içinde mantık yok, sabitler, isimlendirme, git alışkanlıkları |
| `flutter-ui-components` | Tasarımdan (görsel/Figma) widget ağacı ve token çıkarma; mevcut kodda tekrar eden widget'ları script ile bulma; `core/widgets/CATALOG.md` bileşen kataloğu |
| `flutter-project-docs` | Projeye sonradan gelen geliştirici için `README`, `docs/MIMARI.md`, `docs/YENI_EKRAN.md`, `docs/KARARLAR.md` üretir ve güncel tutar |
| `flutter-migrate-existing` | Çalışan projeyi bozmadan yeni yapıya geçirir: önce analiz/rapor, sonra özellik özellik taşıma; `docs/GECIS.md` ile eski/yeni ayrımı |
| `flutter-feature-scaffold` | "Yeni ekran / feature ekle" isteklerinde; model → service → repository → ViewModel → ekran → rota → test |
| `flutter-api-data` | REST API'ye bağlanırken; Dio, token interceptor, hata çevirme, sayfalama, upload |
| `flutter-firebase` | Firebase Auth / Firestore kullanırken; withConverter, stream, redirect, güvenlik kuralları |
| `flutter-testing` | Test yazarken; mocktail, ProviderContainer.test, widget testleri, Firebase fake'leri |

## Mimari özeti

- **Flutter'ın resmi önerisi olan MVVM**: UI katmanı (View + ViewModel) ve veri katmanı (Repository + Service)
- **Feature-first** klasör yapısı: `lib/features/<feature>/{data,ui}`
- **Riverpod 3** (codegen) ile state yönetimi ve bağımlılık enjeksiyonu
- `go_router`, `dio`, `freezed` 3, `json_serializable`, `very_good_analysis`, `mocktail`

```
Screen → ViewModel → Repository → Service → Dio / Firestore
```

## Kurulum

### VS Code'da adım adım (önerilen)

**1. Claude Code eklentisini kur (bir kere)**
`Ctrl+Shift+X` → "Claude Code" ara → yayıncısı **Anthropic** olanı kur → Claude hesabınla giriş yap. VS Code 1.98+ ve Claude Pro/Max/Team/Enterprise hesabı gerekir.

**2. Flutter projesini aç**
`File → Open Folder` ile proje klasörünü aç. Bir dosya açınca sağ üstte Claude simgesi (✱) çıkar; tıklayınca sohbet paneli açılır.

**3. Plugin'i kur (bir kere)**
VS Code terminalini aç (`Ctrl+ö` veya `View → Terminal`) ve:

```
claude
/plugin marketplace add egemendurmus/my_flutter_skills
/plugin install flutter-kit@my-flutter-skills
/exit
```

- Kapsam (scope) sorarsa **User** seç: plugin bütün projelerde geçerli olur.
- Repo private ise önce terminalde `gh auth login` ile GitHub'a giriş yap.
- Plugin hem terminalde hem VS Code panelinde çalışır; emin olmak için VS Code'u bir kez yeniden başlat.

**4. Kullan**
Sağdaki Claude paneline normal yaz; ilgili skill kendiliğinden devreye girer. İlk denemeler:

> Bu projeyi flutter-kit kurallarına göre analiz et. Neler uyumsuz, raporla ama hiçbir dosyayı değiştirme.

> Ayarlar ekranı ekle: tema seçimi (açık/koyu) ve çıkış butonu olsun.

| Ne yapmak istiyorsun | Örnek istek |
|---|---|
| Yeni proje | "stok_takip adında yeni bir Flutter projesi kur, Android ve iOS" |
| Yeni ekran | "Sipariş listesi ve detay ekranı ekle, veri /api/orders'dan geliyor" |
| Firebase | "Kullanıcının değerlendirmelerini Firestore'dan canlı listeleyen ekran yap" |
| Tasarımdan kod | Ekran görüntüsünü panele sürükle: "Bu tasarımı koda dök" |
| Tekrar analizi | "Projede tekrar eden widget'ları bul, ortak bileşen öner" |
| Temizlik | "order_detail_screen.dart spagetti olmuş, temizle" |
| İnceleme | "Son değişiklikleri mimari kurallara göre incele" |

İpuçları:
- `@` yazıp dosya seçersen Claude o dosyaya odaklanır: `@lib/features/orders/ui/screens/orders_screen.dart bunu temizle`
- Belirli bir skill'i zorlamak için adını yaz: "flutter-clean-code kurallarına göre düzenle"
- Claude her değişikliği önce fark (diff) olarak gösterir; sen onaylayınca yazar.

**Mevcut projelerde:** şunu yaz:

> Bu projeyi flutter-kit yapısına geçirmek istiyorum. Önce analiz et ve plan çıkar, hiçbir dosyayı değiştirme.

Claude rapor ve sıra önerir; onay verdikçe önce temel kurulumu, sonra özellikleri tek tek taşır. Geçiş boyunca `docs/GECIS.md` hangi kısmın eski hangisinin yeni olduğunu gösterir. Kural basit: `lib/core` ve `lib/features` dışındaki her şey eski yapıdır.

**Projeye yeni gelen biri için:** projede `README.md` → `docs/MIMARI.md` → `docs/YENI_EKRAN.md` sırasıyla okunur (~30 dk). Bu dokümanlar `flutter-project-docs` skill'iyle oluşturulur ve her değişiklikte güncellenir. Eksikse: "Bu proje için yeni gelen geliştiriciye yönelik dokümanları oluştur".

**Güncelleme:** skill'ler değişince terminalde `claude` → `/plugin marketplace update my-flutter-skills`.

### Komutlar

| Komut | Ne yapar |
|---|---|
| `/flutter-kit:yeni-proje barkod ve stok takip uygulaması` | Sıfırdan proje: yapı, paketler, ilk özellikler, testler, dokümanlar — sırayla |
| `/flutter-kit:incele` | Son değişiklikleri kurallara göre inceler, rapor verir, onay alınca düzeltir |
| `/flutter-kit:incele lib/features/stock` | Belirli bir klasörü inceler |

Komut yazmak zorunlu değil; normal cümleyle istediğinde de ilgili skill devreye girer. Komut, işi garanti altına almak için.

### Otomatik korumalar (hook'lar)

Plugin kurulunca iki şey kendiliğinden çalışır:
- **Her istekte hatırlatma:** Flutter projesindeysen veya boş klasörde "uygulama yap" gibi bir şey istediysen, Claude'a flutter-kit kurallarını kullanması söylenir. Böylece "Flutter" kelimesini yazmasan da doğru yapıyla başlar.
- **Her `.dart` dosyası yazıldığında kontrol:** `dart format` uygulanır; ekranda Dio/Firestore çağrısı, `_buildX()` metodu, gömülü renk/padding/fontSize, 300 satırı aşan dosya, legacy Riverpod, `abstract`siz freezed sınıfı varsa Claude'a anında bildirilir ve düzeltir. Taşınma sürüyorsa (`docs/GECIS.md`) eski yapıdaki dosyalara dokunulmaz.

### Terminal (Claude Code CLI)

Proje klasöründe `claude` çalıştırıp yukarıdaki `/plugin` komutlarını yaz; kullanım aynı.

### Elle (plugin olmadan)

```bash
cp -r plugins/flutter-kit/skills/* ~/.claude/skills/
```

Tek bir projeye özel kullanmak için o projenin `.claude/skills/` klasörüne kopyala.

### Claude.ai sohbet

Her skill klasörünü (`plugins/flutter-kit/skills/<skill>`) ayrı ayrı zip'leyip claude.ai'deki skill ayarlarından yükle, ya da Claude'a "bu skill'i ekle" de.

## Geliştirme

Bir skill'i değiştirirken:
1. `SKILL.md` kısa kalsın (kurallar + adımlar). Uzun kod örnekleri `references/` altına.
2. `description` satırı skill'in ne zaman tetikleneceğini belirler; net ve anahtar kelimeli yaz.
3. Değişiklikten sonra gerçek bir projede dene, `plugin.json`'daki `version`'ı artır, commit + push.
