import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/session_scope.dart';

/// Alta de una banda. Queda pendiente hasta que un moderador del Colectivo la
/// apruebe (así se filtra la música de terceros, pedido de Kiwi).
class CreateBandView extends StatefulWidget {
  const CreateBandView({super.key});

  @override
  State<CreateBandView> createState() => _CreateBandViewState();
}

class _CreateBandViewState extends State<CreateBandView> {
  final _nameController = TextEditingController();
  final _genreController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _genreController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await session.createBand(
      name: _nameController.text,
      genre: _genreController.text,
      location: _locationController.text,
      bio: _bioController.text,
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva banda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const SessionBanner(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Tu banda queda pendiente hasta que un moderador del Colectivo '
              'la apruebe. Mientras tanto no es pública.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            key: const ValueKey('create_band_name'),
            controller: _nameController,
            label: 'Nombre de la banda',
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('create_band_genre'),
            controller: _genreController,
            label: 'Género',
            hint: 'Ej: Rock alternativo',
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('create_band_location'),
            controller: _locationController,
            label: 'Ciudad',
            hint: 'Ej: Mendoza',
            textInputAction: TextInputAction.next,
          ),
          AuthTextField(
            key: const ValueKey('create_band_bio'),
            controller: _bioController,
            label: 'Bio corta (opcional)',
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          AuthSubmitButton(
            label: 'Crear banda',
            busy: session.busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
