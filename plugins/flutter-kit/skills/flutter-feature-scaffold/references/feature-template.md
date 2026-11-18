# Feature şablonu: `orders` (REST API)

> Örneklerde kullanıcı metinleri (`'Siparişler'` vb.) kısalık için doğrudan yazıldı. Gerçek kodda `flutter-clean-code` §3'e göre `context.l10n` / `AppStrings` kullan.

`orders`/`Order` adlarını yeni feature'a göre değiştir. Firestore kullanılıyorsa Service ve Repository için `flutter-firebase` skill'indeki desenleri kullan; ViewModel ve ekran aynı kalır.

## 1. Model — `data/models/order.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

enum OrderStatus { pending, shipped, delivered, cancelled }

@freezed
abstract class Order with _$Order {
  const factory Order({
    required String id,
    required String customerName,
    required double totalAmount,
    @JsonKey(unknownEnumValue: OrderStatus.pending)
    @Default(OrderStatus.pending)
    OrderStatus status,
    required DateTime createdAt,
    String? note,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}
```

Backend `snake_case` gönderiyorsa her alana `@JsonKey(name: ...)` yazmak yerine kökte `build.yaml`:

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          field_rename: snake
```

## 2. Service — `data/services/orders_service.dart`

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/network/dio_provider.dart';
import 'package:my_app/features/orders/data/models/order.dart';

part 'orders_service.g.dart';

class OrdersService {
  OrdersService(this._dio);
  final Dio _dio;

  Future<List<Order>> getOrders() async {
    final res = await _dio.get<List<dynamic>>('/orders');
    return res.data!
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> getOrder(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/orders/$id');
    return Order.fromJson(res.data!);
  }

  Future<void> deleteOrder(String id) => _dio.delete<void>('/orders/$id');
}

@riverpod
OrdersService ordersService(Ref ref) => OrdersService(ref.watch(dioProvider));
```

## 3. Repository — `data/repositories/orders_repository.dart`

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/network/dio_exception_mapper.dart';
import 'package:my_app/features/orders/data/models/order.dart';
import 'package:my_app/features/orders/data/services/orders_service.dart';

part 'orders_repository.g.dart';

class OrdersRepository {
  OrdersRepository(this._service);
  final OrdersService _service;

  Future<List<Order>> fetchOrders() => _guard(_service.getOrders);

  Future<Order> fetchOrder(String id) => _guard(() => _service.getOrder(id));

  Future<void> deleteOrder(String id) => _guard(() => _service.deleteOrder(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

@riverpod
OrdersRepository ordersRepository(Ref ref) =>
    OrdersRepository(ref.watch(ordersServiceProvider));
```

## 4a. Liste ViewModel — `ui/view_models/orders_view_model.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/features/orders/data/models/order.dart';
import 'package:my_app/features/orders/data/repositories/orders_repository.dart';

part 'orders_view_model.g.dart';

@riverpod
class OrdersViewModel extends _$OrdersViewModel {
  @override
  Future<List<Order>> build() =>
      ref.watch(ordersRepositoryProvider).fetchOrders();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(ordersRepositoryProvider).fetchOrders(),
    );
  }

  /// Hata olursa liste ekranda kalır; AppException fırlatılır, UI SnackBar gösterir.
  Future<void> delete(String id) async {
    await ref.read(ordersRepositoryProvider).deleteOrder(id);
    if (!ref.mounted) return;
    final current = state.value ?? const <Order>[];
    state = AsyncData(current.where((order) => order.id != id).toList());
  }
}
```

UI'da silme çağrısı:

```dart
Future<void> _onDelete(BuildContext context, WidgetRef ref, String id) async {
  try {
    await ref.read(ordersViewModelProvider.notifier).delete(id);
  } on AppException catch (e) {
    if (context.mounted) context.showSnack(e.message);
  }
}
```

## 4b. Detay ViewModel (family) — `ui/view_models/order_detail_view_model.dart`

```dart
@riverpod
class OrderDetailViewModel extends _$OrderDetailViewModel {
  @override
  Future<Order> build(String orderId) =>
      ref.watch(ordersRepositoryProvider).fetchOrder(orderId);
}
// Kullanım: ref.watch(orderDetailViewModelProvider(orderId))
```

## 5. Ekran — `ui/screens/orders_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_app/core/router/routes.dart';
import 'package:my_app/core/widgets/app_error_view.dart';
import 'package:my_app/core/widgets/app_loading_view.dart';
import 'package:my_app/features/orders/ui/view_models/orders_view_model.dart';
import 'package:my_app/features/orders/ui/widgets/order_tile.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersViewModelProvider);
    final vm = ref.read(ordersViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Siparişler')),
      body: switch (orders) {
        AsyncData(:final value) when value.isEmpty =>
          const Center(child: Text('Henüz sipariş yok')),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView.separated(
              itemCount: value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => OrderTile(
                order: value[i],
                onTap: () => context.push(Routes.orderDetailPath(value[i].id)),
              ),
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

> `(_, _)` wildcard sözdizimi Dart 3.7+ ister. Proje daha eski SDK'daysa `(_, __)` kullan.

## 6. Rota

`routes.dart`'a sabitleri, `app_router.dart`'a `GoRoute`'u ekle (bkz. `flutter-architecture/references/project-setup.md` §6).

## 7. Testler

`flutter-testing` skill'indeki şablonlarla:
- `test/features/orders/data/repositories/orders_repository_test.dart`
- `test/features/orders/ui/view_models/orders_view_model_test.dart`
