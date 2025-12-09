
import 'package:flutter/material.dart';

import '../widgets/groups_widget.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: const GroupsWidget(),
    );
  }
}
