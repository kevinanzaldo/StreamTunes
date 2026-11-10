import 'package:flutter/material.dart';

import '../models/band.dart';
import '../models/band_membership.dart';
import '../models/donation.dart';
import '../theme/app_theme.dart';
import '../view_models/session_view_model.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/repositories_scope.dart';
import '../widgets/session_scope.dart';
import 'admin_moderation_view.dart';
import 'band_dashboard_view.dart';
import 'create_band_view.dart';
import 'login_view.dart';

/// Pestaña "Cuenta": ingreso si no hay sesión; si la hay, la persona, sus
/// bandas (con su estado de moderación) y el cierre de sesión.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);

    if (session == null) {
      return const _AccountMessage(text: 'La cuenta no está disponible.');
    }
    if (session.isRestoring) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!session.isLoggedIn) return const LoginView();
    return _AccountBody(session: session);
  }
}

class _AccountMessage extends StatelessWidget {
  const _AccountMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.session});

  final SessionViewModel session;

  Future<void> _createBand(BuildContext context) async {
    session.clearMessages();
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateBandView()));
  }

  @override
  Widget build(BuildContext context) {
    final profile = session.profile!;
    final initial = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim()[0].toUpperCase();
    final activeId = session.activeBand?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SessionBanner(session: session),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryGreen,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (session.isAdmin) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.security,
                            size: 14,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Moderación del Colectivo',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            key: const Key('admin_moderation_button'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              foregroundColor: AppTheme.primaryGreen,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminModerationView(),
                                ),
                              );
                            },
                            child: const Text(
                              'Abrir panel',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Mis bandas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (!session.hasBand)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no tenés bandas. Creá la tuya para subir música.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            for (final membership in session.memberships)
              _BandTile(
                key: ValueKey('band_${membership.band.id}'),
                membership: membership,
                isActive: membership.band.id == activeId,
                onTap: () => session.selectActiveBand(membership.band.id),
              ),
          if (session.activeBand != null) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const ValueKey('open_band_dashboard'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BandDashboardView(band: session.activeBand!),
                  ),
                );
              },
              icon: const Icon(Icons.dashboard, size: 18, color: Colors.black),
              label: Text(
                'Abrir panel de ${session.activeBand!.name}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: session.busy ? null : () => _createBand(context),
            icon: const Icon(Icons.add),
            label: const Text('Crear mi banda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceElevated,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Text(
            'Mis aportes al Colectivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const _UserDonationsSection(),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: session.busy ? null : session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _BandTile extends StatelessWidget {
  const _BandTile({
    super.key,
    required this.membership,
    required this.isActive,
    required this.onTap,
  });

  final BandMembership membership;
  final bool isActive;
  final VoidCallback onTap;

  static String _statusText(BandStatus status) {
    switch (status) {
      case BandStatus.pending:
        return 'Pendiente de aprobación: un moderador la está revisando y '
            'todavía no es pública.';
      case BandStatus.approved:
        return 'Aprobada: ya es pública.';
      case BandStatus.suspended:
        return 'Suspendida: no es visible. Hablá con el Colectivo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = membership.band;
    final role = membership.isOwner ? 'Responsable' : 'Integrante';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: AppTheme.primaryGreen) : null,
      ),
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            isActive
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isActive ? AppTheme.primaryGreen : AppTheme.textMuted,
          ),
          title: Text(
            band.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '$role · ${_statusText(band.status)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _UserDonationsSection extends StatelessWidget {
  const _UserDonationsSection();

  @override
  Widget build(BuildContext context) {
    final donationsRepo = RepositoriesScope.of(context).donations;

    return FutureBuilder<List<Donation>>(
      future: donationsRepo.getMyDonations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          );
        }

        final donations = snapshot.data ?? const [];
        if (donations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no realizaste aportes a ninguna banda.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return Card(
          color: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: donations.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final d = donations[index];
              return ListTile(
                leading: const Icon(
                  Icons.favorite,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                title: Text(
                  d.artistName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: d.message != null && d.message!.isNotEmpty
                    ? Text(
                        d.message!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: Text(
                  d.formattedAmount,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
