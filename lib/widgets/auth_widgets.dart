import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../view_models/session_view_model.dart';
import 'session_scope.dart';

/// Campo de texto con etiqueta, con el mismo estilo que el formulario de subida.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLines: maxLines,
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra el último error (rojo) o aviso (verde) de la sesión, con una X para
/// cerrarlo. No ocupa lugar si no hay nada que mostrar.
class SessionBanner extends StatelessWidget {
  const SessionBanner({super.key, this.session});

  final SessionViewModel? session;

  @override
  Widget build(BuildContext context) {
    final effectiveSession = session ?? SessionScope.of(context);
    final error = effectiveSession.error;
    final notice = effectiveSession.notice;
    final message = error ?? notice;
    if (message == null) return const SizedBox.shrink();

    final color = error != null ? Colors.redAccent : AppTheme.primaryGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            error != null ? Icons.error_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Cerrar aviso',
            icon: const Icon(Icons.close, size: 18),
            color: AppTheme.textSecondary,
            onPressed: effectiveSession.clearMessages,
          ),
        ],
      ),
    );
  }
}

/// Botón principal de los formularios: muestra un spinner mientras [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
