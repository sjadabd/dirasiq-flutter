import 'package:flutter/material.dart';
import 'teacher_app_bar.dart';
import 'teacher_drawer.dart';

/// Shared placeholder for teacher tabs that haven't been built yet.
///
/// No logout button — the only place to log out is the profile screen,
/// reached by tapping the avatar in the app bar.
class TeacherPlaceholder extends StatelessWidget {
  const TeacherPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: TeacherAppBar(title: title, subtitle: subtitle),
      drawer: const TeacherDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Icon(icon, size: 64, color: cs.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'قيد البناء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
