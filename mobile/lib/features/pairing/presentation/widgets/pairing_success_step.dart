// E4 — PairingSuccessStep: confirmation with alias + stored-content input.

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../design_system/components/vena_button.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';
import 'stored_content_selector.dart';

class PairingSuccessStep extends StatefulWidget {
  const PairingSuccessStep({
    super.key,
    required this.onFinish,
  });

  /// [alias] may be empty (user skipped); [storedContent] may be null.
  final void Function(String alias, String? storedContent) onFinish;

  @override
  State<PairingSuccessStep> createState() => _PairingSuccessStepState();
}

class _PairingSuccessStepState extends State<PairingSuccessStep>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  String? _storedContent;
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VenaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: VenaSpacing.xxl),
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: const Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: VenaColors.online,
              ),
            ),
          ),
          const SizedBox(height: VenaSpacing.xl),
          Text(
            'Dispositivo pareado!',
            style: VenaTypography.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VenaSpacing.sm),
          Text(
            'Dê um apelido ao dispositivo para identificá-lo facilmente.',
            textAlign: TextAlign.center,
            style:
                VenaTypography.bodyMedium.copyWith(color: VenaColors.textSecondary),
          ),
          const SizedBox(height: VenaSpacing.xxxl),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Apelido (opcional)',
              hintText: 'Ex: Sala de fermentação',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VenaRadius.md),
              ),
            ),
            onSubmitted: (_) =>
                widget.onFinish(_controller.text, _storedContent),
          ),
          const SizedBox(height: VenaSpacing.xl),
          StoredContentSelector(
            onChanged: (value) => setState(() => _storedContent = value),
          ),
          const SizedBox(height: VenaSpacing.xl),
          VenaButton(
            label: 'Concluir',
            onPressed: () => widget.onFinish(_controller.text, _storedContent),
          ),
          const SizedBox(height: VenaSpacing.md),
          VenaButton(
            label: 'Pular',
            variant: VenaButtonVariant.ghost,
            onPressed: () => widget.onFinish('', null),
          ),
        ],
      ),
    );
  }
}
