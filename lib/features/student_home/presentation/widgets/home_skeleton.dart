import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Pulsing placeholder block that animates between two token fills.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.width, required this.height, this.radius = MqRadius.brSm});
  final double width;
  final double height;
  final BorderRadius radius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(mq.fill, mq.fill2, _c.value),
            borderRadius: widget.radius,
          ),
        );
      },
    );
  }
}

/// Full-screen loading state for the Student Home — mirrors the real layout
/// (hero, two upcoming cards, a progress block, and a rail) so the transition
/// to loaded content doesn't jump.
class StudentHomeSkeleton extends StatelessWidget {
  const StudentHomeSkeleton({super.key, this.topInset = 0});

  /// Status-bar / notch inset folded into the top scroll padding when the
  /// screen is embedded (host uses SafeArea(top: false)).
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md + topInset, MqSpacing.lg, MqSpacing.xl),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _block(height: 96),
        MqSpacing.gapLg,
        Row(
          children: [
            Expanded(child: _block(height: 150)),
            MqSpacing.gapMd,
            Expanded(child: _block(height: 150)),
          ],
        ),
        MqSpacing.gapLg,
        _block(height: 120),
        MqSpacing.gapLg,
        const _Shimmer(width: 140, height: 18),
        MqSpacing.gapMd,
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, _) => MqSpacing.gapMd,
            itemBuilder: (_, _) => const _Shimmer(width: 200, height: 184, radius: MqRadius.brLg),
          ),
        ),
      ],
    );
  }

  Widget _block({required double height}) =>
      _Shimmer(width: double.infinity, height: height, radius: MqRadius.brLg);
}
