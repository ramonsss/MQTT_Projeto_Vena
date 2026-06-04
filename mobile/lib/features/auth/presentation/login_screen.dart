import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../design_system/components/vena_button.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import 'splash_screen.dart' show VenaLogo;

/// Tela de autenticação — logo + botão "Entrar com Google".
///
/// A navegação após login é gerenciada pelo redirect do GoRouter.
/// Esta tela apenas dispara [AuthNotifier.signIn()] e exibe erros.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // Mostra snackbar se o login falhar.
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Falha no login. Tente novamente.',
                  style: VenaTypography.bodySmall.copyWith(color: Colors.white),
                ),
                backgroundColor: VenaColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    });

    return Scaffold(
      backgroundColor: VenaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: VenaSpacing.xl),
          child: Column(
            children: [
              // ── Hero — 60% da tela, logo centralizada ──────────────────
              Expanded(
                flex: 6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VenaLogo(width: 240),
                      const SizedBox(height: VenaSpacing.md),
                      Text(
                        'Monitore. Controle. Cultive.',
                        style: VenaTypography.bodyMedium.copyWith(
                          color: VenaColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // ── CTA — 40% da tela, botão fixo ao fundo ─────────────────
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    VenaButton(
                      label: 'Entrar com Google',
                      variant: VenaButtonVariant.secondary,
                      isLoading: authState.isLoading,
                      leadingIcon: authState.isLoading
                          ? null
                          : const _GoogleG(),
                      onPressed: authState.isLoading
                          ? null
                          : () =>
                              ref.read(authNotifierProvider.notifier).signIn(),
                    ),
                    const SizedBox(height: VenaSpacing.md),
                    Text(
                      'Ao entrar, você concorda com os Termos de Uso.',
                      style: VenaTypography.labelSmall.copyWith(
                        color: VenaColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: VenaSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────

/// Ícone "G" estilizado do Google como leading do botão.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF4285F4),
        height: 1.0,
      ),
    );
  }
}
