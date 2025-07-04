// feedback_panel.dart
import 'package:flutter/material.dart';

class FeedbackPanel extends StatelessWidget {
  final Map<String, dynamic>? results;

  const FeedbackPanel({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results == null || results!['feedback'] == null) {
      return const SizedBox.shrink();
    }

    // Handle both String and List<String> feedback
    final feedbackList = results!['feedback'] is String
        ? [results!['feedback'] as String]
        : results!['feedback'] as List<dynamic>;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: results!['isCorrectForm'] == true
                ? Colors.green
                : Colors.orange,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  results!['isCorrectForm'] == true
                      ? Icons.check_circle
                      : Icons.warning,
                  color: results!['isCorrectForm'] == true
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  results!['isCorrectForm'] == true
                      ? 'Good Form!'
                      : 'Form Correction Needed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...feedbackList
                .map<Widget>(
                  (feedback) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white)),
                        Expanded(
                          child: Text(
                            feedback.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }
}
