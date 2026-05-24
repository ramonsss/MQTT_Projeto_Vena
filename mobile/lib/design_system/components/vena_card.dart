// B3 — VenaCard: rounded card with organic shadow and 20 px corners.
//
// All Vena screens use this as the base container for content blocks.
// The shadow lifts slightly on tap to give tactile feedback.

import 'package:flutter/material.dart';

import '../tokens.dart';

class VenaCard extends StatelessWidget {
  const VenaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VenaSpacing.xl),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Background colour. Defaults to [ColorScheme.surface].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(VenaRadius.xl),
        boxShadow: VenaShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VenaRadius.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VenaRadius.xl),
          splashColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
