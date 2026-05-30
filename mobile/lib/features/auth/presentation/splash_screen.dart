import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';

/// Exibida enquanto [AuthNotifier.build()] verifica os tokens armazenados.
///
/// A navegação é inteiramente gerenciada pelo redirect do GoRouter:
/// - auth carregando  → permanece aqui
/// - auth nulo        → /login
/// - auth presente    → /devices
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logoWidth = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: VenaColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VenaLogo(width: logoWidth),
            const SizedBox(height: 20),
            Text(
              'Monitor. Controle. Cultive.',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: VenaColors.textSecondary,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 56),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: VenaColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo oficial da Vena carregada de assets/images/logo.png.
///
/// Reutilizada na SplashScreen e na LoginScreen.
class VenaLogo extends StatelessWidget {
  const VenaLogo({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
