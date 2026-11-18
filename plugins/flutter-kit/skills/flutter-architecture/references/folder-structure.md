# Klasör yapısı ve isimlendirme

## Tam örnek (orders feature'lı bir uygulama)

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   │   └── env.dart                     # String.fromEnvironment sabitleri
│   ├── errors/
│   │   └── app_exception.dart           # sealed AppException hiyerarşisi
│   ├── network/
│   │   ├── dio_provider.dart            # @Riverpod(keepAlive: true) Dio
│   │   ├── dio_exception_mapper.dart    # DioException → AppException
│   │   └── interceptors/
│   │       └── auth_interceptor.dart
│   ├── router/
│   │   ├── app_router.dart              # @Riverpod(keepAlive: true) GoRouter
│   │   └── routes.dart                  # rota isim/path sabitleri
│   ├── theme/
│   │   └── app_theme.dart
│   ├── utils/
│   └── widgets/
│       ├── app_error_view.dart
│       └── app_loading_view.dart
└── features/
    ├── auth/
    │   ├── data/ ...
    │   └── ui/ ...
    └── orders/
        ├── data/
        │   ├── models/
        │   │   └── order.dart           # + order.freezed.dart, order.g.dart
        │   ├── services/
        │   │   └── orders_service.dart
        │   └── repositories/
        │       └── orders_repository.dart
        └── ui/
            ├── view_models/
            │   ├── orders_view_model.dart
            │   └── order_detail_view_model.dart
            ├── screens/
            │   ├── orders_screen.dart
            │   └── order_detail_screen.dart
            └── widgets/
                └── order_tile.dart

test/
├── features/orders/data/repositories/orders_repository_test.dart
├── features/orders/ui/view_models/orders_view_model_test.dart
├── features/orders/ui/screens/orders_screen_test.dart
└── helpers/                              # ortak mock'lar, pump yardımcıları

env/
├── dev.json                              # .gitignore'da
├── prod.json                             # .gitignore'da
└── example.json                          # commit'lenir, şablon
```

## Feature nedir?

Bir feature, kullanıcının gördüğü bir iş alanıdır: `auth`, `orders`, `products`, `profile`, `settings`. Teknik katman (`api`, `widgets`) feature değildir. Bir ekran grubu ayrı bir veri kaynağı veya model seti kullanıyorsa ayrı feature olur.

## Paylaşılan model

İki feature aynı modeli kullanıyorsa modeli sahibi olan feature'da bırak, diğeri onun `data/` katmanını import edebilir (`ui/` katmanını edemez). Üç veya daha fazla feature kullanıyorsa `core/models/`'a taşı.

## İsimlendirme

| Tür | Dosya | Sınıf | Provider (codegen sonucu) |
|---|---|---|---|
| Model | `order.dart` | `Order` | — |
| Service | `orders_service.dart` | `OrdersService` | `ordersServiceProvider` |
| Repository | `orders_repository.dart` | `OrdersRepository` | `ordersRepositoryProvider` |
| ViewModel | `orders_view_model.dart` | `OrdersViewModel` | `ordersViewModelProvider` |
| Screen | `orders_screen.dart` | `OrdersScreen` | — |
| Widget | `order_tile.dart` | `OrderTile` | — |

- Dosya adları `snake_case`, sınıflar `PascalCase`.
- Her dosyada bir public sınıf (küçük private yardımcı widget'lar hariç).
- Provider'ı, bağlı olduğu sınıfla **aynı dosyada** tanımla (ör. `ordersRepositoryProvider` → `orders_repository.dart`).
- Bir ekran için bir ViewModel. ViewModel'in adı ekranla eşleşir: `OrdersScreen` ↔ `OrdersViewModel`.

## Repository için arayüz gerekli mi?

Hayır, varsayılan olarak somut sınıf yaz. Testte `mocktail` somut sınıfı `implements` ile mock'layabilir. Arayüz (abstract class) sadece aynı repository'nin gerçekten iki farklı uygulaması varsa (ör. online/offline) aç.

## DTO ile model ayrı mı olmalı?

Başlangıçta **tek freezed model** (`fromJson`'lu) kullan. Backend'in JSON şekli uygulamanın ihtiyacından belirgin şekilde farklılaşırsa (alan adları, iç içe yapı, birden çok endpoint'ten birleşme) `data/models/` altında `order_dto.dart` aç ve dönüşümü repository'de yap.
