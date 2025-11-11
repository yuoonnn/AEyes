import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_state.dart';
import '../widgets/main_scaffold.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIState>();
    final latest = ai.lastAnalysis;
    final history = ai.history;

    return MainScaffold(
      currentIndex: 1, // will be mapped in MainScaffold
      child: Scaffold(
        appBar: AppBar(title: const Text('AI Analysis')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Latest', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(latest ?? 'Waiting for image...'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text('No past analyses yet.')
            else
              ...history.map((item) {
                final text = item['text'] as String? ?? '';
                final at = item['at'] as DateTime?;
                final when = at != null ? at.toLocal().toString().split('.').first : '';
                return Card(
                  child: ListTile(
                    title: Text(text),
                    subtitle: when.isNotEmpty ? Text(when) : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


