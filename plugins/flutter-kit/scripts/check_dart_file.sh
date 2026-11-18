#!/usr/bin/env bash
# PostToolUse hook: Claude bir .dart dosyasını yazdığında/düzenlediğinde çalışır.
# dart format uygular, flutter-kit kurallarını kontrol eder. İhlal varsa stderr'e yazıp
# exit 2 döner; Claude Code bu mesajı Claude'a geri verir ve Claude düzeltir.

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

if command -v python3 >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception: pass" 2>/dev/null)"
else
  file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# Sadece lib/ altındaki elle yazılmış .dart dosyaları
case "$file" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.mocks.dart) exit 0 ;;
  */lib/*.dart) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# Taşınma sürüyorsa eski yapıdaki dosyalara kural dayatma
rel="${file#"$project_dir"/}"
if [ -f "$project_dir/docs/GECIS.md" ]; then
  case "$rel" in
    lib/core/*|lib/features/*|lib/main.dart|lib/app.dart) ;;
    *) exit 0 ;;
  esac
fi

command -v dart >/dev/null 2>&1 && dart format "$file" >/dev/null 2>&1

problems=()
add() { problems+=("$1"); }

lines=$(wc -l < "$file" | tr -d ' ')
[ "$lines" -gt 300 ] && add "Dosya $lines satır (sınır 300): widget'ları/yardımcıları ayrı dosyalara böl."

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
    done < <(grep -nE "(^|[^A-Za-z_])Dio\(|FirebaseFirestore\.instance|FirebaseAuth\.instance" "$file")
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
    echo "Bunları şimdi düzelt (flutter-clean-code / flutter-architecture). Bilerek bırakıyorsan kullanıcıya nedenini söyle."
  } >&2
  exit 2
fi
exit 0
