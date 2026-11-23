#!/usr/bin/env bash
# Yeni bir feature'ın iskelet dosyalarını flutter-kit yapısında üretir.
# Claude bu dosyaları elle yazmak yerine script'i çalıştırır, sonra sadece
# model alanlarını ve iş mantığını doldurur (çok daha az token).
#
# Kullanım:
#   new_feature.sh <feature> [--model <tekil_ad>] [--source rest|firebase]
#                  [--with-detail] [--with-form] [--project <proje_kökü>]
# Örnek:
#   new_feature.sh products                 → model: product, kaynak pubspec'ten tahmin
#   new_feature.sh stock --model stock_item --source firebase
#   new_feature.sh products --with-detail --with-form
#
#   --with-detail  detay ekranı + family ViewModel + test (listeden tıklayınca açılır)
#   --with-form    oluştur/düzenle formu + form ViewModel + test; service ve
#                  repository'ye create/update eklenir
#
# Var olan dosyanın üstüne asla yazmaz.

set -e

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

FEATURE=""; MODEL=""; SOURCE=""; PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
WITH_DETAIL=false; WITH_FORM=false
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --with-detail) WITH_DETAIL=true; shift ;;
    --with-form) WITH_FORM=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Bilinmeyen seçenek: $1" >&2; usage ;;
    *) FEATURE="$1"; shift ;;
  esac
done

[ -n "$FEATURE" ] || usage
echo "$FEATURE" | grep -qE '^[a-z][a-z0-9_]*$' || { echo "Feature adı snake_case olmalı: $FEATURE" >&2; exit 1; }
[ -f "$PROJECT/pubspec.yaml" ] || { echo "pubspec.yaml bulunamadı: $PROJECT" >&2; exit 1; }

APP="$(sed -n 's/^name:[[:space:]]*\([a-z0-9_]*\).*/\1/p' "$PROJECT/pubspec.yaml" | head -1)"
[ -n "$APP" ] || { echo "pubspec.yaml içinde name: bulunamadı" >&2; exit 1; }

if [ -z "$MODEL" ]; then
  case "$FEATURE" in
    *ies) MODEL="${FEATURE%ies}y" ;;
    *ss) MODEL="$FEATURE" ;;
    *s) MODEL="${FEATURE%s}" ;;
    *) MODEL="$FEATURE" ;;
  esac
fi
echo "$MODEL" | grep -qE '^[a-z][a-z0-9_]*$' || { echo "Model adı snake_case olmalı: $MODEL" >&2; exit 1; }

if [ -z "$SOURCE" ]; then
  if grep -q "cloud_firestore" "$PROJECT/pubspec.yaml" && ! grep -q "^[[:space:]]*dio:" "$PROJECT/pubspec.yaml"; then
    SOURCE=firebase
  else
    SOURCE=rest
  fi
fi
case "$SOURCE" in rest|firebase) ;; *) echo "--source rest veya firebase olmalı" >&2; exit 1 ;; esac

pascal() { printf '%s' "$1" | awk -F_ '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'; }
camel()  { p="$(pascal "$1")"; printf '%s%s' "$(printf '%s' "${p:0:1}" | tr '[:upper:]' '[:lower:]')" "${p:1}"; }

FEATURE_P="$(pascal "$FEATURE")"; FEATURE_C="$(camel "$FEATURE")"
MODEL_P="$(pascal "$MODEL")";     MODEL_C="$(camel "$MODEL")"

LIB="$PROJECT/lib/features/$FEATURE"
TEST="$PROJECT/test/features/$FEATURE"
created=(); skipped=()

ROUTES="$PROJECT/lib/core/router/routes.dart"
ROUTER="$PROJECT/lib/core/router/app_router.dart"
ROUTER_AUTO=false
if [ -f "$ROUTES" ] && [ -f "$ROUTER" ] \
   && grep -q "// flutter-kit:routes" "$ROUTES" && grep -q "// flutter-kit:routes" "$ROUTER" \
   && grep -q "// flutter-kit:imports" "$ROUTER" \
   && ! grep -qE "static const $FEATURE_C[[:space:]]*=" "$ROUTES"; then
  ROUTER_AUTO=true
fi

# Şablon bayrakları. Satır sonundaki "//@<koşul>" işareti satırı koşula bağlar:
#   büyük harf = açık olmalı, küçük harf = kapalı olmalı, "|" = veya.
#   D: --with-detail   F: --with-form   R: rota bu çalıştırmada otomatik eklenecek
#   B: kaynak Firebase (b: REST)
#   ör. "//@DR" detay açık VE rota otomatik; "//@d|r" detay kapalı VEYA rota elle
FLAGS=""
[ "$SOURCE" = firebase ] && FLAGS="${FLAGS}B"
$WITH_DETAIL && FLAGS="${FLAGS}D"
$WITH_FORM && FLAGS="${FLAGS}F"
$ROUTER_AUTO && FLAGS="${FLAGS}R"

filter_flags() {
  awk -v flags="$FLAGS" '
    function on(spec,   n, i, j, c, ok, alts) {
      n = split(spec, alts, "|")
      for (i = 1; i <= n; i++) {
        ok = 1
        for (j = 1; j <= length(alts[i]); j++) {
          c = substr(alts[i], j, 1)
          if (c ~ /[A-Z]/ && index(flags, c) == 0) ok = 0
          if (c ~ /[a-z]/ && index(flags, toupper(c)) > 0) ok = 0
        }
        if (ok) return 1
      }
      return 0
    }
    match($0, /[[:space:]]*\/\/@[A-Za-z|]+[[:space:]]*$/) {
      spec = substr($0, RSTART, RLENGTH); gsub(/[[:space:]\/@]/, "", spec)
      if (on(spec)) print substr($0, 1, RSTART - 1)
      next
    }
    { print }
  '
}

# Şablonlar: templates/feature/<yol>.dart.tmpl. Yer tutucular: __APP__,
# __FEATURE__/__Feature__/__feature__, __MODEL__/__Model__/__model__, __FEATURE_PATH__
TPL="$(cd "$(dirname "$0")/../templates/feature" && pwd)"
render() { # $1 şablon (TPL'e göre) → yer tutucular + bayraklar uygulanmış metin
  [ -f "$TPL/$1" ] || { echo "Şablon bulunamadı: $TPL/$1" >&2; exit 1; }
  sed -e "s|__APP__|$APP|g" -e "s|__FEATURE_PATH__|${FEATURE//_/-}|g"       -e "s|__FEATURE__|$FEATURE|g" -e "s|__Feature__|$FEATURE_P|g" -e "s|__feature__|$FEATURE_C|g"       -e "s|__MODEL__|$MODEL|g" -e "s|__Model__|$MODEL_P|g" -e "s|__model__|$MODEL_C|g" "$TPL/$1" | filter_flags
}

emit() { # $1 hedef dosya, $2 şablon
  dest="$1"
  if [ -e "$dest" ]; then
    skipped+=("${dest#"$PROJECT"/}")
    return
  fi
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"
  render "$2" > "$tmp"
  # import satırlarını Dart'ın directives_ordering kuralına göre (alfabetik) sırala
  { grep "^import " "$tmp" | LC_ALL=C sort; grep -v "^import " "$tmp"; } > "$dest"
  rm -f "$tmp"
  created+=("${dest#"$PROJECT"/}")
}

# ---------------------------------------------------------------- model
emit "$LIB/data/models/$MODEL.dart" lib/data/models/model.dart.tmpl

# ---------------------------------------------------------------- service + repository
if [ "$SOURCE" = rest ]; then
emit "$LIB/data/services/${FEATURE}_service.dart" lib/data/services/feature_service.rest.dart.tmpl

emit "$LIB/data/repositories/${FEATURE}_repository.dart" lib/data/repositories/feature_repository.rest.dart.tmpl
else
emit "$LIB/data/services/${FEATURE}_service.dart" lib/data/services/feature_service.firebase.dart.tmpl

emit "$LIB/data/repositories/${FEATURE}_repository.dart" lib/data/repositories/feature_repository.firebase.dart.tmpl
fi

# ---------------------------------------------------------------- view model
if [ "$SOURCE" = rest ]; then
emit "$LIB/ui/view_models/${MODEL}_list_view_model.dart" lib/ui/view_models/model_list_view_model.rest.dart.tmpl
else
emit "$LIB/ui/view_models/${MODEL}_list_view_model.dart" lib/ui/view_models/model_list_view_model.firebase.dart.tmpl
fi

# ---------------------------------------------------------------- screen + widget
emit "$LIB/ui/screens/${MODEL}_list_screen.dart" lib/ui/screens/model_list_screen.dart.tmpl

emit "$LIB/ui/widgets/${MODEL}_tile.dart" lib/ui/widgets/model_tile.dart.tmpl

# ---------------------------------------------------------------- detay (--with-detail)
if $WITH_DETAIL; then
emit "$LIB/ui/view_models/${MODEL}_detail_view_model.dart" lib/ui/view_models/model_detail_view_model.dart.tmpl

emit "$LIB/ui/screens/${MODEL}_detail_screen.dart" lib/ui/screens/model_detail_screen.dart.tmpl

emit "$LIB/ui/widgets/${MODEL}_detail_view.dart" lib/ui/widgets/model_detail_view.dart.tmpl

emit "$TEST/ui/view_models/${MODEL}_detail_view_model_test.dart" test/ui/view_models/model_detail_view_model_test.dart.tmpl
fi

# ---------------------------------------------------------------- form (--with-form)
if $WITH_FORM; then
emit "$LIB/ui/view_models/${MODEL}_form_view_model.dart" lib/ui/view_models/model_form_view_model.dart.tmpl

emit "$LIB/ui/screens/${MODEL}_form_screen.dart" lib/ui/screens/model_form_screen.dart.tmpl

emit "$LIB/ui/widgets/${MODEL}_form_view.dart" lib/ui/widgets/model_form_view.dart.tmpl

emit "$TEST/ui/view_models/${MODEL}_form_view_model_test.dart" test/ui/view_models/model_form_view_model_test.dart.tmpl
fi

# ---------------------------------------------------------------- tests
if [ "$SOURCE" = rest ]; then
emit "$TEST/data/repositories/${FEATURE}_repository_test.dart" test/data/repositories/feature_repository_test.rest.dart.tmpl
emit "$TEST/ui/view_models/${MODEL}_list_view_model_test.dart" test/ui/view_models/model_list_view_model_test.rest.dart.tmpl
else
emit "$TEST/data/repositories/${FEATURE}_repository_test.dart" test/data/repositories/feature_repository_test.firebase.dart.tmpl
emit "$TEST/ui/view_models/${MODEL}_list_view_model_test.dart" test/ui/view_models/model_list_view_model_test.firebase.dart.tmpl
fi

# ---------------------------------------------------------------- rota
# Router'da "// flutter-kit:" işaretleri varsa (project-setup başlangıç router'ı)
# liste rotası (+ detay/form alt rotaları) ve import'lar eklenir; ilk feature
# açılış ekranı olur. İşaret yoksa ya da feature rotası zaten varsa elle eklenir.
route_status="elle ekle (core/router/routes.dart + app_router.dart)"
insert_before() { # $1 dosya, $2 işaret, $3 şablon
  blk="$(mktemp)"; render "$3" > "$blk"
  awk -v m="$2" -v f="$blk" 'index($0, m) && !done { while ((getline l < f) > 0) print l; done = 1 } { print }' "$1" > "$1.tmp" \
    && mv "$1.tmp" "$1"
  rm -f "$blk"
}
if $ROUTER_AUTO; then
  insert_before "$ROUTES" "// flutter-kit:routes" router/routes.routes.dart.tmpl
  insert_before "$ROUTER" "// flutter-kit:imports" router/router.imports.dart.tmpl
  insert_before "$ROUTER" "// flutter-kit:routes" router/router.routes.dart.tmpl
  route_status="eklendi: Routes.$FEATURE_C → ${MODEL_P}ListScreen"
  $WITH_DETAIL && route_status="$route_status, detay"
  $WITH_FORM && route_status="$route_status, form"
  if grep -q "// flutter-kit:initial" "$ROUTER"; then
    sed -i.bak "s|initialLocation: Routes\.home, // flutter-kit:initial|initialLocation: Routes.$FEATURE_C,|" "$ROUTER" && rm -f "$ROUTER.bak"
    route_status="$route_status (açılış ekranı yapıldı)"
  fi
elif [ -f "$ROUTES" ] && grep -qE "static const $FEATURE_C[[:space:]]*=" "$ROUTES"; then
  route_status="zaten var (Routes.$FEATURE_C)"
  { $WITH_DETAIL || $WITH_FORM; } && route_status="$route_status — detay/form alt rotalarını elle ekle (project-setup.md §6)"
fi
if ! $ROUTER_AUTO && { $WITH_DETAIL || $WITH_FORM; }; then
  route_status="$route_status; liste ekranındaki detaya gitme / + butonu üretilmedi, rotayı ekleyince bağla"
fi

# ---------------------------------------------------------------- rapor
echo "Feature: $FEATURE  |  model: $MODEL_P  |  kaynak: $SOURCE  |  uygulama: $APP"
echo "Rota: $route_status"
echo
echo "Oluşturulan (${#created[@]}):"
for f in "${created[@]}"; do echo "  + $f"; done
if [ ${#skipped[@]} -gt 0 ]; then
  echo "Atlanan, zaten var (${#skipped[@]}):"
  for f in "${skipped[@]}"; do echo "  = $f"; done
fi

missing=()
for f in core/constants/app_spacing.dart core/widgets/app_empty_view.dart core/widgets/app_error_view.dart core/widgets/app_loading_view.dart core/errors/app_exception.dart; do
  [ -f "$PROJECT/lib/$f" ] || missing+=("lib/$f")
done
if [ "$SOURCE" = rest ]; then
  for f in core/network/dio_provider.dart core/network/dio_exception_mapper.dart; do [ -f "$PROJECT/lib/$f" ] || missing+=("lib/$f"); done
else
  for f in core/firebase/firebase_providers.dart core/firebase/firebase_exception_mapper.dart; do [ -f "$PROJECT/lib/$f" ] || missing+=("lib/$f"); done
fi
if [ ${#missing[@]} -gt 0 ]; then
  echo
  echo "UYARI — iskeletin kullandığı core dosyaları eksik (önce: bash \"$(dirname "$0")/setup_core.sh\" --source $SOURCE):"
  for f in "${missing[@]}"; do echo "  ! $f"; done
fi

cat <<EOF

Sıradaki adımlar:
  1. Model alanlarını düzenle: lib/features/$FEATURE/data/models/$MODEL.dart (TODO satırları)
  2. Rota: $route_status
  3. dart run build_runner build && dart fix --apply && dart format . && flutter analyze
  4. flutter test test/features/$FEATURE
  5. docs/MIMARI.md özellik tablosuna satır ekle
EOF
