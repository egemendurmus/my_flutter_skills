// expect: freezed sınıfı 'abstract class' veya 'sealed class' olmalı
import 'package:freezed_annotation/freezed_annotation.dart';

@freezed
class CartItem with _$CartItem {}

@freezed
abstract class CartLine with _$CartLine {}
