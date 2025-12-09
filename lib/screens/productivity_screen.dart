
import 'package:flutter/material.dart';

import '../widgets/productivity_widget.dart';

class ProductivityScreen extends StatelessWidget {
  const ProductivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity'),
      ),
      body: const ProductivityWidget(),
    );
  }
}
