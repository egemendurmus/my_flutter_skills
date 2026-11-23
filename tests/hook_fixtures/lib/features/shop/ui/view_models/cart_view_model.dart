// expect: clean
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_view_model.g.dart';

@riverpod
class CartViewModel extends _$CartViewModel {
  @override
  int build() => 0;
}
