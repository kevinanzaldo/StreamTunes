import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/session_scope.dart';

/// Registro: nombre, email y contraseña. Se abre desde `LoginView` y se cierra
/// solo (devolviendo `true`) cuando la cuenta se creó.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await session.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SessionBanner(session: session),
          const Text(
            'Una sola cuenta sirve para escuchar y, si querés, para tener tu banda.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            key: const ValueKey('register_name'),
            controller: _nameController,
            label: 'Nombre',
            hint: 'Cómo te van a ver los demás',
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('register_email'),
            controller: _emailController,
            label: 'Email',
            hint: 'tu@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('register_password'),
            controller: _passwordController,
            label: 'Contraseña',
            hint: 'Al menos 8 caracteres',
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
          const SizedBox(height: 4),
          AuthSubmitButton(
            label: 'Registrarme',
            busy: session.busy,
            onPressed: _submit,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o registrate con',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('register_google_button'),
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
            onPressed: session.busy
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    final ok = await session.signInWithGoogle();
                    if (ok && mounted) nav.pop(true);
                  },
          ),
          const SizedBox(height: 6),
          const Text(
            'Si aún no configuraste Google OAuth en Supabase, registrate con tu email arriba.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
