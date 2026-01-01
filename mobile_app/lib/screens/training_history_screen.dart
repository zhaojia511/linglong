import 'package:flutter/material.dart';

class TrainingHistoryScreen extends StatelessWidget {
  const TrainingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training History'),
      ),
      body: const Center(
        child: Text('Training History Screen'),
      ),
    );
  }
}
