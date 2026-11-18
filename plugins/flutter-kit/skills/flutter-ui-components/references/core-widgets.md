# Başlangıç ortak bileşen seti

Yeni projede `core/widgets/` altına bunlar kurulur. Hepsi sadece tema, `AppSpacing`/`AppRadius` ve parametre kullanır; provider veya iş mantığı içermez. Import'larda `my_app` yerine proje adını yaz.

## app_loading_view.dart

```dart
import 'package:flutter/material.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
```

## app_empty_view.dart

```dart
import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_spacing.dart';
import 'package:my_app/core/extensions/context_extensions.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Icon(icon, size: 48, color: context.colors.outline),
            Text(message, textAlign: TextAlign.center, style: context.textTheme.bodyLarge),
            if (actionLabel != null && onAction != null)
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
```

## app_error_view.dart

```dart
import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_spacing.dart';
import 'package:my_app/core/errors/app_exception.dart';
import 'package:my_app/core/extensions/context_extensions.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.error, super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            Text(messageOf(error), textAlign: TextAlign.center),
            if (onRetry != null)
              OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
```

## app_button.dart (varyant enum'u örneği)

```dart
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final child = isLoading
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);

    return switch (variant) {
      AppButtonVariant.primary => icon == null
          ? FilledButton(onPressed: callback, child: child)
          : FilledButton.icon(onPressed: callback, icon: Icon(icon), label: child),
      AppButtonVariant.secondary => icon == null
          ? OutlinedButton(onPressed: callback, child: child)
          : OutlinedButton.icon(onPressed: callback, icon: Icon(icon), label: child),
      AppButtonVariant.text => TextButton(onPressed: callback, child: child),
    };
  }
}
```

## status_badge.dart (ton enum'u örneği)

```dart
import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_spacing.dart';
import 'package:my_app/core/extensions/context_extensions.dart';

enum StatusTone { success, warning, danger, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      StatusTone.success => (colors.primaryContainer, colors.onPrimaryContainer),
      StatusTone.warning => (colors.tertiaryContainer, colors.onTertiaryContainer),
      StatusTone.danger => (colors.errorContainer, colors.onErrorContainer),
      StatusTone.neutral => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Text(label, style: context.textTheme.labelSmall?.copyWith(color: foreground)),
      ),
    );
  }
}
```

> Marka renkleri (ör. kurumsal "başarı yeşili") `ColorScheme`'de yoksa `ThemeExtension<AppColors>` ile temaya eklenir ve `context.appColors.success` şeklinde okunur — widget'a hex yazılmaz.

## AppCard, AppTextField, SectionHeader

Aynı kurallarla: `AppCard` = `Card` + `InkWell` + `AppSpacing.card`; `AppTextField` = `TextFormField` + `label`/`hint`/`validator`/`controller` (dekorasyon `InputDecorationTheme`'den); `SectionHeader` = başlık + opsiyonel "Tümünü gör" `TextButton`. Gerektiğinde yaz, hepsini baştan zorunlu kurma.
