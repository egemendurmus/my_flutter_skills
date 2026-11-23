#!/usr/bin/env bash
# UserPromptSubmit hook: Flutter işlerinde Claude'a flutter-kit skill'lerini hatırlatır.
# stdout'a yazılan metin Claude'un bağlamına eklenir. Hiçbir şey yazmazsa etkisi yoktur.

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project_dir="${project_dir//$'\r'/}"
project_dir="${project_dir//\\//}"  # Windows: C:\a\b → C:/a/b (Git Bash bunu okuyabilir)

json_field() {
  # $1: alan adı. python3 varsa doğru parse, yoksa kaba sed.
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('$1',''))
except Exception: pass" 2>/dev/null
  else
    printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}

prompt="$(json_field prompt)"
session="$(json_field session_id)"
marker_dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}"
marker="$marker_dir/flutter-kit-seen-${session:-nosession}"

is_flutter=false
if [ -f "$project_dir/pubspec.yaml" ] && grep -q "sdk:[[:space:]]*flutter" "$project_dir/pubspec.yaml"; then
  is_flutter=true
fi

if $is_flutter; then
  if [ -f "$marker" ]; then
    echo "[flutter-kit] Flutter projesi: flutter-architecture + flutter-clean-code kuralları geçerli."
    exit 0
  fi
  mkdir -p "$marker_dir" 2>/dev/null && : > "$marker" 2>/dev/null
  echo "[flutter-kit] Bu bir Flutter projesi ve flutter-kit plugin'i kurulu."
  echo "- Kod yazmadan önce flutter-architecture ve flutter-clean-code skill'lerini yükle ve uygula; iş türüne göre ilgili skill'i de (feature-scaffold, api-data, firebase, ui-components, testing, project-docs)."
  if [ -f "$project_dir/docs/GECIS.md" ]; then
    echo "- docs/GECIS.md var: proje yeni yapıya taşınıyor. Önce onu oku; lib/core ve lib/features dışı eski yapıdır."
  elif [ ! -d "$project_dir/lib/features" ] && [ "$(find "$project_dir/lib" -name '*.dart' 2>/dev/null | wc -l | tr -d ' ')" -le 1 ]; then
    echo "- Yeni oluşturulmuş proje (sadece main.dart var): flutter-kit:yeni-proje adımlarına devam et; sayaç örneğini sil, yapıyı project-setup.md'ye göre kur."
  elif [ ! -d "$project_dir/lib/features" ]; then
    echo "- Proje henüz flutter-kit yapısında değil (lib/features yok). Yeni özellik veya yapısal değişiklikten önce flutter-migrate-existing skill'iyle başla: önce analiz ve plan, kullanıcı onayı."
  fi
  echo "- Yapı/özellik/paket değişince docs/ altındaki dokümanları aynı işte güncelle."
  exit 0
fi

# Flutter projesi değil: yeni uygulama isteği mi?
other_stack=false
for f in package.json Cargo.toml go.mod requirements.txt pyproject.toml pom.xml build.gradle Gemfile composer.json; do
  [ -f "$project_dir/$f" ] && other_stack=true && break
done

if ! $other_stack && printf '%s' "$prompt" | grep -qiE "flutter|uygulama|mobil|(^|[^a-z])app([^a-z]|$)|android|ios|proje (kur|oluştur|yap|aç)"; then
  echo "[flutter-kit] Kullanıcı başka bir teknoloji belirtmedikçe uygulama/mobil uygulama istekleri Flutter ile ve flutter-kit standartlarıyla yapılır."
  echo "- Yeni proje: flutter-kit:yeni-proje skill'ini yükle ve adımlarını sırayla uygula (flutter-architecture → references/project-setup.md, ardından flutter-project-docs). Varsayılan 'flutter create' sayaç örneğini bırakma."
  echo "- Proje adı, platformlar ve backend (REST API / Firebase) belli değilse başlamadan kısaca sor."
fi
exit 0
