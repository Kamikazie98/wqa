import 'package:flutter/material.dart';

class PrimaryScaffold extends StatelessWidget {
  const PrimaryScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context)
                  .colorScheme
                  .primary
                  .withAlpha((0.08 * 255).round()),
              Theme.of(context)
                  .colorScheme
                  .secondary
                  .withAlpha((0.06 * 255).round()),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
