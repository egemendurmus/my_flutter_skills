#!/usr/bin/env bash
# flutter-kit uçtan uca testi: skill'lerin ürettiği kod gerçek bir Flutter
# projesinde derleniyor, analizden ve testlerden geçiyor mu?
#
#   1. flutter create + paketler (güncel sürümler — paket kırılmalarını yakalar)
#   2. setup_core.sh (rest + firebase) + new_feature.sh (products/rest, stock/firebase)
#   3. build_runner → dart fix → dart format → flutter analyze → flutter test
#   4. kural hook'u: üretilen dosyalar temiz geçmeli, kasıtlı ihlal yakalanmalı
#   5. find_widget_duplicates.py çalışmalı
#
# Kullanım: tests/e2e.sh [çalışma_dizini]   (verilmezse geçici dizin, sonunda silinir)
# Gerekenler: flutter, bash; python3 varsa 5. adım da çalışır.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/plugins/flutter-kit"
if [ $# -gt 0 ]; then WORK="$1"; mkdir -p "$WORK"; KEEP=true; else WORK="$(mktemp -d)"; KEEP=false; fi
APP="$WORK/e2e_app"
LOG="$WORK/logs"; mkdir -p "$LOG"
failures=0

step() { printf '\n== %s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; failures=$((failures + 1)); }
run()  { # $1 ad, sonrası komut; çıktı loga, hata olursa son satırları göster
  local name="$1"; shift
  if "$@" > "$LOG/$name.log" 2>&1; then ok "$name"; return 0; fi
  fail "$name (log: $LOG/$name.log)"; tail -20 "$LOG/$name.log" | sed 's/^/    /'; return 1
}
cleanup() { $KEEP || rm -rf "$WORK"; }
trap cleanup EXIT

PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && [ "$("$c" -c 'print(1)' 2>/dev/null)" = "1" ]; then PY="$c"; break; fi
done

step "1. Proje"
rm -rf "$APP"
run flutter_create flutter create --org com.example --platforms android "$WORK/e2e_app" || exit 1
cd "$APP" || exit 1
rm -f test/widget_test.dart
run pub_add flutter pub add flutter_riverpod riverpod_annotation go_router dio freezed_annotation json_annotation \
  flutter_secure_storage firebase_core firebase_auth cloud_firestore || exit 1
run pub_add_dev flutter pub add dev:build_runner dev:riverpod_generator dev:freezed dev:json_serializable \
  dev:very_good_analysis dev:mocktail || exit 1
# analysis_options.yaml: project-setup.md §3'teki yaml bloğu
awk '/^## 3\./ { s = 1 } s && /^```yaml/ { b = 1; next } b && /^```/ { exit } b' \
  "$KIT/skills/flutter-architecture/references/project-setup.md" > analysis_options.yaml
grep -q very_good_analysis analysis_options.yaml && ok "analysis_options.yaml" || fail "analysis_options.yaml çıkarılamadı"
grep -E '^\s+(flutter_riverpod|riverpod_annotation|freezed|dio|cloud_firestore|go_router):' pubspec.yaml | sed 's/^ */    /'

step "2. Script'ler"
run setup_core_rest bash "$KIT/scripts/setup_core.sh" --source rest --project "$APP" --force-entry
run setup_core_firebase bash "$KIT/scripts/setup_core.sh" --source firebase --project "$APP"
run feature_rest bash "$KIT/scripts/new_feature.sh" products --source rest --with-detail --with-form --project "$APP"
run feature_firebase bash "$KIT/scripts/new_feature.sh" stock --model stock_item --source firebase --with-detail --with-form --project "$APP"
run feature_plain bash "$KIT/scripts/new_feature.sh" order_lines --source rest --project "$APP"
run feature_form_only bash "$KIT/scripts/new_feature.sh" invoices --source rest --with-form --project "$APP"
run feature_detail_only bash "$KIT/scripts/new_feature.sh" notes --source firebase --with-detail --project "$APP"
[ "$(grep -c 'path: Routes.invoices,' lib/core/router/app_router.dart)" = 1 ] \
  && [ "$(grep -c 'path: Routes.notes,' lib/core/router/app_router.dart)" = 1 ] \
  && ok "tek bayrakta (sadece form / sadece detay) rota bir kez eklendi" || fail "tek bayrakta rota tekrarlandı veya eksik"
grep -q "UYARI" "$LOG/feature_rest.log" "$LOG/feature_firebase.log" && fail "new_feature eksik core dosyası bildirdi"
n_rest="$(grep -cE '^\s+\+' "$LOG/feature_rest.log")"; n_plain="$(grep -cE '^\s+\+' "$LOG/feature_plain.log")"
[ "$n_rest" = 16 ] && [ "$n_plain" = 8 ] && ok "dosya sayısı: detay+form 16, bayraksız 8" || fail "dosya sayısı: detay+form $n_rest (16), bayraksız $n_plain (8)"
grep -q "açılış ekranı" "$LOG/feature_rest.log" && ok "ilk feature açılış ekranı oldu" || fail "rota/açılış ekranı eklenmedi"
grep -q "Routes.stock" lib/core/router/app_router.dart && ok "ikinci feature rotası eklendi" || fail "ikinci rota eklenmedi"
grep -q "productDetailPath" lib/core/router/routes.dart && grep -q "ProductFormScreen" lib/core/router/app_router.dart \
  && ok "detay/form alt rotaları eklendi" || fail "detay/form alt rotaları eklenmedi"
if grep -rqE "//@[A-Za-z|]+[[:space:]]*$" lib test; then
  fail "üretilen dosyalarda //@ işareti kaldı"; grep -rnE "//@[A-Za-z|]+[[:space:]]*$" lib test | head -5 | sed 's/^/    /'
else ok "şablon işaretleri temizlendi"; fi
if grep -q "go_router" lib/features/order_lines/ui/screens/order_line_list_screen.dart; then
  fail "bayraksız liste ekranına gereksiz import girdi"
else ok "bayraksız liste ekranı sade"; fi
run feature_rerun bash "$KIT/scripts/new_feature.sh" products --source rest --project "$APP"
[ "$(grep -c 'static const products' lib/core/router/routes.dart)" = 1 ] && ok "tekrar çalıştırma rotayı çoğaltmadı" \
  || fail "tekrar çalıştırma rotayı çoğalttı"

step "3. Derleme, analiz, test"
run build_runner dart run build_runner build
grep -E '^W ' "$LOG/build_runner.log" | sed 's/^/    uyarı: /'
run dart_fix dart fix --apply
run dart_format dart format .
flutter analyze > "$LOG/analyze.log" 2>&1
# pubspec sıralaması 'flutter pub add'den gelir, skill çıktısı değildir
issues="$(grep -E ' (info|warning|error) - ' "$LOG/analyze.log" | grep -v sort_pub_dependencies)"
if [ -z "$issues" ]; then ok "flutter analyze (skill kodunda sıfır uyarı)"; else fail "flutter analyze"; echo "$issues" | sed 's/^/    /'; fi
run flutter_test flutter test && grep -E 'All tests passed' "$LOG/flutter_test.log" | tail -1 | sed 's/^/    /'

step "4. Kural hook'u"
clean=0; dirty=0
while IFS= read -r f; do
  if bash "$KIT/scripts/check_dart_file.sh" "$f" "$APP" > "$LOG/hook_last.log" 2>&1; then clean=$((clean + 1))
  else dirty=$((dirty + 1)); sed 's/^/    /' "$LOG/hook_last.log"; fi
done < <(find lib/core lib/features lib/main.dart lib/app.dart -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart')
[ "$dirty" = 0 ] && ok "üretilen $clean dosya temiz" || fail "$dirty üretilen dosyada ihlal"

mkdir -p lib/features/shop/ui/screens
cat > lib/features/shop/ui/screens/shop_page.dart <<'EOF'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
class ShopController extends StatelessWidget {
  Widget _buildBody() => Padding(padding: EdgeInsets.all(8), child: Text('x', style: TextStyle(fontSize: 14, color: Colors.red)));
}
EOF
hook_json() { # hook'a Claude Code'un gönderdiği biçimde JSON ver
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then p="$(cygpath -w "$p")"; fi  # Windows: gerçek yol biçimi
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$(printf '%s' "$p" | sed 's/\\/\\\\/g')"
}
pdir="$APP"; command -v cygpath >/dev/null 2>&1 && pdir="$(cygpath -w "$APP")"
out="$(hook_json "$APP/lib/features/shop/ui/screens/shop_page.dart" | CLAUDE_PROJECT_DIR="$pdir" bash "$KIT/scripts/check_dart_file.sh" 2>&1)"; code=$?
n="$(printf '%s\n' "$out" | grep -c '^  - ')"
if [ "$code" = 2 ] && [ "$n" -ge 7 ]; then ok "kasıtlı ihlal yakalandı ($n kural, hook modu)"; else fail "kasıtlı ihlal: exit=$code, $n kural (beklenen ≥7)"; echo "$out" | sed 's/^/    /'; fi
rm -rf lib/features/shop

step "5. Tekrar tarayıcı"
if [ -n "$PY" ]; then
  run duplicates "$PY" -I "$KIT/skills/flutter-ui-components/scripts/find_widget_duplicates.py" lib/
  run duplicates_json sh -c "\"$PY\" -I \"$KIT/skills/flutter-ui-components/scripts/find_widget_duplicates.py\" lib/ --json | \"$PY\" -I -c 'import json,sys; json.load(sys.stdin)'"
else
  echo "  - python yok, atlandı"
fi

echo
if [ "$failures" = 0 ]; then echo "SONUÇ: tümü geçti"; else echo "SONUÇ: $failures adım başarısız"; fi
$KEEP && echo "Proje: $APP"
exit $((failures > 0))
