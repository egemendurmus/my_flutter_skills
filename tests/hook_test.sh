#!/usr/bin/env bash
# check_dart_file.sh için hızlı fixture testleri (Flutter gerekmez, saniyeler sürer).
#
# tests/hook_fixtures/lib/... altındaki her .dart dosyası beklentisini kendi
# başında yazar:
#   // expect: clean                → hiç ihlal çıkmamalı
#   // expect: <mesajdan bir parça>  → bu mesaj çıkmalı (birden fazla satır olabilir)
# İhlal sayısı da expect satırı sayısına eşit olmalı: fazladan uyarı (yanlış alarm)
# da testi düşürür.
#
# Kullanım: tests/hook_test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/plugins/flutter-kit/scripts/check_dart_file.sh"
FIX="$ROOT/tests/hook_fixtures"
pass=0; failures=0

check() { # $1 dosya (FIX'e göre); beklentiler dosyanın içinden okunur
  local rel="$1" out code expects n_exp n_got miss=""
  out="$(bash "$CHECK" "$FIX/$rel" "$FIX" 2>&1)"; code=$?
  expects="$(sed -n 's|^// expect: ||p' "$FIX/$rel")"
  n_got="$(printf '%s\n' "$out" | grep -c '^  - ')"
  if [ "$expects" = clean ]; then
    n_exp=0
  else
    n_exp="$(printf '%s\n' "$expects" | grep -c .)"
    while IFS= read -r e; do
      printf '%s\n' "$out" | grep -qF -- "$e" || miss="$miss\n      eksik: $e"
    done <<< "$expects"
  fi
  local want_code=2; [ "$n_exp" = 0 ] && want_code=0
  if [ -z "$miss" ] && [ "$n_got" = "$n_exp" ] && [ "$code" = "$want_code" ]; then
    pass=$((pass + 1))
  else
    failures=$((failures + 1))
    printf '  ✗ %s (beklenen %s ihlal, çıkan %s, exit %s)' "$rel" "$n_exp" "$n_got" "$code"
    printf '%b\n' "$miss"
    printf '%s\n' "$out" | sed 's/^/      | /'
  fi
}

while IFS= read -r f; do
  check "${f#"$FIX"/}"
done < <(find "$FIX/lib" -name '*.dart' | LC_ALL=C sort)

# 300 satır sınırı: fixture'ı burada üret (repoda uzun dosya tutmamak için)
long="lib/features/shop/data/models/long_model.dart"
{ echo "// expect: satır (sınır 300)"; for i in $(seq 1 305); do echo "const v$i = $i;"; done; } > "$FIX/$long"
check "$long"
rm -f "$FIX/$long"

# Hook modu: Claude Code'un stdin'den gönderdiği JSON ile de çalışmalı
target="$FIX/lib/features/shop/ui/screens/cart_page.dart"
p="$target"; pdir="$FIX"
if command -v cygpath >/dev/null 2>&1; then p="$(cygpath -w "$p")"; pdir="$(cygpath -w "$FIX")"; fi
json="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$(printf '%s' "$p" | sed 's/\\/\\\\/g')")"
cp "$target" "$target.bak"  # hook modu dart format uygulayabilir
out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$CHECK" 2>&1)"; code=$?
mv "$target.bak" "$target"
if [ "$code" = 2 ] && printf '%s' "$out" | grep -qF "_screen.dart' ile bitmeli"; then
  pass=$((pass + 1))
else
  failures=$((failures + 1)); echo "  ✗ hook modu (JSON stdin): exit $code"; printf '%s\n' "$out" | sed 's/^/      | /'
fi

echo
if [ "$failures" = 0 ]; then echo "hook testleri: $pass/$pass geçti"; else echo "hook testleri: $failures başarısız, $pass geçti"; fi
exit $((failures > 0))
