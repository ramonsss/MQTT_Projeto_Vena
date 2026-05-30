// E3 — WifiProvisionStep: form to enter Wi-Fi credentials for BLE provisioning.

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../design_system/components/vena_button.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';

class WifiProvisionStep extends StatefulWidget {
  const WifiProvisionStep({
    super.key,
    required this.deviceName,
    required this.onSubmit,
    required this.onSkip,
    this.isLoading = false,
  });

  final String deviceName;
  final void Function(String ssid, String psk) onSubmit;
  final VoidCallback onSkip;
  final bool isLoading;

  @override
  State<WifiProvisionStep> createState() => _WifiProvisionStepState();
}

class _WifiProvisionStepState extends State<WifiProvisionStep> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _pskController = TextEditingController();
  bool _obscurePsk = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _pskController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    widget.onSubmit(_ssidController.text.trim(), _pskController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VenaSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: VenaSpacing.xl),
            const Icon(Icons.wifi_lock, size: 56, color: VenaColors.primary),
            const SizedBox(height: VenaSpacing.lg),
            Text(
              'Configurar Wi-Fi',
              style: VenaTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VenaSpacing.sm),
            Text(
              'Informe as credenciais da rede Wi-Fi para o dispositivo ${widget.deviceName}.',
              style: VenaTypography.bodySmall
                  .copyWith(color: VenaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VenaSpacing.xxxl),
            TextFormField(
              controller: _ssidController,
              enabled: !widget.isLoading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nome da rede (SSID)',
                hintText: 'Ex: FazendaWifi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VenaRadius.md),
                ),
                prefixIcon: const Icon(Icons.wifi),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Informe o nome da rede.';
                }
                return null;
              },
            ),
            const SizedBox(height: VenaSpacing.lg),
            TextFormField(
              controller: _pskController,
              enabled: !widget.isLoading,
              obscureText: _obscurePsk,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VenaRadius.md),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePsk ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePsk = !_obscurePsk),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'A senha deve ter pelo menos 8 caracteres.';
                }
                return null;
              },
            ),
            const SizedBox(height: VenaSpacing.xxxl),
            if (widget.isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: VenaSpacing.md),
                    Text('Configurando Wi-Fi no dispositivo...'),
                  ],
                ),
              )
            else ...[
              VenaButton(label: 'Configurar Wi-Fi', onPressed: _submit),
              const SizedBox(height: VenaSpacing.md),
              VenaButton(
                label: 'Pular (dispositivo já tem Wi-Fi)',
                variant: VenaButtonVariant.ghost,
                onPressed: widget.onSkip,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
