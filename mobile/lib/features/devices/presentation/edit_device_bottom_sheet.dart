// C1 — EditDeviceBottomSheet: long-press edit for alias + stored content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../design_system/components/vena_button.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../../pairing/presentation/widgets/stored_content_selector.dart';
import '../application/device_actions_provider.dart';

/// Shows a modal bottom sheet allowing the user to edit the alias and stored
/// content of a device. Call via [showEditDeviceSheet].
Future<void> showEditDeviceSheet(BuildContext context, Device device) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(VenaRadius.xl)),
    ),
    builder: (_) => _EditDeviceBottomSheet(device: device),
  );
}

class _EditDeviceBottomSheet extends ConsumerStatefulWidget {
  const _EditDeviceBottomSheet({required this.device});

  final Device device;

  @override
  ConsumerState<_EditDeviceBottomSheet> createState() =>
      _EditDeviceBottomSheetState();
}

class _EditDeviceBottomSheetState
    extends ConsumerState<_EditDeviceBottomSheet> {
  late final TextEditingController _aliasController;
  String? _storedContent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _aliasController =
        TextEditingController(text: widget.device.alias);
    _storedContent = widget.device.storedContent;
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O apelido não pode ser vazio.')),
      );
      return;
    }

    setState(() => _saving = true);

    final actions = ref.read(deviceActionsProvider.notifier);
    await actions.renameDevice(widget.device.deviceId, alias);
    await actions.updateStoredContent(
        widget.device.deviceId, _storedContent);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        VenaSpacing.xl,
        VenaSpacing.xl,
        VenaSpacing.xl,
        VenaSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(VenaRadius.full),
              ),
            ),
          ),
          const SizedBox(height: VenaSpacing.lg),

          // ── Title ────────────────────────────────────────────────────
          Text('Editar dispositivo', style: VenaTypography.headlineSmall),
          const SizedBox(height: VenaSpacing.xl),

          // ── Alias field ───────────────────────────────────────────────
          TextField(
            controller: _aliasController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Apelido',
              hintText: 'Ex: Sala de fermentação',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VenaRadius.md),
              ),
            ),
          ),
          const SizedBox(height: VenaSpacing.xl),

          // ── Stored content selector ───────────────────────────────────
          StoredContentSelector(
            initialValue: _storedContent,
            onChanged: (value) => setState(() => _storedContent = value),
          ),
          const SizedBox(height: VenaSpacing.xl),

          // ── Save button ───────────────────────────────────────────────
          VenaButton(
            label: 'Salvar',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
