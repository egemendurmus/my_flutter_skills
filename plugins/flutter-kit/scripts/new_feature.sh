#!/usr/bin/env bash
# Yeni bir feature'ın iskelet dosyalarını flutter-kit yapısında üretir.
# Claude bu dosyaları elle yazmak yerine script'i çalıştırır, sonra sadece
# model alanlarını ve iş mantığını doldurur (çok daha az token).
#
# Kullanım:
#   new_feature.sh <feature> [--model <tekil_ad>] [--source rest|firebase] [--project <proje_kökü>]
# Örnek:
#   new_feature.sh products                 → model: product, kaynak pubspec'ten tahmin
#   new_feature.sh stock --model stock_item --source firebase
#
# Var olan dosyanın üstüne asla yazmaz.

set -e

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

FEATURE=""; MODEL=""; SOURCE=""; PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
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

emit() {
  dest="$1"
  if [ -e "$dest" ]; then
    cat >/dev/null
    skipped+=("${dest#"$PROJECT"/}")
    return
  fi
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"
  sed -e "s|__APP__|$APP|g" \
      -e "s|__FEATURE__|$FEATURE|g" -e "s|__Feature__|$FEATURE_P|g" -e "s|__feature__|$FEATURE_C|g" \
      -e "s|__MODEL__|$MODEL|g" -e "s|__Model__|$MODEL_P|g" -e "s|__model__|$MODEL_C|g" > "$tmp"
  # import satırlarını Dart'ın directives_ordering kuralına göre (alfabetik) sırala
  { grep "^import " "$tmp" | LC_ALL=C sort; grep -v "^import " "$tmp"; } > "$dest"
  rm -f "$tmp"
  created+=("${dest#"$PROJECT"/}")
}

# ---------------------------------------------------------------- model
emit "$LIB/data/models/$MODEL.dart" <<'T'
import 'package:freezed_annotation/freezed_annotation.dart';

part '__MODEL__.freezed.dart';
part '__MODEL__.g.dart';

// TODO(flutter-kit): Alanları gerçek veriye göre düzenle.
@freezed
abstract class __Model__ with _$__Model__ {
  const factory __Model__({
    required String id,
    required String name,
  }) = ___Model__;

  factory __Model__.fromJson(Map<String, dynamic> json) =>
      _$__Model__FromJson(json);
}
T

# ---------------------------------------------------------------- service + repository
if [ "$SOURCE" = rest ]; then
emit "$LIB/data/services/${FEATURE}_service.dart" <<'T'
import 'package:__APP__/core/network/dio_provider.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__FEATURE___service.g.dart';

class __Feature__Service {
  __Feature__Service(this._dio);
  final Dio _dio;

  // TODO(flutter-kit): Endpoint yolunu backend'e göre düzenle.
  static const _path = '/__FEATURE__';

  Future<List<__Model__>> getAll() async {
    final res = await _dio.get<List<dynamic>>(_path);
    return res.data!
        .map((e) => __Model__.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<__Model__> getById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('$_path/$id');
    return __Model__.fromJson(res.data!);
  }
}

@riverpod
__Feature__Service __feature__Service(Ref ref) =>
    __Feature__Service(ref.watch(dioProvider));
T

emit "$LIB/data/repositories/${FEATURE}_repository.dart" <<'T'
import 'package:__APP__/core/network/dio_exception_mapper.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/services/__FEATURE___service.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__FEATURE___repository.g.dart';

class __Feature__Repository {
  __Feature__Repository(this._service);
  final __Feature__Service _service;

  Future<List<__Model__>> fetchAll() => _guard(_service.getAll);

  Future<__Model__> fetchById(String id) => _guard(() => _service.getById(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

@riverpod
__Feature__Repository __feature__Repository(Ref ref) =>
    __Feature__Repository(ref.watch(__feature__ServiceProvider));
T
else
emit "$LIB/data/services/${FEATURE}_service.dart" <<'T'
import 'package:__APP__/core/firebase/firebase_providers.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__FEATURE___service.g.dart';

class __Feature__Service {
  __Feature__Service(this._db);
  final FirebaseFirestore _db;

  // TODO(flutter-kit): Koleksiyon adını ve sorguyu düzenle.
  CollectionReference<__Model__> get _collection =>
      _db.collection('__FEATURE__').withConverter<__Model__>(
            fromFirestore: (snap, _) =>
                __Model__.fromJson({...snap.data()!, 'id': snap.id}),
            toFirestore: (item, _) => item.toJson()..remove('id'),
          );

  Stream<List<__Model__>> watchAll() => _collection
      .limit(100)
      .snapshots()
      .map((query) => query.docs.map((doc) => doc.data()).toList());

  Future<__Model__?> getById(String id) async =>
      (await _collection.doc(id).get()).data();
}

@riverpod
__Feature__Service __feature__Service(Ref ref) =>
    __Feature__Service(ref.watch(firestoreProvider));
T

emit "$LIB/data/repositories/${FEATURE}_repository.dart" <<'T'
import 'package:__APP__/core/firebase/firebase_exception_mapper.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/services/__FEATURE___service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__FEATURE___repository.g.dart';

class __Feature__Repository {
  __Feature__Repository(this._service);
  final __Feature__Service _service;

  Stream<List<__Model__>> watchAll() => _service.watchAll().handleError(
        (Object e) =>
            throw e is FirebaseException ? mapFirebaseException(e) : e,
      );

  Future<__Model__?> fetchById(String id) async {
    try {
      return await _service.getById(id);
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    }
  }
}

@riverpod
__Feature__Repository __feature__Repository(Ref ref) =>
    __Feature__Repository(ref.watch(__feature__ServiceProvider));
T
fi

# ---------------------------------------------------------------- view model
if [ "$SOURCE" = rest ]; then
emit "$LIB/ui/view_models/${MODEL}_list_view_model.dart" <<'T'
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__MODEL___list_view_model.g.dart';

@riverpod
class __Model__ListViewModel extends _$__Model__ListViewModel {
  @override
  Future<List<__Model__>> build() =>
      ref.watch(__feature__RepositoryProvider).fetchAll();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(__feature__RepositoryProvider).fetchAll(),
    );
  }
}
T
else
emit "$LIB/ui/view_models/${MODEL}_list_view_model.dart" <<'T'
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__MODEL___list_view_model.g.dart';

@riverpod
class __Model__ListViewModel extends _$__Model__ListViewModel {
  @override
  Stream<List<__Model__>> build() =>
      ref.watch(__feature__RepositoryProvider).watchAll();
}
T
fi

# ---------------------------------------------------------------- screen + widget
emit "$LIB/ui/screens/${MODEL}_list_screen.dart" <<'T'
import 'package:__APP__/core/constants/app_spacing.dart';
import 'package:__APP__/core/widgets/app_empty_view.dart';
import 'package:__APP__/core/widgets/app_error_view.dart';
import 'package:__APP__/core/widgets/app_loading_view.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___list_view_model.dart';
import 'package:__APP__/features/__FEATURE__/ui/widgets/__MODEL___tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class __Model__ListScreen extends ConsumerWidget {
  const __Model__ListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(__model__ListViewModelProvider);

    return Scaffold(
      // TODO(flutter-kit): Başlık ve metinleri l10n / AppStrings'e taşı.
      appBar: AppBar(title: const Text('__Feature__')),
      body: switch (items) {
        AsyncData(:final value) when value.isEmpty =>
          const AppEmptyView(message: 'Kayıt yok'),
        AsyncData(:final value) => ListView.separated(
            padding: AppSpacing.page,
            itemCount: value.length,
            separatorBuilder: (_, _) => AppGap.sm,
            itemBuilder: (_, index) => __Model__Tile(item: value[index]),
          ),
        AsyncError(:final error) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(__model__ListViewModelProvider),
          ),
        _ => const AppLoadingView(),
      },
    );
  }
}
T

emit "$LIB/ui/widgets/${MODEL}_tile.dart" <<'T'
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:flutter/material.dart';

class __Model__Tile extends StatelessWidget {
  const __Model__Tile({required this.item, super.key, this.onTap});

  final __Model__ item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name),
        onTap: onTap,
      ),
    );
  }
}
T

# ---------------------------------------------------------------- tests
if [ "$SOURCE" = rest ]; then
emit "$TEST/data/repositories/${FEATURE}_repository_test.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/data/services/__FEATURE___service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock__Feature__Service extends Mock implements __Feature__Service {}

void main() {
  late _Mock__Feature__Service service;
  late __Feature__Repository repository;

  const item = __Model__(id: '1', name: 'Örnek');

  setUp(() {
    service = _Mock__Feature__Service();
    repository = __Feature__Repository(service);
  });

  test('fetchAll kayıtları döner', () async {
    when(() => service.getAll()).thenAnswer((_) async => [item]);

    expect(await repository.fetchAll(), [item]);
  });

  test('bağlantı hatasında NetworkException fırlatır', () {
    when(() => service.getAll()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/__FEATURE__'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(repository.fetchAll(), throwsA(isA<NetworkException>()));
  });
}
T
emit "$TEST/ui/view_models/${MODEL}_list_view_model_test.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___list_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock__Feature__Repository extends Mock
    implements __Feature__Repository {}

void main() {
  late _Mock__Feature__Repository repository;
  late ProviderContainer container;

  const item = __Model__(id: '1', name: 'Örnek');

  setUp(() {
    repository = _Mock__Feature__Repository();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        __feature__RepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('yükleme başarılıysa listeyi verir', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [item]);

    expect(await container.read(__model__ListViewModelProvider.future), [item]);
  });

  test('hata olursa AsyncError olur', () async {
    when(() => repository.fetchAll())
        .thenAnswer((_) async => throw const NetworkException());

    container.listen(__model__ListViewModelProvider, (_, _) {});
    await expectLater(
      container.read(__model__ListViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );
  });
}
T
else
emit "$TEST/data/repositories/${FEATURE}_repository_test.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/data/services/__FEATURE___service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock__Feature__Service extends Mock implements __Feature__Service {}

void main() {
  late _Mock__Feature__Service service;
  late __Feature__Repository repository;

  const item = __Model__(id: '1', name: 'Örnek');

  setUp(() {
    service = _Mock__Feature__Service();
    repository = __Feature__Repository(service);
  });

  test('watchAll kayıtları akıtır', () {
    when(() => service.watchAll()).thenAnswer((_) => Stream.value([item]));

    expect(repository.watchAll(), emits([item]));
  });

  test('Firestore erişilemezse NetworkException verir', () {
    when(() => service.watchAll()).thenAnswer(
      (_) => Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
    );

    expect(repository.watchAll(), emitsError(isA<NetworkException>()));
  });
}
T
emit "$TEST/ui/view_models/${MODEL}_list_view_model_test.dart" <<'T'
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___list_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock__Feature__Repository extends Mock
    implements __Feature__Repository {}

void main() {
  late _Mock__Feature__Repository repository;
  late ProviderContainer container;

  const item = __Model__(id: '1', name: 'Örnek');

  setUp(() {
    repository = _Mock__Feature__Repository();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        __feature__RepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('akıştaki ilk listeyi verir', () async {
    when(() => repository.watchAll()).thenAnswer((_) => Stream.value([item]));

    expect(await container.read(__model__ListViewModelProvider.future), [item]);
  });
}
T
fi

# ---------------------------------------------------------------- rapor
echo "Feature: $FEATURE  |  model: $MODEL_P  |  kaynak: $SOURCE  |  uygulama: $APP"
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
  echo "UYARI — iskeletin kullandığı core dosyaları eksik (önce project-setup adımlarıyla oluştur):"
  for f in "${missing[@]}"; do echo "  ! $f"; done
fi

cat <<EOF

Sıradaki adımlar:
  1. Model alanlarını düzenle: lib/features/$FEATURE/data/models/$MODEL.dart (TODO satırları)
  2. Rota ekle: ${MODEL_P}ListScreen → core/router/routes.dart + app_router.dart
  3. dart run build_runner build -d && dart fix --apply && dart format . && flutter analyze
  4. flutter test test/features/$FEATURE
  5. docs/MIMARI.md özellik tablosuna satır ekle
EOF
