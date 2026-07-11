import 'package:flutter/material.dart';

/// Shows a lightweight "Coming Soon" dialog for a feature that isn't built
/// yet, instead of silently doing nothing when the user taps it.
void showComingSoon(BuildContext context, {required String feature, String? detail}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.rocket_launch_outlined, color: Color(0xFF3D6BFF), size: 32),
      title: Text(feature),
      content: Text(
        detail ?? 'This feature is coming soon. We\'re still building it out!',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// A full placeholder screen for a nav destination that isn't built yet.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String? detail;

  const ComingSoonScreen({super.key, required this.title, this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch_outlined, size: 64, color: Color(0xFF3D6BFF)),
              const SizedBox(height: 16),
              const Text(
                'Coming Soon',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                detail ?? '$title is still being built. Check back soon!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
