# My Flutter Skills

Reusable Flutter engineering standards for **Claude Code** and **ChatGPT**.

## Available skill

- **Flutter Engineering Standard v1.1**: Create new Flutter applications, evolve existing applications adaptively, implement features, build a design system, generate code and review architecture. Preferred new-project stack: feature-first MVVM, Riverpod 3, Dio, go_router and optional Freezed/json_serializable.

Source: [`.claude/skills/flutter-engineering-standard/SKILL.md`](.claude/skills/flutter-engineering-standard/SKILL.md).

## Claude Code — project installation

Copy the complete `.claude/skills/flutter-engineering-standard/` directory into the **target Flutter repository** at the same relative path. Claude Code can then discover the project's skill. The included `agents/openai.yaml` is ChatGPT metadata; Claude Code doesn't require it.

The optional reviewer is in `.claude/agents/flutter-architecture-reviewer.md`. Copy it to the target repository if you want a dedicated read-only reviewer.

Skills in this centralized library **do not automatically become active in unrelated repositories**. Install or reference them for each target project.

## ChatGPT

Use the `flutter-engineering-standard/` folder (from inside `.claude/skills/`) when building a single-skill ZIP for your ChatGPT Skills library. The skill entrypoint is `SKILL.md` and includes `agents/openai.yaml`.

## Standards

- **CREATE:** feature-first structure, Riverpod 3, typed navigation, a proportional UI kit, reproducible code generation and tests.
- **EVOLVE:** inspect first, preserve behavior, migrate incrementally, never force a state-management rewrite.
- **REVIEW:** report evidence with file/line, severity and PASS/FAIL/NOT RUN status; never invent a passing test result.
- **REMOTE CHANGES:** read-only by default; request explicit authorization before write operations.

## Verification

Run the non-destructive structural helper from the target Flutter repository:

```bash
python .claude/skills/flutter-engineering-standard/scripts/validate_structure.py .
```

This heuristic check does not replace `flutter analyze` and `flutter test`.

### Acknowledgment

## flutter-kit (Claude Code plugin)

`plugins/flutter-kit/` altında, Claude Code plugin marketplace'i olarak kurulabilen 7 skill. Yukarıdaki `flutter-engineering-standard` süreç kurallarını (CREATE/EVOLVE/REVIEW) tanımlar; `flutter-kit` aynı stack için somut kod şablonları ve adım adım iş akışları verir.

### İçerik

| Skill | Ne zaman devreye girer |
|---|---|
| `flutter-architecture` | Flutter kodu yazarken, proje kurarken, kod incelerken; klasör yapısı, katman kuralları, paket seçimi |
| `flutter-clean-code` | Her kod yazımında ve refactor'da: dosya/widget/fonksiyon boyut sınırları, widget çıkarma, `build` içinde mantık yok, sabitler, isimlendirme, git alışkanlıkları |
| `flutter-ui-components` | Tasarımdan (görsel/Figma) widget ağacı ve token çıkarma; mevcut kodda tekrar eden widget'ları script ile bulma; `core/widgets/CATALOG.md` bileşen kataloğu |
| `flutter-feature-scaffold` | "Yeni ekran / feature ekle" isteklerinde; model → service → repository → ViewModel → ekran → rota → test |
| `flutter-api-data` | REST API'ye bağlanırken; Dio, token interceptor, hata çevirme, sayfalama, upload |
| `flutter-firebase` | Firebase Auth / Firestore kullanırken; withConverter, stream, redirect, güvenlik kuralları |
| `flutter-testing` | Test yazarken; mocktail, ProviderContainer.test, widget testleri, Firebase fake'leri |

### Mimari özeti

- **Flutter'ın resmi önerisi olan MVVM**: UI katmanı (View + ViewModel) ve veri katmanı (Repository + Service)
- **Feature-first** klasör yapısı: `lib/features/<feature>/{data,ui}`
- **Riverpod 3** (codegen) ile state yönetimi ve bağımlılık enjeksiyonu
- `go_router`, `dio`, `freezed` 3, `json_serializable`, `very_good_analysis`, `mocktail`

```
Screen → ViewModel → Repository → Service → Dio / Firestore
```

### Kurulum

#### Claude Code (önerilen)

```
/plugin marketplace add egemendurmus/my_flutter_skills
/plugin install flutter-kit@serdar-flutter-skills
```

Güncelleme: repoya push ettikten sonra `/plugin marketplace update serdar-flutter-skills`.

#### Elle (plugin olmadan)

```bash
cp -r plugins/flutter-kit/skills/* ~/.claude/skills/
```

Tek bir projeye özel kullanmak için o projenin `.claude/skills/` klasörüne kopyala.

#### Claude.ai sohbet

Her skill klasörünü (`plugins/flutter-kit/skills/<skill>`) ayrı ayrı zip'leyip claude.ai'deki skill ayarlarından yükle, ya da Claude'a "bu skill'i ekle" de.

### Geliştirme

Bir skill'i değiştirirken:
1. `SKILL.md` kısa kalsın (kurallar + adımlar). Uzun kod örnekleri `references/` altına.
2. `description` satırı skill'in ne zaman tetikleneceğini belirler; net ve anahtar kelimeli yaz.
3. Değişiklikten sonra gerçek bir projede dene, `plugin.json`'daki `version`'ı artır, commit + push.
