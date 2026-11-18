# Sık kullanılan API desenleri

## Sayfalama (sonsuz kaydırma)

Sayfalı yanıt modeli:

```dart
@Freezed(genericArgumentFactories: true)
abstract class Paged<T> with _$Paged<T> {
  const factory Paged({
    required List<T> items,
    required int page,
    required int totalPages,
  }) = _Paged<T>;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$PagedFromJson(json, fromJsonT);
}
```

Service:

```dart
Future<Paged<Order>> getOrdersPage(int page, {int pageSize = 20}) async {
  final res = await _dio.get<Map<String, dynamic>>(
    '/orders',
    queryParameters: {'page': page, 'pageSize': pageSize},
  );
  return Paged.fromJson(
    res.data!,
    (e) => Order.fromJson(e! as Map<String, dynamic>),
  );
}
```

ViewModel — biriken liste + "daha fazla" durumu:

```dart
@freezed
abstract class OrdersPageState with _$OrdersPageState {
  const factory OrdersPageState({
    @Default([]) List<Order> items,
    @Default(1) int page,
    @Default(true) bool hasMore,
    @Default(false) bool isLoadingMore,
  }) = _OrdersPageState;
}

@riverpod
class PagedOrdersViewModel extends _$PagedOrdersViewModel {
  @override
  Future<OrdersPageState> build() async {
    final first = await ref.watch(ordersRepositoryProvider).fetchOrdersPage(1);
    return OrdersPageState(
      items: first.items,
      hasMore: first.page < first.totalPages,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(ordersRepositoryProvider)
          .fetchOrdersPage(current.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.page < next.totalPages,
        isLoadingMore: false,
      ));
    } on AppException {
      if (!ref.mounted) return;
      // Liste kaybolmasın: mevcut veriyi koru, sadece yüklemeyi kapat.
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }
}
```

UI'da `ListView.builder` son elemana yaklaşınca (`index >= items.length - 3`) `loadMore()` çağırır; `isLoadingMore` iken listenin sonunda küçük bir loader gösterir.

## Arama (debounce + iptal)

```dart
@riverpod
Future<List<Product>> productSearch(Ref ref, String query) async {
  if (query.trim().length < 2) return [];

  // Debounce: kullanıcı yazmaya devam ederse bu provider dispose olur.
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (disposed) throw StateError('cancelled');

  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return ref.watch(productsRepositoryProvider).search(query, cancelToken: cancelToken);
}
```

Service metodu `cancelToken`'ı `_dio.get(..., cancelToken: cancelToken)`'a geçirir.

## Dosya yükleme (multipart + ilerleme)

```dart
Future<String> uploadFile(String path, {void Function(double)? onProgress}) async {
  final form = FormData.fromMap({
    'file': await MultipartFile.fromFile(path, filename: path.split('/').last),
  });
  final res = await _dio.post<Map<String, dynamic>>(
    '/files',
    data: form,
    onSendProgress: (sent, total) {
      if (total > 0) onProgress?.call(sent / total);
    },
  );
  return res.data!['url'] as String;
}
```

## Basit önbellek (aynı veri ekranlar arası paylaşılsın)

Riverpod provider'ları zaten önbellektir. Kısa süre canlı tutmak için:

```dart
@riverpod
Future<List<Category>> categories(Ref ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(catalogRepositoryProvider).fetchCategories();
}
```

Çevrimdışı çalışma gerekiyorsa (veri cihazda kalıcı olmalı) kullanıcıyla netleştir; `drift` (SQLite) ile repository içinde "önce lokal, sonra ağ" deseni kurulur.

## Tarih/saat

- Backend ISO 8601 UTC göndermeli; `DateTime.parse` ile oku, gösterirken `.toLocal()` ve `intl` `DateFormat` kullan.
- Backend `/Date(...)/` veya özel format gönderiyorsa modelde `JsonConverter<DateTime, String>` yaz.

## Para / ondalık

- Tutarları `double` ile hesaplama yapma (yuvarlama hatası). Sadece gösterilecekse `double` + `NumberFormat.currency(locale: 'tr_TR', symbol: '₺')` yeterli; hesap yapılacaksa backend'den kuruş (int) veya string iste.
