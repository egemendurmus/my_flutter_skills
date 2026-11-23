#!/usr/bin/env bash
# PostToolUse hook: Claude bir .dart dosyasını yazdığında/düzenlediğinde çalışır.
# dart format uygular, flutter-kit kurallarını kontrol eder. İhlal varsa stderr'e yazıp
# exit 2 döner; Claude Code bu mesajı Claude'a geri verir ve Claude düzeltir.

# Kullanım:
#   hook olarak: stdin'den JSON (tool_input.file_path) okur, dosyayı biçimlendirir ve kontrol eder
#   elle:       check_dart_file.sh <dosya.dart> [proje_kökü]  → sadece kontrol eder, dosyayı değiştirmez
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
review_mode=false
if [ -n "$1" ]; then
  review_mode=true
  file="$1"
  [ -n "$2" ] && project_dir="$2"
  case "$file" in /*) ;; *) file="$project_dir/$file" ;; esac
else
input="$(cat)"
# Windows'ta python3 çoğu zaman Microsoft Store kısayoludur: gerçekten çalışanı seç.
py=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && [ "$("$c" -c 'print(1)' 2>/dev/null)" = "1" ]; then py="$c"; break; fi
done
if [ -n "$py" ]; then
  file="$(printf '%s' "$input" | "$py" -c "import json,sys
try: print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception: pass" 2>/dev/null)"
else
  # JSON'da \\ olarak kaçışlanmış ters eğik çizgiyi teke indir
  file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 | sed 's/\\\\/\\/g')"
fi
fi

# Windows yollarını normalize et: C:\a\b → /c/a/b (Git Bash biçimi), sondaki \r'yi at
to_unix() {
  p="$(printf '%s' "$1" | tr -d '\r' | sed 's|\\|/|g')"
  case "$p" in
    [A-Za-z]:/*) p="/$(printf '%s' "${p:0:1}" | tr '[:upper:]' '[:lower:]')${p:2}" ;;
  esac
  printf '%s' "$p"
}
file="$(to_unix "$file")"
project_dir="$(to_unix "$project_dir")"

# Sadece lib/ altındaki elle yazılmış .dart dosyaları
case "$file" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.mocks.dart) exit 0 ;;
  */lib/*.dart) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# Kurallar sadece yeni yapıdaki dosyalara uygulanır. lib/core ve lib/features dışı
# eski yapıdır (taşınmamış proje veya geçiş süren proje): orada küçük düzeltme
# yapılırken refactor dayatılmaz.
rel="${file#"$project_dir"/}"
case "$rel" in
  lib/core/*|lib/features/*) ;;
  lib/main.dart|lib/app.dart) [ -d "$project_dir/lib/core" ] || exit 0 ;;
  *) exit 0 ;;
esac

$review_mode || { command -v dart >/dev/null 2>&1 && dart format "$file" >/dev/null 2>&1; }

problems=()
add() { problems+=("$1"); }

lines=$(wc -l < "$file" | tr -d ' ')
[ "$lines" -gt 300 ] && add "Dosya $lines satır (sınır 300): widget'ları/yardımcıları ayrı dosyalara böl."

# --- Dosya yeri ve adı ---
name="$(basename "$file")"
base="${name%.dart}"
stem="$(printf '%s' "$base" | sed -E 's/_(controller|notifier|view_model|viewmodel|vm|provider|screen|page|view|service|api|datasource|data_source|repository|repo)$//')"

suggest_place() {
  # $1: feature adı
  case "$name" in
    *_controller.dart|*_notifier.dart|*_view_model.dart|*_viewmodel.dart|*_vm.dart|*_provider.dart)
      echo "lib/features/$1/ui/view_models/${stem}_view_model.dart" ;;
    *_screen.dart|*_page.dart|*_view.dart) echo "lib/features/$1/ui/screens/${stem}_screen.dart" ;;
    *_service.dart|*_api.dart|*_datasource.dart|*_data_source.dart) echo "lib/features/$1/data/services/${stem}_service.dart" ;;
    *_repository.dart|*_repo.dart) echo "lib/features/$1/data/repositories/${stem}_repository.dart" ;;
    *) echo "model ise lib/features/$1/data/models/$name, widget ise lib/features/$1/ui/widgets/$name" ;;
  esac
}

case "$rel" in
  lib/features/*)
    after="${rel#lib/features/}"
    feature="${after%%/*}"
    rest="${after#*/}"
    [ "$rest" = "$after" ] && rest=""
    case "$rest" in
      data/models/*|ui/widgets/*|domain/use_cases/*) ;;
      data/services/*)
        case "$name" in *_service.dart) ;; *) add "Service dosyası '_service.dart' ile bitmeli: $(suggest_place "$feature")" ;; esac ;;
      data/repositories/*)
        case "$name" in *_repository.dart) ;; *) add "Repository dosyası '_repository.dart' ile bitmeli: $(suggest_place "$feature")" ;; esac ;;
      ui/view_models/*)
        case "$name" in *_view_model.dart|*_state.dart) ;; *) add "ViewModel dosyası '_view_model.dart' ile bitmeli (controller/notifier adı kullanılmaz): lib/features/$feature/ui/view_models/${stem}_view_model.dart" ;; esac ;;
      ui/screens/*)
        case "$name" in *_screen.dart) ;; *) add "Ekran dosyası '_screen.dart' ile bitmeli: lib/features/$feature/ui/screens/${stem}_screen.dart" ;; esac ;;
      *)
        add "Dosya yanlış yerde ($rel). Bir feature içinde sadece şu klasörler olur: data/models, data/services, data/repositories, ui/view_models, ui/screens, ui/widgets (gerekirse domain/use_cases). Doğru yer: $(suggest_place "$feature")" ;;
    esac
    while IFS= read -r m; do
      add "Satır ${m%%:*}: sınıf adı Controller/Notifier ile bitiyor — <Ad>ViewModel olarak değiştir (provider adı da <ad>ViewModelProvider olur)."
    done < <(grep -nE "^[[:space:]]*class[[:space:]]+[A-Z][A-Za-z0-9]*(Controller|Notifier)[[:space:]]+extends" "$file")
    ;;
  lib/core/*)
    after="${rel#lib/core/}"
    folder="${after%%/*}"
    if [ "$folder" = "$after" ]; then
      add "core/ altında klasörsüz dosya ($rel): config, constants, errors, extensions, firebase, models, network, router, theme, utils veya widgets klasörüne koy."
    else
      case "$folder" in
        config|constants|errors|extensions|firebase|models|network|router|theme|utils|widgets) ;;
        *) add "core/$folder/ standart bir klasör değil. Kullanılacaklar: config, constants, errors, extensions, firebase, models, network, router, theme, utils, widgets." ;;
      esac
    fi
    ;;
esac

while IFS= read -r m; do
  add "Satır ${m%%:*}: widget döndüren metot (${m#*:}) — ayrı StatelessWidget sınıfına çevir."
done < <(grep -nE "^[[:space:]]*Widget[[:space:]]+_build[A-Za-z0-9_]*[[:space:]]*\(" "$file" | sed -E 's/^([0-9]+):[[:space:]]*Widget[[:space:]]+(_build[A-Za-z0-9_]*).*/\1:\2()/')

case "$rel" in
  */ui/*|*/screens/*|*/widgets/*)
    while IFS= read -r m; do
      add "Satır ${m%%:*}: UI katmanında veri erişimi ($(echo "${m#*:}" | sed -E "s/.*package:([a-z_]+).*/\1/;s/^ +//")) — ViewModel → Repository → Service üzerinden git."
    done < <(grep -nE "import 'package:(dio|http|cloud_firestore|firebase_auth|firebase_storage|sqflite|drift|mssql_connection)/" "$file")
    while IFS= read -r m; do
      add "Satır ${m%%:*}: UI içinde Dio()/FirebaseFirestore.instance — Service katmanına taşı."
    done < <(grep -nE "(^|[^A-Za-z_])Dio\(|FirebaseFirestore\.instance|FirebaseAuth\.instance" "$file" | grep -vE "^[0-9]+:[[:space:]]*//")
    ;;
esac

case "$rel" in
  lib/core/*)
    while IFS= read -r m; do
      add "Satır ${m%%:*}: core/ bir feature'ı import ediyor — core feature'lara bağımlı olamaz."
    done < <(grep -nE "import '(package:[a-z_]+/)?features/" "$file")
    ;;
esac

case "$rel" in
  */theme/*|*/constants/*) ;;
  *)
    c=$(grep -cE "Color\(0x[0-9A-Fa-f]+\)|Colors\.(red|green|blue|black|white|grey|orange|yellow|purple|pink|teal|amber|cyan|indigo|brown|lime)" "$file")
    [ "$c" -gt 0 ] && add "$c yerde gömülü renk — Theme.of(context).colorScheme / context.colors kullan."
    p=$(grep -cE "EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]" "$file")
    [ "$p" -gt 0 ] && add "$p yerde sayı ile padding (EdgeInsets) — AppSpacing sabitlerini kullan."
    f=$(grep -cE "fontSize:[[:space:]]*[0-9]" "$file")
    [ "$f" -gt 0 ] && add "$f yerde sabit fontSize — context.textTheme stillerini kullan."
    ;;
esac

while IFS= read -r m; do
  add "Satır ${m%%:*}: Riverpod legacy API — @riverpod Notifier/AsyncNotifier kullan."
done < <(grep -nE "(^|[^A-Za-z_])(StateNotifierProvider|StateProvider|ChangeNotifierProvider)([^A-Za-z_]|$)" "$file")

if grep -qE "^@freezed" "$file"; then
  while IFS= read -r m; do
    add "Satır ${m%%:*}: freezed sınıfı 'abstract class' veya 'sealed class' olmalı (Freezed 3)."
  done < <(grep -nA1 -E "^@freezed" "$file" | grep -E "^[0-9]+-class " | sed -E 's/^([0-9]+)-.*/\1:x/')
fi

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "flutter-kit kural ihlali — $rel:"
    for p in "${problems[@]}"; do echo "  - $p"; done
    $review_mode || echo "Bunları şimdi düzelt (flutter-clean-code / flutter-architecture). Bilerek bırakıyorsan kullanıcıya nedenini söyle."
  } >&2
  exit 2
fi
exit 0
