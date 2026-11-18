# my_flutter_skills

Flutter projelerim için Claude skill'leri. Repo bir **Claude Code plugin marketplace**'i olarak düzenlenmiştir. İçinde tek bir plugin var: `flutter-kit`.

## İçerik

| Skill | Ne zaman devreye girer |
|---|---|
| `flutter-architecture` | Flutter kodu yazarken, proje kurarken, kod incelerken; klasör yapısı, katman kuralları, paket seçimi |
| `flutter-clean-code` | Her kod yazımında ve refactor'da: dosya/widget/fonksiyon boyut sınırları, widget çıkarma, `build` içinde mantık yok, sabitler, isimlendirme, git alışkanlıkları |
| `flutter-ui-components` | Tasarımdan (görsel/Figma) widget ağacı ve token çıkarma; mevcut kodda tekrar eden widget'ları script ile bulma; `core/widgets/CATALOG.md` bileşen kataloğu |
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

### Claude Code (önerilen)

```
/plugin marketplace add egemendurmus/my_flutter_skills
/plugin install flutter-kit@serdar-flutter-skills
```

Güncelleme: repoya push ettikten sonra `/plugin marketplace update serdar-flutter-skills`.

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
