import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DocStatus { draft, inProgress, saved, exported }

class StatusBadgeWidget extends StatelessWidget {
  final DocStatus status;
  const StatusBadgeWidget({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      DocStatus.draft => (
        'Draft',
        const Color(0xFFF0F0F5),
        const Color(0xFF6B6B80),
      ),
      DocStatus.inProgress => (
        'In Progress',
        const Color(0xFFFDE8DC),
        AppTheme.secondary,
      ),
      DocStatus.saved => ('Saved', AppTheme.successContainer, AppTheme.success),
      DocStatus.exported => (
        'Exported',
        AppTheme.primaryContainer,
        AppTheme.primary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
