import 'dart:math' as math;
import 'package:flutter/material.dart';

class DynamicMeshBackground extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  const DynamicMeshBackground({
    super.key,
    required this.child,
    this.isPlaying = true,
    this.primaryColor = const Color(0xFF6B1123),
    this.secondaryColor = const Color(0xFF1E1B4B),
  });

  @override
  State<DynamicMeshBackground> createState() => _DynamicMeshBackgroundState();
}

class _DynamicMeshBackgroundState extends State<DynamicMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DynamicMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final x1 = math.sin(t * 2 * math.pi) * 0.3;
        final y1 = math.cos(t * 2 * math.pi) * 0.3;

        return Stack(
          children: [
            Container(color: Colors.black),
            Positioned(
              top: -60 + (y1 * 80),
              left: -60 + (x1 * 80),
              width: 320,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.primaryColor.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60 - (y1 * 70),
              right: -50 - (x1 * 70),
              width: 340,
              height: 340,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.secondaryColor.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.primaryColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}
