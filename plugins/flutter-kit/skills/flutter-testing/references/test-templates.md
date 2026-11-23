# Test şablonları

## Ortak mock'lar — test/helpers/mocks.dart

```dart
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

// Projedeki sınıflar
class MockOrdersService extends Mock implements OrdersService {}
class MockOrdersRepository extends Mock implements OrdersRepository {}

DioException dioError(int status, {Object? data}) {
  final req = RequestOptions(path: '/test');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: req, statusCode: status, data: data),
  );
}

DioException dioTimeout() => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionTimeout,
    );
```

## 1. Repository testi

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockOrdersService service;
  late OrdersRepository repo;

  final order = Order(
    id: '1',
    customerName: 'Ali',
    totalAmount: 100,
    createdAt: DateTime(2026),
  );

  setUp(() {
    service = MockOrdersService();
    repo = OrdersRepository(service);
  });

  group('fetchOrders', () {
    test('başarılı yanıtta siparişleri döner', () async {
      when(() => service.getOrders()).thenAnswer((_) async => [order]);

      expect(await repo.fetchOrders(), [order]);
      verify(() => service.getOrders()).called(1);
    });

    test('404 gelince NotFoundException fırlatır', () {
      when(() => service.getOrders()).thenThrow(dioError(404));

      expect(repo.fetchOrders(), throwsA(isA<NotFoundException>()));
    });

    test('timeout olunca NetworkException fırlatır', () {
      when(() => service.getOrders()).thenThrow(dioTimeout());

      expect(repo.fetchOrders(), throwsA(isA<NetworkException>()));
    });

    test('ProblemDetails mesajını kullanır', () {
      when(() => service.getOrders()).thenThrow(
        dioError(400, data: {'title': 'Tarih aralığı geçersiz'}),
      );

      expect(
        repo.fetchOrders(),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'Tarih aralığı geçersiz')),
      );
    });
  });
}
```

## 2. ViewModel testi

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockOrdersRepository repo;
  late ProviderContainer container;

  final order = Order(id: '1', customerName: 'Ali', totalAmount: 100, createdAt: DateTime(2026));

  setUp(() {
    repo = MockOrdersRepository();
    container = ProviderContainer.test(
      retry: (_, _) => null, // hata testlerinde otomatik yeniden denemeyi kapat
      overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
    );
  });

  test('build siparişleri yükler', () async {
    when(() => repo.fetchOrders()).thenAnswer((_) async => [order]);

    final result = await container.read(ordersViewModelProvider.future);

    expect(result, [order]);
  });

  test('build hata verirse AsyncError olur', () async {
    when(() => repo.fetchOrders()).thenThrow(const NetworkException());

    // Provider'ı canlı tut ve sonucu bekle
    final sub = container.listen(ordersViewModelProvider, (_, _) {});
    await expectLater(
      container.read(ordersViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );
    expect(sub.read(), isA<AsyncError<List<Order>>>());
  });

  test('delete sonrası kayıt listeden çıkar', () async {
    when(() => repo.fetchOrders()).thenAnswer((_) async => [order]);
    when(() => repo.deleteOrder('1')).thenAnswer((_) async {});

    final sub = container.listen(ordersViewModelProvider, (_, _) {});
    await container.read(ordersViewModelProvider.future);

    await container.read(ordersViewModelProvider.notifier).delete('1');

    expect(sub.read().value, isEmpty);
    verify(() => repo.deleteOrder('1')).called(1);
  });

  test('delete başarısız olursa liste korunur', () async {
    when(() => repo.fetchOrders()).thenAnswer((_) async => [order]);
    when(() => repo.deleteOrder('1')).thenThrow(const NetworkException());

    final sub = container.listen(ordersViewModelProvider, (_, _) {});
    await container.read(ordersViewModelProvider.future);

    await expectLater(
      container.read(ordersViewModelProvider.notifier).delete('1'),
      throwsA(isA<NetworkException>()),
    );
    expect(sub.read().value, [order]);
  });
}
```

> `ProviderContainer.test` sürümünüzde `retry` parametresini kabul etmiyorsa: `container = ProviderContainer(retry: (_, _) => null, overrides: [...]); addTearDown(container.dispose);`

## 3. Widget testi

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockOrdersRepository repo;

  setUp(() => repo = MockOrdersRepository());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );

  testWidgets('siparişleri listeler', (tester) async {
    when(() => repo.fetchOrders()).thenAnswer((_) async => [
          Order(id: '1', customerName: 'Ali', totalAmount: 100, createdAt: DateTime(2026)),
        ]);

    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('boş listede mesaj gösterir', (tester) async {
    when(() => repo.fetchOrders()).thenAnswer((_) async => []);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Henüz sipariş yok'), findsOneWidget);
  });

  testWidgets('hatada mesaj ve tekrar dene butonu gösterir', (tester) async {
    when(() => repo.fetchOrders()).thenThrow(const NetworkException());

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('İnternet bağlantınızı kontrol edin.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
```

Ekran `go_router` kullanıyorsa (`context.push`) ve test navigasyonu içeriyorsa `MaterialApp.router` + test için küçük bir `GoRouter` kur; navigasyon yoksa `MaterialApp(home: ...)` yeterli.

## 4. Firestore repository testi (fake)

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('watchMine sadece kullanıcının kayıtlarını döner', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('assessments').add({'title': 'A', 'ownerId': 'u1', 'score': 0});
    await db.collection('assessments').add({'title': 'B', 'ownerId': 'u2', 'score': 0});

    final container = ProviderContainer.test(
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    final repo = container.read(assessmentsRepositoryProvider);

    final list = await repo.watchMine('u1').first;
    expect(list.map((a) => a.title), ['A']);
  });
}
```

> `fake_cloud_firestore` güvenlik kurallarını uygulamaz; kurallar emulator'de test edilir. `orderBy('createdAt')` kullanan sorgularda test verisine `createdAt` alanı ekle.

## 5. Auth (firebase_auth_mocks)

```dart
final auth = MockFirebaseAuth(
  signedIn: true,
  mockUser: MockUser(uid: 'u1', email: 'test@example.com'),
);
final container = ProviderContainer.test(
  overrides: [firebaseAuthProvider.overrideWithValue(auth)],
);
```
