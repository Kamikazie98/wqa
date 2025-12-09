
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/productivity_controller.dart';
import '../widgets/goal_suggestion_card.dart';

class ProductivityScreen extends StatelessWidget {
  const ProductivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity'),
      ),
      body: Consumer<ProductivityController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.goalSuggestions.isEmpty) {
            return const Center(child: Text('No goal suggestions available.'));
          }

          return ListView.builder(
            itemCount: controller.goalSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = controller.goalSuggestions[index];
              return GoalSuggestionCard(suggestion: suggestion);
            },
          );
        },
      ),
    );
  }
}
