// expect: widget döndüren metot (_buildHeader())
import 'package:flutter/material.dart';

class CartTile extends StatelessWidget {
  const CartTile({super.key});

  @override
  Widget build(BuildContext context) => _buildHeader();

  Widget _buildHeader() => const SizedBox();
}
