// B2 — StoredContentSelector: quick-fill widget for "what is stored" field.
//
// Shows two ChoiceChips (Cacau, Pimenta-do-reino).

import 'package:flutter/material.dart';

import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';

/// The two content options.
enum _ContentOption { cacau, pimenta }

extension _ContentOptionData on _ContentOption {
  String get label => switch (this) {
        _ContentOption.cacau => 'Cacau',
        _ContentOption.pimenta => 'Pimenta-do-reino',
      };

  Color get chipColor => switch (this) {
        _ContentOption.cacau => const Color(0xFF6B4226),
        _ContentOption.pimenta => const Color(0xFF2C2C2C),
      };

  IconData get chipIcon => switch (this) {
        _ContentOption.cacau => Icons.spa_outlined,
        _ContentOption.pimenta => Icons.scatter_plot,
      };
}

class StoredContentSelector extends StatefulWidget {
  const StoredContentSelector({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  /// Called whenever the selection changes.
  /// - `null`  → user cleared
  /// - non-null → the selected content label
  final void Function(String? value) onChanged;

  /// Pre-fill when editing an existing device.
  final String? initialValue;

  @override
  State<StoredContentSelector> createState() => _StoredContentSelectorState();
}

class _StoredContentSelectorState extends State<StoredContentSelector> {
  _ContentOption? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial != null && initial.isNotEmpty) {
      final match = _ContentOption.values
          .cast<_ContentOption?>()
          .firstWhere(
            (o) => o?.label == initial,
            orElse: () => null,
          );
      _selected = match;
    }
  }

  void _onChipTap(_ContentOption option) {
    setState(() {
      if (_selected == option) {
        // Tap again to deselect.
        _selected = null;
        widget.onChanged(null);
      } else {
        _selected = option;
        widget.onChanged(option.label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'O que está armazenado?',
          style: VenaTypography.labelLarge,
        ),
        const SizedBox(height: VenaSpacing.sm),
        Row(
          children: [
            Expanded(child: _buildChip(_ContentOption.cacau)),
            const SizedBox(width: VenaSpacing.sm),
            Expanded(child: _buildChip(_ContentOption.pimenta)),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(_ContentOption option) {
    final isSelected = _selected == option;
    final chipColor = option.chipColor;

    // Custom container instead of ChoiceChip so it respects Expanded width.
    return GestureDetector(
      onTap: () => _onChipTap(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: VenaSpacing.md,
          vertical: VenaSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(VenaRadius.md),
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.chipIcon, size: 16, color: Colors.white),
            const SizedBox(width: VenaSpacing.xs),
            Text(
              option.label,
              style: VenaTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
