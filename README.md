# my_flutter_skills

Flutter projeleri için Claude Code plugin'i: **flutter-kit**. Yeni projeyi baştan doğru yapıyla kurar, mevcut projeyi bozmadan bu yapıya taşır, kod yazarken kuralları otomatik kontrol eder ve projeye sonradan gelen geliştirici için dokümanları hazırlar.

## Hızlı başlangıç

```
claude
/plugin marketplace add egemendurmus/my_flutter_skills
/plugin install flutter-kit@my-flutter-skills
```

Sonra boş bir klasörde:

```
/flutter-kit:yeni-proje barkod ve stok takip uygulaması
```

Ayrıntılı kurulum: [VS Code'da kurulum](#vs-codeda-kurulum).

## Mimari özeti

- **MVVM**: Flutter'ın resmi mimari önerisi. UI katmanı (View + ViewModel), veri katmanı (Repository + Service)
- **Feature-first** klasörler: `lib/core/` (ortak) + `lib/features/<özellik>/{data,ui}/`
- **Paketler**: Riverpod 3 (codegen), go_router, Dio, freezed 3 + json_serializable, very_good_analysis, mocktail
- **Minimum**: Flutter 3.27+, Dart 3.7+

```
Ekran → ViewModel → Repository → Service → API / Firebase
```

## Komutlar

| Komut | Ne yapar |
|---|---|
| `/flutter-kit:yeni-proje <açıklama>` | Sıfırdan proje kurar, sırayla: soru sorar → yapı ve paketler → ilk özellikler → testler → dokümanlar. `flutter create`'in sayaç örneğini bırakmaz |
| `/flutter-kit:incele` | Son değişiklikleri kurallara göre inceler, önem sırasıyla rapor verir; onay verirsen düzeltir |
| `/flutter-kit:incele lib/features/stock` | Belirli bir klasörü/dosyayı inceler |

Komut yazmak zorunlu değil: normal bir cümle yazdığında da ilgili skill devreye girer. Komut, doğru akışın çalışmasını garanti altına almak için.

## Otomatik korumalar

Plugin kurulduktan sonra bunlar kendiliğinden çalışır, bir şey yazman gerekmez:

- **Her istekte hatırlatma:** Bir Flutter projesindeysen ya da boş bir klasörde "uygulama yap" gibi bir şey istediysen, Claude'a flutter-kit kurallarıyla çalışması söylenir. "Flutter" kelimesini yazmasan bile doğru yapıyla başlar. Proje henüz bu yapıda değilse önce taşıma planıyla başlaması söylenir.
- **Her `.dart` dosyası yazıldığında kontrol:** `dart format` uygulanır. Ardından şunlar kontrol edilir; ihlal varsa Claude'a hemen bildirilir ve Claude düzeltir:
  - ekranda Dio / Firestore / Firebase Auth kullanımı (katman ihlali)
  - `_buildX()` şeklinde widget döndüren metot
  - koda gömülü renk, padding ya da fontSize
  - 300 satırı aşan dosya
  - `core/` klasörünün bir feature'ı import etmesi
  - legacy Riverpod (`StateProvider` vb.), `abstract`/`sealed` olmayan freezed sınıfı
  - **dosyanın yeri ve adı:** feature içinde açıkta duran dosya, `controller`/`notifier`/`page` adları, `core/` altında standart dışı klasör — doğru yolu da söyler

  Sadece yeni yapıdaki dosyalar (`lib/core/`, `lib/features/`) kontrol edilir. Henüz taşınmamış bir projede veya eski yapıdaki bir dosyada küçük bir düzeltme yapılırken refactor dayatılmaz.

## Skill'ler

| Skill | Ne zaman devreye girer |
|---|---|
| `yeni-proje` | Sıfırdan uygulama: diğer skill'leri doğru sırayla çalıştıran kontrol listesi |
| `incele` | Kod inceleme: değiştirmeden rapor verir, onay alınca düzeltir |
| `flutter-architecture` | Her Flutter işinde: klasör yapısı, katman kuralları, paketler, proje kurulum adımları |
| `flutter-clean-code` | Her kod yazımında: boyut sınırları, widget çıkarma, `build` içinde mantık olmaması, sabitler, isimlendirme, git alışkanlıkları |
| `flutter-feature-scaffold` | Yeni ekran/özellik: model → service → repository → ViewModel → ekran → rota → test |
| `flutter-api-data` | REST API: Dio, token yenileme, hata çevirme, sayfalama, dosya yükleme |
| `flutter-firebase` | Firebase Auth / Firestore: withConverter, stream, giriş yönlendirmesi, güvenlik kuralları |
| `flutter-ui-components` | Tasarımdan (görsel/Figma) widget çıkarma, tekrar eden widget'ları bulan script, `CATALOG.md` bileşen kataloğu |
| `flutter-testing` | Testler: mocktail, ProviderContainer.test, widget testleri, Firebase fake'leri |
| `flutter-project-docs` | Yeni gelen geliştirici için `README`, `docs/MIMARI.md`, `docs/YENI_EKRAN.md`, `docs/KARARLAR.md`; bunları güncel tutar |
| `flutter-migrate-existing` | Mevcut projeyi bozmadan taşıma: analiz → plan → özellik özellik taşıma, eski/yeni ayrımı `docs/GECIS.md`'de |

## Kullanım

### Yeni proje

Boş bir klasör aç ve şunu yaz:

> /flutter-kit:yeni-proje barkod ve stok takip uygulaması

Claude önce proje adını, platformları ve backend'i (REST API / Firebase) sorar. Sonra yapıyı, ilk özellikleri, testleri ve dokümanları oluşturur.

### Mevcut proje

> Bu projeyi flutter-kit yapısına geçirmek istiyorum. Önce analiz et ve plan çıkar, hiçbir dosyayı değiştirme.

Claude bir rapor ve taşıma sırası önerir. Sen onay verdikçe önce temel kurulumu yapar, sonra özellikleri tek tek taşır. Uygulama hiçbir aşamada bozulmaz. Geçiş süresince tek bir kural geçerli: **`lib/core` ve `lib/features` dışındaki her şey eski yapıdır.**

### Günlük işler

| Ne yapmak istiyorsun | Örnek istek |
|---|---|
| Yeni ekran | "Sipariş listesi ve detay ekranı ekle, veri /api/orders'dan geliyor" |
| Firebase | "Kullanıcının değerlendirmelerini Firestore'dan canlı listeleyen ekran yap" |
| Tasarımdan kod | Ekran görüntüsünü panele sürükle: "Bu tasarımı koda dök" |
| Tekrar analizi | "Projede tekrar eden widget'ları bul, ortak bileşen öner" |
| Temizlik | "order_detail_screen.dart spagetti olmuş, temizle" |
| İnceleme | `/flutter-kit:incele` |
| Doküman | "Yeni gelen geliştirici için dokümanları oluştur / güncelle" |

İpuçları:
- `@` yazıp bir dosya seçersen Claude o dosyaya odaklanır: `@lib/features/orders/ui/screens/orders_screen.dart bunu temizle`
- Belirli bir skill'i zorlamak için adını yazabilirsin: "flutter-clean-code kurallarına göre düzenle"
- Claude her değişikliği önce fark (diff) olarak gösterir, sen onaylayınca yazar.

### Projeye yeni gelen biri

Projede şu sırayla okunur (yaklaşık 30 dk): `README.md` → `docs/MIMARI.md` → `docs/YENI_EKRAN.md` → `docs/KARARLAR.md`. Bu dosyalar `flutter-project-docs` ile oluşturulur ve her değişiklikte güncellenir.

## Token tasarrufu

Plugin kendi tarafında şunları yapar:
- **Core kurulumu script'le yapılır** (`scripts/setup_core.sh`): `lib/core/`, `main.dart`, `app.dart` (20+ dosya) reference'lardaki koddan tek komutla kopyalanır.
- **Yeni özellik iskeleti script'le üretilir** (`scripts/new_feature.sh`): model, service, repository, ViewModel, ekran, widget ve 2 test dosyası tek komutla oluşur, rota router'a eklenir. Claude sadece alanları ve iş mantığını doldurur.
- **Gereksiz dosyalar okunmaz:** her projeye `.claude/settings.json` eklenir; `build/`, `.dart_tool/`, `ios/Pods/` ve üretilmiş `*.g.dart` / `*.freezed.dart` dosyaları Claude'a kapalıdır.
- **Skill'ler kısa tutulur:** kurallar kısa liste halinde, ayrıntılar sadece gerektiğinde okunan `references/` dosyalarında.

Senin yapabileceklerin:
- Konu değişince `/clear` yaz; biten işin konuşması token yemeye devam eder.
- Dosyayı `@` ile göster (`@lib/features/products/...`); Claude aramak için token harcamaz.
- Rutin işlerde `/model` ile Sonnet'i seç; mimari karar ve taşıma planında Opus.
- Uzun `flutter analyze` / log çıktısının tamamını yapıştırma; sadece hata satırlarını ver ya da Claude'a kendisi çalıştırmasını söyle.
- Tüm testleri değil ilgili klasörü çalıştır: `flutter test test/features/products`.

## VS Code'da kurulum

1. **Claude Code eklentisi (bir kere):** Eklentiler bölümünü aç (Mac: `Cmd+Shift+X`, Windows: `Ctrl+Shift+X`), "Claude Code" diye ara ve yayıncısı **Anthropic** olanı kur. Ardından Claude hesabınla giriş yap. VS Code 1.98+ ve Claude Pro, Max, Team ya da Enterprise hesabı gerekir.
2. **Projeyi aç:** `File → Open Folder`. Bir dosya açınca sağ üstte Claude simgesi (✱) çıkar, tıklayınca sohbet paneli açılır.
3. **Plugin'i kur (bir kere):** `View → Terminal` ile terminali aç ve şunları yaz:
   ```
   claude
   /plugin marketplace add egemendurmus/my_flutter_skills
   /plugin install flutter-kit@my-flutter-skills
   /exit
   ```
   - Kapsam (scope) sorarsa **User** seç, plugin bütün projelerde geçerli olur.
   - Repo private ise önce terminalde `gh auth login` ile GitHub'a giriş yap.
4. **VS Code'u yeniden başlat.** Hook'lar yeni oturumda yüklenir.

Terminalden kullanmak istersen proje klasöründe `claude` yazman yeterli, kullanım aynı.

**Gereksinimler:** macOS, Linux veya Windows'ta Git Bash (hook'lar bash script'i). `python3` varsa daha sağlam çalışır ama zorunlu değil. `dart` PATH'teyse dosyalar otomatik biçimlendirilir.

## Güncelleme

Repoda değişiklik yapıldıktan sonra:

```
claude
/plugin marketplace update my-flutter-skills
```

Sonra VS Code'u yeniden başlat (ya da oturumda `/reload-plugins` yaz).

## Plugin olmadan kullanım

```bash
cp -r plugins/flutter-kit/skills/* ~/.claude/skills/
```

Bu şekilde skill'ler çalışır ama **otomatik korumalar (hook'lar) çalışmaz**. Mümkünse plugin olarak kur.

Claude.ai sohbetinde de skill'ler yüklenebilir (her klasör ayrı zip olarak). Ancak orada hook'lar ve script'ler çalışmaz; asıl kullanım yeri Claude Code.

## Repo yapısı

```
.claude-plugin/marketplace.json     marketplace tanımı (my-flutter-skills)
plugins/flutter-kit/
├── .claude-plugin/plugin.json      plugin tanımı ve sürüm
├── hooks/hooks.json                otomatik korumalar
├── scripts/                        hook script'leri
│   ├── prompt_context.sh           her istekte hatırlatma
│   ├── check_dart_file.sh          .dart dosyası kontrolü (elle: tüm proje taraması)
│   ├── setup_core.sh               lib/core + main/app kurulumu (reference'lardan)
│   └── new_feature.sh              yeni özellik iskeleti (8 dosya + rota; --with-detail, --with-form)
└── skills/<skill>/
    ├── SKILL.md                    kurallar ve adımlar
    ├── references/                 kod şablonları, örnekler
    └── scripts/                    yardımcı script'ler (varsa)
tests/e2e.sh                        uçtan uca test (gerçek Flutter projesinde)
.github/workflows/e2e.yml           e2e: her push + haftalık, Linux ve Windows
```

> `setup_core.sh` kodu `references/` içindeki ```` ```dart ```` bloklarından alır: hedef yol bloğun ilk satırındaki `// lib/core/x.dart` yorumundan veya üstteki `## core/x.dart` başlığından okunur. Reference'taki bir kod bloğunu değiştirirken bu biçimi koru.

## Geliştirme

Bir skill'i değiştirirken:
1. `SKILL.md` kısa kalsın (kurallar ve adımlar). Uzun kod örnekleri `references/` altına gider.
2. `description` satırı skill'in ne zaman devreye gireceğini belirler. Net ve anahtar kelimeli yaz.
3. Sürümü **iki yerde** artır: `.claude-plugin/marketplace.json` ve `plugins/flutter-kit/.claude-plugin/plugin.json`. Sürüm artmazsa kullanıcılar güncellemeyi almaz.
4. Kontrol: `claude plugin validate .` ve `claude plugin validate plugins/flutter-kit`
5. `bash tests/e2e.sh` — skill kodu gerçek projede derleniyor, analizden ve testten geçiyor mu (Flutter gerekir, ~3-5 dk). CI aynısını her push'ta ve haftalık çalıştırır.
6. Commit ve push.

Claude bir şeyi istemediğin şekilde yaptığında, bunu ilgili skill'e kural olarak ekle. Skill'ler bu şekilde olgunlaşır.
