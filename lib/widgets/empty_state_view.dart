import 'package:flutter/material.dart';

/// Componente reutilizable para estados vacíos de la app (criterio B1).
///
/// Proporciona un ícono sutil, título explicativo, descripción opcional
/// y botones de acción principal o secundario, adaptado al tema oscuro.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white38 : Colors.black38;
    final titleColor = isDark ? Colors.white70 : Colors.black87;
    final descColor = isDark ? Colors.white54 : Colors.black54;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16.0 : 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 36.0 : 56.0, color: iconColor),
            SizedBox(height: compact ? 8.0 : 16.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8.0),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: descColor),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 12.0 : 20.0),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
