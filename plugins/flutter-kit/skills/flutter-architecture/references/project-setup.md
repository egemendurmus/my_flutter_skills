# Yeni proje kurulumu

Sırayla uygula. Her adımdan sonra hata varsa düzelt, sonra devam et.

## 1. Proje

```bash
flutter create --org com.eliar --platforms android,ios <proje_adi>
cd <proje_adi>
```

`--org` ve platformları kullanıcının ihtiyacına göre sor/ayarla (web/windows gerekiyorsa ekle).

**Varsayılan sayaç örneğini bırakma:** `lib/main.dart` içeriğini §5'teki bootstrap ile değiştir, `test/widget_test.dart`'ı sil. `flutter create` çıktısındaki demo kod projede kalmaz.

## 2. Paketler

```bash
flutter pub add flutter_riverpod riverpod_annotation go_router dio freezed_annotation json_annotation
flutter pub add dev:build_runner dev:riverpod_generator dev:freezed dev:json_serializable dev:very_good_analysis dev:mocktail
```

Gerektiğinde:

```bash
flutter pub add shared_preferences flutter_secure_storage   # lokal depolama
flutter pub add flutter_localizations --sdk=flutter          # çok dil
flutter pub add intl
```

## 3. analysis_options.yaml

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore   # freezed + @JsonKey için gerekli

linter:
  rules:
    public_member_api_docs: false
```

## 4. Ortam değişkenleri (dart-define)

`env/example.json` (commit'lenir):

```json
{
  "API_BASE_URL": "https://api.example.com",
  "APP_ENV": "dev"
}
```

`env/dev.json` ve `env/prod.json` aynı şekilde, **`.gitignore`'a ekle**:

```
env/*.json
!env/example.json
```

`lib/core/config/env.dart`:

```dart
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static bool get isProd => appEnv == 'prod';
}
```

Çalıştırma: `flutter run --dart-define-from-file=env/dev.json`

> Not: dart-define değerleri uygulama paketinden okunabilir. Gerçek sırlar (servis hesabı, DB şifresi) **asla** istemciye konmaz; bunlar backend'de kalır.

## 5. main.dart ve app.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Uygulama',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
```

## 6. Router

```dart
// lib/core/router/routes.dart
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const orders = '/orders';
  static const orderDetail = 'detail/:id';        // /orders altında
  static String orderDetailPath(String id) => '/orders/detail/$id';
}
```

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/router/routes.dart';
// + ekranların importları (features/.../ui/screens/...)

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: Routes.orders,
    routes: [
      GoRoute(
        path: Routes.orders,
        builder: (context, state) => const OrdersScreen(),
        routes: [
          GoRoute(
            path: Routes.orderDetail,
            builder: (context, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
```

Navigasyon UI'da: `context.go(Routes.orders)`, `context.push(Routes.orderDetailPath(id))`.
Giriş kontrolü (redirect) gerekiyorsa `flutter-firebase` skill'indeki auth redirect desenine bak; REST auth'ta aynı desen token durumuyla uygulanır.

## 7. Tema

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF1565C0);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
  );
}
```

Renkleri widget'larda sabit yazma; `Theme.of(context).colorScheme` kullan.

## 8. Ortak hata ve yükleme widget'ları

`core/errors/app_exception.dart` için `references/app-exception.md`'deki tanımı kullan. `core/widgets/app_error_view.dart`, hatayı `AppException` ise `message` ile, değilse genel bir mesajla gösterir ve opsiyonel "Tekrar dene" butonu sunar.

## 9. Çok dil (gerekiyorsa)

`pubspec.yaml` içinde `flutter: generate: true`, kökte `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_tr.arb
output-localization-file: app_localizations.dart
```

`MaterialApp.router`'a `localizationsDelegates: AppLocalizations.localizationsDelegates` ve `supportedLocales: AppLocalizations.supportedLocales` ekle.

## 10. Sabitler ve extension'lar

`flutter-clean-code/references/constants-and-extensions.md`'deki dosyaları oluştur: `core/constants/` (spacing, radius, durations, assets) ve `core/extensions/` (context, format). İlk günden olmazlarsa gömülü değerler hızla birikir.

## 10b. Ortak widget'lar ve katalog

`flutter-ui-components/references/core-widgets.md`'deki başlangıç setini (`AppLoadingView`, `AppEmptyView`, `AppErrorView`, `AppButton`) `core/widgets/` altına kur ve `core/widgets/CATALOG.md`'yi oluştur (`catalog-format.md`).

## 10c. İnsanlar için dokümanlar

`flutter-project-docs` skill'iyle `README.md`, `docs/MIMARI.md`, `docs/YENI_EKRAN.md`, `docs/KARARLAR.md` oluştur. Projeye sonradan gelen biri bunları okuyarak başlar.

## 11. Proje CLAUDE.md

Proje kökünde `CLAUDE.md` oluştur; plugin kurulu olmayan bir ortamda bile kurallar görünür olsun:

```markdown
# <Proje adı>

Bu proje flutter-kit standartlarını kullanır (feature-first + MVVM + Riverpod 3).

## Kurallar
- Katmanlar: Screen → ViewModel → Repository → Service. Widget veri çekmez.
- Klasörler: lib/core/ (ortak), lib/features/<feature>/{data,ui}/
- Dosya ≤ 300 satır, build ≤ 60 satır, widget döndüren _buildX() metodu yok.
- Gömülü renk/padding/metin yok: tema, core/constants, l10n.
- Modeller freezed (abstract/sealed), provider'lar @riverpod codegen.
- lib/ içinde package: import.
- Yeni UI yazmadan önce lib/core/widgets/CATALOG.md'ye bak; ortak bileşen ekleyince güncelle.

## Komutlar
- Çalıştır: flutter run --dart-define-from-file=env/dev.json
- Codegen: dart run build_runner build -d
- Kontrol: dart format . && flutter analyze && flutter test

## İnsanlar için dokümanlar
- docs/MIMARI.md, docs/YENI_EKRAN.md, docs/KARARLAR.md (varsa docs/GECIS.md)
- Yapı, paket veya özellik değişince ilgili dokümanı aynı işte güncelle.

## Projeye özel notlar
- Backend: <API adresi / Firebase projesi>
- <projeye özel kararlar buraya>
```

## 12. Bitirme

```bash
dart run build_runner build -d
flutter analyze
flutter test
```

Geliştirme sırasında codegen'i açık tut: `dart run build_runner watch -d`.

Üretilen `*.g.dart` / `*.freezed.dart` dosyalarını `.gitignore`'a ekleme, **commit'le**: repo klonlanır klonlanmaz derlenir. Kullanıcı aksini tercih ederse değiştir.
