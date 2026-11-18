# Önce / sonra örnekleri

## 1. Spagetti ekran

### Önce (yapma)

```dart
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() async {
    try {
      final res = await Dio().get('https://api.eliar.com/orders');   // ağ çağrısı widget'ta
      setState(() { data = res.data; loading = false; });
    } catch (e) {}                                                     // boş catch
  }

  Widget _buildItem(dynamic o) {                                       // widget döndüren metot
    final d = DateTime.parse(o['created_at']);
    return Container(
      padding: const EdgeInsets.all(13),                               // gömülü değer
      color: o['status'] == 'cancelled' ? Color(0xFFFFCDD2) : Colors.white,
      child: Row(children: [
        Text(o['customer_name'], style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        Spacer(),
        Text('${d.day}.${d.month}.${d.year}'),                         // build'de formatlama
        Text('${(o['total'] as num).toStringAsFixed(2)} TL'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    final filtered = data.where((o) => o['status'] != 'deleted').toList(); // build'de filtre
    filtered.sort((a, b) => b['created_at'].compareTo(a['created_at']));
    return Scaffold(
      appBar: AppBar(title: Text('Siparişler')),
      body: ListView(children: filtered.map(_buildItem).toList()),
    );
  }
}
```

Sorunlar: ağ çağrısı UI'da, `dynamic` JSON UI'a kadar geliyor, hata yutuluyor, hata/boş durumu yok, filtre+sıralama `build`'de, formatlama `build`'de, gömülü renk/padding/font, widget döndüren metot, URL koda gömülü.

### Sonra

Aynı ekran 6 küçük dosyaya ayrılır:

```
features/orders/
├── data/models/order.dart                     # freezed, OrderStatus enum
├── data/services/orders_service.dart          # Dio çağrısı
├── data/repositories/orders_repository.dart   # hata çevirme, filtre/sıralama
├── ui/view_models/orders_view_model.dart      # AsyncNotifier
├── ui/screens/orders_screen.dart              # sadece iskelet
└── ui/widgets/order_tile.dart                 # tek satırın görünümü
```

Repository — iş kuralı (silinenleri çıkar, yeniden eskiye sırala) veri katmanında:

```dart
Future<List<Order>> fetchOrders() => _guard(() async {
      final orders = await _service.getOrders();
      return orders
          .where((order) => order.status != OrderStatus.deleted)
          .sortedBy((order) => order.createdAt)   // package:collection
          .reversed
          .toList();
    });
```

Ekran — sadece hangi durumda ne gösterileceği:

```dart
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ordersTitle)),
      body: switch (orders) {
        AsyncData(:final value) when value.isEmpty =>
          AppEmptyView(message: context.l10n.ordersEmpty),
        AsyncData(:final value) => _OrderList(orders: value),
        AsyncError(:final error) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(ordersViewModelProvider),
          ),
        _ => const AppLoadingView(),
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: AppSpacing.page,
        itemCount: orders.length,
        separatorBuilder: (_, _) => AppGap.sm,
        itemBuilder: (_, index) => OrderTile(order: orders[index]),
      );
}
```

Tek satır — görünüm, tema ve extension'larla:

```dart
class OrderTile extends StatelessWidget {
  const OrderTile({required this.order, super.key, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: order.isCancelled ? context.colors.errorContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(order.customerName, style: context.textTheme.titleMedium),
        subtitle: Text(order.createdAt.shortDate),
        trailing: Text(order.totalAmount.asTry),
      ),
    );
  }
}
```

`isCancelled` modelde getter (freezed'de `const Order._();` private constructor ekleyerek):

```dart
bool get isCancelled => status == OrderStatus.cancelled;
```

## 2. Widget döndüren metot → sınıf

```dart
// Önce
Widget _buildHeader() => Padding(padding: ..., child: Row(...));

// Sonra
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: AppSpacing.page,
        child: Text(title, style: context.textTheme.headlineSmall),
      );
}
```

Başka dosyada da kullanılacaksa `widgets/` altına public olarak taşı.

## 3. Derin iç içe if → guard clause

```dart
// Önce
Future<void> submit() async {
  if (state.email.isNotEmpty) {
    if (state.password.length >= 6) {
      if (!state.isSubmitting) {
        // ... asıl iş
      }
    }
  }
}

// Sonra
Future<void> submit() async {
  if (state.isSubmitting) return;
  if (state.email.isEmpty) return _fail('E-posta gerekli');
  if (state.password.length < 6) return _fail('Şifre en az 6 karakter');
  // ... asıl iş
}
```

## 4. Uzun parametre listesi → nesne

```dart
// Önce
Future<List<Order>> search(String q, DateTime? from, DateTime? to,
    OrderStatus? status, int page, int pageSize, String sort) { ... }

// Sonra
@freezed
abstract class OrderQuery with _$OrderQuery {
  const factory OrderQuery({
    String? text,
    DateTime? from,
    DateTime? to,
    OrderStatus? status,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _OrderQuery;
}

Future<List<Order>> search(OrderQuery query) { ... }
```

`OrderQuery` freezed olduğu için `==` doğru çalışır ve family provider parametresi olarak kullanılabilir: `ref.watch(orderSearchProvider(query))`.
