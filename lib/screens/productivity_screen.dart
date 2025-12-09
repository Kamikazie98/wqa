
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../controllers/productivity_controller.dart';

class ProductivityScreen extends StatelessWidget {
  const ProductivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: Consumer<ProductivityController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (controller.goalSuggestions.isEmpty) {
            return Center(child: Text(l10n.noGoalSuggestions));
          } else {
            return ListView.builder(
              itemCount: controller.goalSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = controller.goalSuggestions[index];
                return ListTile(
                  title: Text(suggestion.title),
                  subtitle: Text(suggestion.description),
                );
              },
            );
          }
        },
      ),
    );
  }
}
