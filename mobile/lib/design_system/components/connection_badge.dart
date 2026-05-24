// B5 — ConnectionBadge: online/offline status with a breathing pulse animation.
//
// When [online] is true the dot pulses at [VenaDuration.pulse] frequency
// to indicate a live connection. When offline the dot is static.
//
// Example:
//   ConnectionBadge(online: true)
//   ConnectionBadge(online: false, label: 'Desconectado')

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../tokens.dart';
import '../typography.dart';

class ConnectionBadge extends StatefulWidget {
  const ConnectionBadge({
    super.key,
    required this.online,
    this.label,
  });

  final bool online;

  /// Custom label. Defaults to "Online" / "Offline".
  final String? label;

  @override
  State<ConnectionBadge> createState() => _ConnectionBadgeState();
}

class _ConnectionBadgeState extends State<ConnectionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: VenaDuration.pulse,
    );
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.online) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ConnectionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.online && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.online && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0; // keep dot fully opaque when offline
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.online ? VenaColors.online : VenaColors.offline;
    final label =
        widget.label ?? (widget.online ? 'Online' : 'Offline');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: widget.online ? _opacity.value : 1.0,
              ),
              shape: BoxShape.circle,
              boxShadow: widget.online
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(width: VenaSpacing.sm - 2),
        Text(
          label,
          style: VenaTypography.labelMedium.copyWith(color: color),
        ),
      ],
    );
  }
}
