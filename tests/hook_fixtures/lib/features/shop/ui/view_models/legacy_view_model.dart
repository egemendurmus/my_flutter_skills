// expect: Riverpod legacy API
import 'package:flutter_riverpod/legacy.dart';

final counter = StateProvider<int>((ref) => 0);
// Yanlış alarm olmamalı: isim içinde geçen kelime
final myStateProviderHelper = 1;
