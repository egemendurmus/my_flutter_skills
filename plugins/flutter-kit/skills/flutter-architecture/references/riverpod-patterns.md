# Riverpod 3 desenleri (codegen)

> Örneklerde kullanıcı metinleri (`'Siparişler'` vb.) kısalık için doğrudan yazıldı. Gerçek kodda `flutter-clean-code` §3'e göre `context.l10n` / `AppStrings` kullan.

Her dosyada codegen için `part` satırı gerekir:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_repository.g.dart';
```

## 1. Bağımlılık sağlayan provider (Service / Repository)

```dart
@riverpod
OrdersRepository ordersRepository(Ref ref) {
  return OrdersRepository(ref.watch(ordersServiceProvider));
}
```

Uygulama ömrü boyunca tek örnek olması gerekenler:

```dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) { ... }
```

## 2. Basit okuma: FutureProvider / StreamProvider

Ekranın sadece veriyi göstermesi, aksiyon olmaması durumunda:

```dart
@riverpod
Future<Order> orderDetail(Ref ref, String orderId) {
  return ref.watch(ordersRepositoryProvider).fetchOrder(orderId);
}
// Kullanım: ref.watch(orderDetailProvider(orderId))
```

## 3. ViewModel: AsyncNotifier (veri + aksiyonlar)

```dart
@riverpod
class OrdersViewModel extends _$OrdersViewModel {
  @override
  Future<List<Order>> build() {
    return ref.watch(ordersRepositoryProvider).fetchOrders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ordersRepositoryProvider).fetchOrders(),
    );
  }

  Future<void> deleteOrder(String id) async {
    final repo = ref.read(ordersRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.deleteOrder(id);
      return repo.fetchOrders();
    });
  }
}
```

Kurallar:
- `build()` içinde `ref.watch`, metodlarda `ref.read`.
- `state = AsyncLoading()` sadece tam yeniden yüklemede; liste üzerinde küçük güncelleme yapılırken mevcut veriyi korumak için doğrudan `AsyncValue.guard` kullan.
- Uzun `await` sonrası state yazmadan önce `if (!ref.mounted) return;`.

## 4. Form / senkron UI state: Notifier + freezed state

```dart
@freezed
abstract class LoginFormState with _$LoginFormState {
  const factory LoginFormState({
    @Default('') String email,
    @Default('') String password,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _LoginFormState;
}

@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  LoginFormState build() => const LoginFormState();

  void setEmail(String v) => state = state.copyWith(email: v, errorMessage: null);
  void setPassword(String v) => state = state.copyWith(password: v, errorMessage: null);

  /// Başarılıysa true döner; navigasyonu UI yapar.
  Future<bool> submit() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).signIn(state.email, state.password);
      return true;
    } on AppException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.message);
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSubmitting: false);
    }
  }
}
```

## 5. UI tarafı

```dart
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Siparişler')),
      body: switch (orders) {
        AsyncData(:final value) when value.isEmpty =>
          const Center(child: Text('Sipariş yok')),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.read(ordersViewModelProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: value.length,
              itemBuilder: (_, i) => OrderTile(order: value[i]),
            ),
          ),
        AsyncError(:final error) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(ordersViewModelProvider),
          ),
        _ => const AppLoadingView(),
      },
    );
  }
}
```

Tek seferlik olaylar (SnackBar, navigasyon) için `ref.listen`:

```dart
ref.listen(ordersViewModelProvider, (prev, next) {
  if (next is AsyncError && prev is! AsyncError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messageOf(next.error))),
    );
  }
});
```

## 6. Riverpod 3 notları

- `AsyncValue` sealed: `switch` ile tüm durumları ele al.
- `.value` artık nullable (veri yoksa `null`); kesin veri gerekiyorsa `.requireValue`.
- Başarısız provider'lar varsayılan olarak **otomatik yeniden denenir**. Bir provider için kapatmak: `@Riverpod(retry: noRetry)` ile `Duration? noRetry(int retryCount, Object error) => null;`.
- Ref alt tipleri (`OrdersRepositoryRef` vb.) yok; her yerde `Ref`.
- Legacy API'ler (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`) `package:flutter_riverpod/legacy.dart` altına taşındı — yeni kodda kullanma.
- Deneysel özellikler (offline persistence, mutations) stabil değil; kullanıcı istemedikçe kullanma.
