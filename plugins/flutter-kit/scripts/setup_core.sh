#!/usr/bin/env bash
# Yeni projede lib/core/, lib/main.dart ve lib/app.dart dosyalarını skill
# reference'larındaki kod bloklarından üretir. Kodun tek kaynağı reference'lardır;
# bu script sadece onları doğru yere kopyalar (Claude'un 20+ dosyayı elle yazmasından
# çok daha az token, kopyalama hatası yok).
#
# Kullanım:
#   setup_core.sh [--source rest|firebase] [--project <proje_kökü>] [--force-entry]
#
#   --source       veri kaynağı; verilmezse pubspec'ten tahmin edilir (varsayılan rest)
#   --force-entry  lib/main.dart ve lib/app.dart varsa da üzerine yazar
#                  ('flutter create' sayaç örneğini silmek için)
#
# Var olan core dosyasının üstüne asla yazmaz.

set -e

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

SOURCE=""; PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"; FORCE_ENTRY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --force-entry) FORCE_ENTRY=true; shift ;;
    -h|--help) usage ;;
    *) echo "Bilinmeyen seçenek: $1" >&2; usage ;;
  esac
done

PROJECT="${PROJECT//\\//}"
[ -f "$PROJECT/pubspec.yaml" ] || { echo "pubspec.yaml bulunamadı: $PROJECT" >&2; exit 1; }
APP="$(sed -n 's/^name:[[:space:]]*\([a-z0-9_]*\).*/\1/p' "$PROJECT/pubspec.yaml" | head -1)"
[ -n "$APP" ] || { echo "pubspec.yaml içinde name: bulunamadı" >&2; exit 1; }

if [ -z "$SOURCE" ]; then
  if grep -q "cloud_firestore" "$PROJECT/pubspec.yaml" && ! grep -q "^[[:space:]]*dio:" "$PROJECT/pubspec.yaml"; then
    SOURCE=firebase
  else
    SOURCE=rest
  fi
fi
case "$SOURCE" in rest|firebase) ;; *) echo "--source rest veya firebase olmalı" >&2; exit 1 ;; esac

SKILLS="$(cd "$(dirname "$0")/../skills" && pwd)"
refs=(
  flutter-architecture/references/project-setup.md
  flutter-architecture/references/app-exception.md
  flutter-clean-code/references/constants-and-extensions.md
  flutter-ui-components/references/core-widgets.md
)
if [ "$SOURCE" = rest ]; then
  refs+=(flutter-api-data/references/dio-setup.md)
else
  refs+=(flutter-firebase/SKILL.md flutter-firebase/references/firestore-patterns.md)
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Her ```dart bloğu için hedef yol:
#   1. bloğun ilk satırı "// lib/core/x.dart", "// core/x.dart", "// lib/main.dart" ise o (satır atılır)
#   2. yoksa üstteki başlıkta geçen "core/....dart"
#   3. core-widgets.md'de başlık "## app_x.dart" ise core/widgets/app_x.dart
# Aynı yol ikinci kez görülürse ilki geçerlidir.
for ref in "${refs[@]}"; do
  awk -v out="$OUT" -v ref="$ref" '
    function flush(   f, d) {
      if (path == "" || (path in seen)) return
      seen[path] = 1
      f = out "/" path
      d = f; sub(/\/[^\/]*$/, "", d)
      system("mkdir -p \"" d "\"")
      printf "%s", body > f
      close(f)
    }
    /^```dart[[:space:]]*$/ { inblock = 1; body = ""; first = 1; path = ""; next }
    inblock && /^```/ { inblock = 0; flush(); next }
    inblock {
      if (first) {
        first = 0
        if (match($0, /^\/\/ (lib\/)?(core\/[a-z0-9_\/]+\.dart|main\.dart|app\.dart)[[:space:]]*$/)) {
          path = $0; sub(/^\/\/ /, "", path); sub(/^lib\//, "", path); sub(/[[:space:]]+$/, "", path)
          next
        }
        path = hpath
      }
      body = body $0 "\n"
      next
    }
    /^#+ / {
      hpath = ""
      if (match($0, /core\/[a-z0-9_\/]+\.dart/)) hpath = substr($0, RSTART, RLENGTH)
      else if (ref ~ /core-widgets\.md$/ && match($0, /^## [a-z0-9_]+\.dart/)) hpath = "core/widgets/" substr($0, 4, RLENGTH - 3)
    }
  ' "$SKILLS/$ref"
done

created=(); skipped=()
while IFS= read -r src; do
  rel="${src#"$OUT"/}"
  dest="$PROJECT/lib/$rel"
  if [ -e "$dest" ] && { [ "$rel" != main.dart ] && [ "$rel" != app.dart ] || ! $FORCE_ENTRY; }; then
    skipped+=("lib/$rel"); continue
  fi
  mkdir -p "$(dirname "$dest")"
  sed "s|package:my_app/|package:$APP/|g" "$src" > "$dest"
  created+=("lib/$rel")
done < <(find "$OUT" -type f -name '*.dart' | LC_ALL=C sort)

echo "Core kurulumu  |  kaynak: $SOURCE  |  uygulama: $APP"
echo
echo "Oluşturulan (${#created[@]}):"
for f in "${created[@]}"; do echo "  + $f"; done
if [ ${#skipped[@]} -gt 0 ]; then
  echo "Atlanan, zaten var (${#skipped[@]}):"
  for f in "${skipped[@]}"; do echo "  = $f"; done
  case " ${skipped[*]} " in *" lib/main.dart "*|*" lib/app.dart "*)
    $FORCE_ENTRY || echo "  (main.dart/app.dart 'flutter create' örneğiyse --force-entry ile yeniden çalıştır)" ;;
  esac
fi

pkgs="flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation"
if [ "$SOURCE" = rest ]; then pkgs="$pkgs dio flutter_secure_storage"; else pkgs="$pkgs firebase_core firebase_auth cloud_firestore"; fi
missing=""
for p in $pkgs; do grep -qE "^[[:space:]]+$p:" "$PROJECT/pubspec.yaml" || missing="$missing $p"; done
dev_missing=""
for p in build_runner riverpod_generator freezed json_serializable very_good_analysis mocktail; do
  grep -qE "^[[:space:]]+$p:" "$PROJECT/pubspec.yaml" || dev_missing="$dev_missing dev:$p"
done
if [ -n "$missing$dev_missing" ]; then
  echo
  echo "UYARI — eksik paketler:"
  [ -n "$missing" ] && echo "  flutter pub add$missing"
  [ -n "$dev_missing" ] && echo "  flutter pub add$dev_missing"
fi

cat <<EOF

Sıradaki adımlar:
EOF
if [ "$SOURCE" = firebase ]; then
  echo "  - flutterfire configure, sonra lib/main.dart'a Firebase.initializeApp ekle (flutter-firebase skill'i)"
fi
cat <<EOF
  - lib/core/widgets/CATALOG.md oluştur (flutter-ui-components/references/catalog-format.md)
  - Özellik ekle: new_feature.sh <feature>
  - dart run build_runner build && dart fix --apply && dart format . && flutter analyze
EOF
