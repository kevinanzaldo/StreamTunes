import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/session_scope.dart';
import 'register_view.dart';

/// Formulario de ingreso. Se muestra dentro de "Mi cuenta" mientras no haya
/// sesión iniciada: al entrar, `AccountView` lo reemplaza solo.
class LoginView extends StatefulWidget {
  const LoginView({super.key, this.title = 'Mi cuenta', this.message});

  /// Título de la barra (cambia cuando el formulario aparece en una pantalla
  /// protegida, por ejemplo "Playlists").
  final String title;

  /// Texto de bienvenida; si es null se usa el genérico.
  final String? message;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await SessionScope.of(
      context,
    ).signIn(email: _emailController.text, password: _passwordController.text);
  }

  Future<void> _resetPassword() async {
    await SessionScope.of(context).sendPasswordReset(_emailController.text);
  }

  Future<void> _openRegister() async {
    final session = SessionScope.of(context);
    session.clearMessages();
    final registered = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const RegisterView()));
    // Si se registró, se conserva el aviso (por ejemplo "confirmá tu email").
    if (registered != true) session.clearMessages();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SessionBanner(session: session),
          Text(
            widget.message ?? 'Ingresá para armar playlists, donar y subir la música de tu banda.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            key: const ValueKey('login_email'),
            controller: _emailController,
            label: 'Email',
            hint: 'tu@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('login_password'),
            controller: _passwordController,
            label: 'Contraseña',
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
          if (AppConfig.shouldUseMock) ...[
            const Text(
              'Modo demo: probá con ana@streamtunes.test (tiene banda), '
              'caro@streamtunes.test (oyente) o admin@streamtunes.test. '
              'Contraseña: Test1234!',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
          AuthSubmitButton(
            label: 'Entrar',
            busy: session.busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: session.busy ? null : _resetPassword,
            child: const Text('Olvidé mi contraseña'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o ingresá con',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('login_google_button'),
            icon: Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 22),
            ),
            label: const Text(
              'Continuar con Google',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.white24),
              foregroundColor: Colors.white,
            ),
            onPressed: session.busy ? null : () => session.signInWithGoogle(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Si aún no configuraste Google OAuth en Supabase, ingresá con tu email y contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: session.busy ? null : _openRegister,
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
