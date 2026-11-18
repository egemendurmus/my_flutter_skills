# Sabitler ve extension'lar (her yeni projede oluştur)

## core/constants/app_spacing.dart

```dart
import 'package:flutter/widgets.dart';

/// 4'ün katları ile boşluk ölçeği.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets page = EdgeInsets.all(md);
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets listItem =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);
}

/// Column/Row içinde boşluk: `AppGap.md`.
/// Kare SizedBox olduğu için hem Column hem Row'da çalışır.
abstract final class AppGap {
  static const xs = SizedBox.square(dimension: AppSpacing.xs);
  static const sm = SizedBox.square(dimension: AppSpacing.sm);
  static const md = SizedBox.square(dimension: AppSpacing.md);
  static const lg = SizedBox.square(dimension: AppSpacing.lg);
  static const xl = SizedBox.square(dimension: AppSpacing.xl);
}
```

> Not: Column/Row'da `spacing:` parametresi (Flutter 3.27+) tek tip boşluk için daha da temizdir: `Column(spacing: AppSpacing.sm, children: [...])`.

## core/constants/app_radius.dart ve app_durations.dart

```dart
import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const debounce = Duration(milliseconds: 350);
}
```

## core/constants/app_assets.dart

```dart
abstract final class AppAssets {
  static const logo = 'assets/images/logo.png';
  static const emptyBox = 'assets/images/empty_box.svg';
}
```

## core/extensions/context_extensions.dart

```dart
import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);

  void showSnack(String message) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
```

Çok dilli projede ek olarak:

```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
```

## core/extensions/format_extensions.dart

Formatlama `build` içinde değil, burada:

```dart
import 'package:intl/intl.dart';

extension DateTimeFormatX on DateTime {
  String get shortDate => DateFormat('dd.MM.yyyy', 'tr_TR').format(toLocal());
  String get dateTime => DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(toLocal());
}

extension MoneyFormatX on num {
  String get asTry =>
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2)
          .format(this);
}
```

> `tr_TR` tarih formatı için uygulama başında `await initializeDateFormatting('tr_TR');` (`package:intl/date_symbol_data_local.dart`) çağrılmalı; `flutter_localizations` kullanılıyorsa gerekmez.

Kullanım: `Text(order.createdAt.shortDate)`, `Text(order.totalAmount.asTry)`.

## Klasör yapısına ekleme

```
lib/core/
├── constants/
│   ├── app_spacing.dart
│   ├── app_radius.dart
│   ├── app_durations.dart
│   └── app_assets.dart
└── extensions/
    ├── context_extensions.dart
    └── format_extensions.dart
```
