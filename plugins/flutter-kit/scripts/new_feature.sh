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
      -e "s|__MODEL__|$MODEL|g" -e "s|__Model__|$MODEL_P|g" -e "s|__model__|$MODEL_C|g" | filter_flags > "$tmp"
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

  // Yeni kayıtta id'yi sunucu verir.                                       //@F
  Future<void> create(__Model__ item) =>                                    //@F
      _dio.post<void>(_path, data: item.toJson()..remove('id'));            //@F
                                                                            //@F
  Future<void> update(__Model__ item) =>                                    //@F
      _dio.put<void>('$_path/${item.id}', data: item.toJson());             //@F
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

  Future<void> create(__Model__ item) => _guard(() => _service.create(item)); //@F
                                                                            //@F
  Future<void> update(__Model__ item) => _guard(() => _service.update(item)); //@F

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

  // Yeni kayıtta doküman id'sini Firestore verir.                          //@F
  Future<void> create(__Model__ item) => _collection.add(item);             //@F
                                                                            //@F
  Future<void> update(__Model__ item) => _collection.doc(item.id).set(item); //@F
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

  // Sadece FirebaseException çevrilir; diğer hatalar olduğu gibi geçer.
  Stream<List<__Model__>> watchAll() => _service.watchAll().handleError(
        (Object e) => throw mapFirebaseException(e as FirebaseException),
        test: (e) => e is FirebaseException,
      );

  Future<__Model__?> fetchById(String id) => _guard(() => _service.getById(id));

  Future<void> create(__Model__ item) => _guard(() => _service.create(item)); //@F
                                                                            //@F
  Future<void> update(__Model__ item) => _guard(() => _service.update(item)); //@F

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
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
import 'package:__APP__/core/router/routes.dart'; //@DR|FR
import 'package:go_router/go_router.dart'; //@DR|FR

class __Model__ListScreen extends ConsumerWidget {
  const __Model__ListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(__model__ListViewModelProvider);

    return Scaffold(
      // TODO(flutter-kit): Başlık ve metinleri l10n / AppStrings'e taşı.
      appBar: AppBar(title: const Text('__Feature__')),
      floatingActionButton: FloatingActionButton( //@FR
        onPressed: () => context.push(Routes.__model__FormPath), //@FR
        child: const Icon(Icons.add), //@FR
      ), //@FR
      body: switch (items) {
        AsyncData(:final value) when value.isEmpty =>
          const AppEmptyView(message: 'Kayıt yok'),
        AsyncData(:final value) => ListView.separated(
            padding: AppSpacing.page,
            itemCount: value.length,
            separatorBuilder: (_, _) => AppGap.sm,
            itemBuilder: (_, index) => __Model__Tile(item: value[index]), //@d|r
            itemBuilder: (_, index) => __Model__Tile( //@DR
              item: value[index], //@DR
              onTap: () => //@DR
                  context.push(Routes.__model__DetailPath(value[index].id)), //@DR
            ), //@DR
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

# ---------------------------------------------------------------- detay (--with-detail)
if $WITH_DETAIL; then
emit "$LIB/ui/view_models/${MODEL}_detail_view_model.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart'; //@B
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__MODEL___detail_view_model.g.dart';

// Kullanım: ref.watch(__model__DetailViewModelProvider(id))
@riverpod
class __Model__DetailViewModel extends _$__Model__DetailViewModel {
  @override
  Future<__Model__> build(String id) => //@b
      ref.watch(__feature__RepositoryProvider).fetchById(id); //@b
  Future<__Model__> build(String id) async { //@B
    final item = await ref.watch(__feature__RepositoryProvider).fetchById(id); //@B
    return item ?? (throw const NotFoundException()); //@B
  } //@B
}
T

emit "$LIB/ui/screens/${MODEL}_detail_screen.dart" <<'T'
import 'package:__APP__/core/widgets/app_error_view.dart';
import 'package:__APP__/core/widgets/app_loading_view.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___detail_view_model.dart';
import 'package:__APP__/features/__FEATURE__/ui/widgets/__MODEL___detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:__APP__/core/router/routes.dart'; //@FR
import 'package:go_router/go_router.dart'; //@FR

class __Model__DetailScreen extends ConsumerWidget {
  const __Model__DetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(__model__DetailViewModelProvider(id));

    return Scaffold(
      // TODO(flutter-kit): Başlığı l10n / AppStrings'e taşı.
      appBar: AppBar( //@FR
        title: const Text('Detay'), //@FR
        actions: [ //@FR
          if (item.value case final value?) //@FR
            IconButton( //@FR
              icon: const Icon(Icons.edit), //@FR
              onPressed: () => //@FR
                  context.push(Routes.__model__FormPath, extra: value), //@FR
            ), //@FR
        ], //@FR
      ), //@FR
      appBar: AppBar(title: const Text('Detay')), //@f|r
      body: switch (item) {
        AsyncData(:final value) => __Model__DetailView(item: value),
        AsyncError(:final error) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(__model__DetailViewModelProvider(id)),
          ),
        _ => const AppLoadingView(),
      },
    );
  }
}
T

emit "$LIB/ui/widgets/${MODEL}_detail_view.dart" <<'T'
import 'package:__APP__/core/constants/app_spacing.dart';
import 'package:__APP__/core/extensions/context_extensions.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:flutter/material.dart';

class __Model__DetailView extends StatelessWidget {
  const __Model__DetailView({required this.item, super.key});

  final __Model__ item;

  @override
  Widget build(BuildContext context) {
    // TODO(flutter-kit): Modelin diğer alanlarını göster.
    return ListView(
      padding: AppSpacing.page,
      children: [
        Text(item.name, style: context.textTheme.headlineSmall),
      ],
    );
  }
}
T

emit "$TEST/ui/view_models/${MODEL}_detail_view_model_test.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart'; //@B
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___detail_view_model.dart';
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

  test('id ile kaydı verir', () async {
    when(() => repository.fetchById('1')).thenAnswer((_) async => item);

    final provider = __model__DetailViewModelProvider('1');
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), item);
  });
  //@B
  test('kayıt yoksa NotFoundException verir', () async { //@B
    when(() => repository.fetchById('x')).thenAnswer((_) async => null); //@B
    //@B
    final provider = __model__DetailViewModelProvider('x'); //@B
    container.listen(provider, (_, _) {}); //@B
    await expectLater( //@B
      container.read(provider.future), //@B
      throwsA(isA<NotFoundException>()), //@B
    ); //@B
  }); //@B
}
T
fi

# ---------------------------------------------------------------- form (--with-form)
if $WITH_FORM; then
emit "$LIB/ui/view_models/${MODEL}_form_view_model.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___list_view_model.dart'; //@b
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '__MODEL___form_view_model.freezed.dart';
part '__MODEL___form_view_model.g.dart';

// TODO(flutter-kit): Modelin düzenlenebilir alanlarını ekle.
@freezed
abstract class __Model__FormState with _$__Model__FormState {
  const factory __Model__FormState({
    @Default('') String name,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = ___Model__FormState;

  const __Model__FormState._();

  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;
}

/// [initial] null ise yeni kayıt, değilse düzenleme.
/// Kullanım: ref.watch(__model__FormViewModelProvider(initial))
@riverpod
class __Model__FormViewModel extends _$__Model__FormViewModel {
  @override
  __Model__FormState build(__Model__? initial) =>
      __Model__FormState(name: initial?.name ?? '');

  void setName(String value) =>
      state = state.copyWith(name: value, errorMessage: null);

  /// Başarılıysa true döner; geri dönmeyi (navigasyonu) UI yapar.
  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final repository = ref.read(__feature__RepositoryProvider);
    final name = state.name.trim();
    try {
      final existing = initial;
      if (existing == null) {
        await repository.create(__Model__(id: '', name: name));
      } else {
        await repository.update(existing.copyWith(name: name));
      }
      ref.invalidate(__model__ListViewModelProvider); //@b
      return true;
    } on AppException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.message);
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSubmitting: false);
    }
  }
}
T

emit "$LIB/ui/screens/${MODEL}_form_screen.dart" <<'T'
import 'package:__APP__/core/extensions/context_extensions.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___form_view_model.dart';
import 'package:__APP__/features/__FEATURE__/ui/widgets/__MODEL___form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class __Model__FormScreen extends ConsumerWidget {
  const __Model__FormScreen({super.key, this.initial});

  /// null ise yeni kayıt.
  final __Model__? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      __model__FormViewModelProvider(initial).select((s) => s.errorMessage),
      (_, message) {
        if (message != null) context.showSnack(message);
      },
    );

    return Scaffold(
      // TODO(flutter-kit): Başlıkları l10n / AppStrings'e taşı.
      appBar: AppBar(
        title: Text(initial == null ? 'Yeni kayıt' : 'Düzenle'),
      ),
      body: __Model__FormView(initial: initial),
    );
  }
}
T

emit "$LIB/ui/widgets/${MODEL}_form_view.dart" <<'T'
import 'package:__APP__/core/constants/app_spacing.dart';
import 'package:__APP__/core/widgets/app_button.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___form_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class __Model__FormView extends ConsumerWidget {
  const __Model__FormView({super.key, this.initial});

  final __Model__? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = __model__FormViewModelProvider(initial);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    // TODO(flutter-kit): Alanları ve etiketleri (l10n) düzenle.
    return ListView(
      padding: AppSpacing.page,
      children: [
        TextFormField(
          initialValue: state.name,
          decoration: const InputDecoration(labelText: 'Ad'),
          textInputAction: TextInputAction.done,
          onChanged: viewModel.setName,
        ),
        AppGap.lg,
        AppButton(
          label: 'Kaydet',
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? () => _submit(context, viewModel) : null,
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    __Model__FormViewModel viewModel,
  ) async {
    final isSaved = await viewModel.submit();
    if (isSaved && context.mounted) Navigator.of(context).pop();
  }
}
T

emit "$TEST/ui/view_models/${MODEL}_form_view_model_test.dart" <<'T'
import 'package:__APP__/core/errors/app_exception.dart';
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart';
import 'package:__APP__/features/__FEATURE__/data/repositories/__FEATURE___repository.dart';
import 'package:__APP__/features/__FEATURE__/ui/view_models/__MODEL___form_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mock__Feature__Repository extends Mock
    implements __Feature__Repository {}

void main() {
  late _Mock__Feature__Repository repository;
  late ProviderContainer container;

  const item = __Model__(id: '1', name: 'Örnek');

  setUpAll(() => registerFallbackValue(item));

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

  __Model__FormViewModel listenTo(__Model__? initial) {
    final provider = __model__FormViewModelProvider(initial);
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier);
  }

  test('ad boşsa kaydetmez', () async {
    final viewModel = listenTo(null);

    expect(await viewModel.submit(), isFalse);
    verifyNever(() => repository.create(any()));
  });

  test('yeni kayıtta create çağırır', () async {
    when(() => repository.create(any())).thenAnswer((_) async {});
    final viewModel = listenTo(null)..setName('  Yeni  ');

    expect(await viewModel.submit(), isTrue);
    final saved =
        verify(() => repository.create(captureAny())).captured.single
            as __Model__;
    expect(saved.name, 'Yeni');
  });

  test('düzenlemede update çağırır, id korunur', () async {
    when(() => repository.update(any())).thenAnswer((_) async {});
    final viewModel = listenTo(item)..setName('Değişti');

    expect(await viewModel.submit(), isTrue);
    verify(
      () => repository.update(item.copyWith(name: 'Değişti')),
    ).called(1);
  });

  test('hata olursa mesajı state içine yazar', () async {
    when(() => repository.create(any()))
        .thenAnswer((_) async => throw const NetworkException());
    final viewModel = listenTo(null)..setName('Yeni');

    expect(await viewModel.submit(), isFalse);
    final state = container.read(__model__FormViewModelProvider(null));
    expect(state.errorMessage, isNotNull);
    expect(state.isSubmitting, isFalse);
  });
}
T
fi

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

    // autoDispose provider: dinleyici yoksa ilk değerden önce kapanır.
    container.listen(__model__ListViewModelProvider, (_, _) {});
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

    // autoDispose provider: dinleyici yoksa ilk değerden önce kapanır.
    container.listen(__model__ListViewModelProvider, (_, _) {});
    expect(await container.read(__model__ListViewModelProvider.future), [item]);
  });
}
T
fi

# ---------------------------------------------------------------- rota
# Router'da "// flutter-kit:" işaretleri varsa (project-setup başlangıç router'ı)
# liste rotası (+ detay/form alt rotaları) ve import'lar eklenir; ilk feature
# açılış ekranı olur. İşaret yoksa ya da feature rotası zaten varsa elle eklenir.
route_status="elle ekle (core/router/routes.dart + app_router.dart)"
render() { # stdin şablonu → yer tutucular + bayraklar uygulanmış metin
  sed -e "s|__APP__|$APP|g" -e "s|__FEATURE_PATH__|${FEATURE//_/-}|g" \
      -e "s|__FEATURE__|$FEATURE|g" -e "s|__Feature__|$FEATURE_P|g" -e "s|__feature__|$FEATURE_C|g" \
      -e "s|__MODEL__|$MODEL|g" -e "s|__Model__|$MODEL_P|g" -e "s|__model__|$MODEL_C|g" | filter_flags
}
insert_before() { # $1 dosya, $2 işaret; eklenecek satırlar stdin'den
  blk="$(mktemp)"; render > "$blk"
  awk -v m="$2" -v f="$blk" 'index($0, m) && !done { while ((getline l < f) > 0) print l; done = 1 } { print }' "$1" > "$1.tmp" \
    && mv "$1.tmp" "$1"
  rm -f "$blk"
}
if $ROUTER_AUTO; then
  insert_before "$ROUTES" "// flutter-kit:routes" <<'T'
  static const __feature__ = '/__FEATURE_PATH__';
  static const __model__Detail = 'detail/:id'; //@D
  static String __model__DetailPath(String id) => '/__FEATURE_PATH__/detail/$id'; //@D
  static const __model__Form = 'form'; //@F
  static const __model__FormPath = '/__FEATURE_PATH__/form'; //@F
T
  insert_before "$ROUTER" "// flutter-kit:imports" <<'T'
import 'package:__APP__/features/__FEATURE__/ui/screens/__MODEL___list_screen.dart';
import 'package:__APP__/features/__FEATURE__/ui/screens/__MODEL___detail_screen.dart'; //@D
import 'package:__APP__/features/__FEATURE__/ui/screens/__MODEL___form_screen.dart'; //@F
import 'package:__APP__/features/__FEATURE__/data/models/__MODEL__.dart'; //@F
T
  insert_before "$ROUTER" "// flutter-kit:routes" <<'T'
      GoRoute(path: Routes.__feature__, builder: (_, _) => const __Model__ListScreen()), //@df
      GoRoute( //@D|F
        path: Routes.__feature__, //@D|F
        builder: (_, _) => const __Model__ListScreen(), //@D|F
        routes: [ //@D|F
          GoRoute( //@D
            path: Routes.__model__Detail, //@D
            builder: (_, state) => //@D
                __Model__DetailScreen(id: state.pathParameters['id'] ?? ''), //@D
          ), //@D
          GoRoute( //@F
            path: Routes.__model__Form, //@F
            // Düzenlemede kayıt `extra` ile gelir; yoksa yeni kayıt. //@F
            builder: (_, state) => //@F
                __Model__FormScreen(initial: state.extra as __Model__?), //@F
          ), //@F
        ], //@D|F
      ), //@D|F
T
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
