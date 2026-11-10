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
        ],
      ),
    );
  }
}
