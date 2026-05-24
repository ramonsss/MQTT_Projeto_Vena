// B6 — VenaButton: primary / secondary / ghost variants with haptic feedback.
//
// All variants have a fixed height of 52 px to keep touch targets consistent.
// Pass [isLoading] to replace the label with a spinner while an async action
// is in progress.
//
// Example:
//   VenaButton(label: 'Entrar com Google', onPressed: _signIn)
//   VenaButton(label: 'Cancelar', variant: VenaButtonVariant.secondary, onPressed: _cancel)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import '../typography.dart';

enum VenaButtonVariant { primary, secondary, ghost }

class VenaButton extends StatelessWidget {
  const VenaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VenaButtonVariant.primary,
    this.leadingIcon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final VenaButtonVariant variant;

  /// Icon shown before the label.
  final Widget? leadingIcon;
  final bool isLoading;

  /// When `false`, the button shrinks to wrap its content.
  final bool isFullWidth;

  void _handlePress() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }

  Widget _buildContent(Color spinnerColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          leadingIcon!,
          const SizedBox(width: VenaSpacing.sm),
        ],
        Text(label, style: VenaTypography.button),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = isFullWidth ? double.infinity : null;
    const height = 52.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VenaRadius.xl),
    );

    switch (variant) {
      case VenaButtonVariant.primary:
        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handlePress,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.5),
              shape: shape,
              elevation: 0,
            ),
            child: _buildContent(cs.onPrimary),
          ),
        );

      case VenaButtonVariant.secondary:
        return SizedBox(
          width: width,
          height: height,
          child: OutlinedButton(
            onPressed: isLoading ? null : _handlePress,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary, width: 1.5),
              shape: shape,
            ),
            child: _buildContent(cs.primary),
          ),
        );

      case VenaButtonVariant.ghost:
        return SizedBox(
          width: width,
          height: height,
          child: TextButton(
            onPressed: isLoading ? null : _handlePress,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              shape: shape,
            ),
            child: _buildContent(cs.primary),
          ),
        );
    }
  }
}
