// expect: 2 yerde gömülü renk
// expect: 1 yerde sayı ile padding
// expect: 1 yerde sabit fontSize
import 'package:flutter/material.dart';

final a = Container(color: const Color(0xFF112233));
final b = Padding(padding: const EdgeInsets.all(8), child: Text('x', style: TextStyle(fontSize: 14, color: Colors.red)));
