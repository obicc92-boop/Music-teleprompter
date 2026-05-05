import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../engine/beat_detector.dart';

class BpmIndicator extends StatefulWidget {
  final Stream<BeatEvent> beatStream;
  final double bpm;
  final bool isVoiceActive;
  final double voiceEnergy;

  const BpmIndicator({
    super.key,
    required this.beatStream,
    required this.bpm,
    required this.isVoiceActive,
    required this.voiceEnergy,
  });

  @override
  State<BpmIndicator> createState() => _BpmIndicatorState();
}

class _BpmIndicatorState extends State<BpmIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<BeatEvent>? _beatSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _beatSub = widget.beatStream.listen((_) {
      _pulseController.forward(from: 0.0);
    });
  }

  @override
  void didUpdateWidget(BpmIndicator old) {
    super.didUpdateWidget(old);
    if (old.beatStream != widget.beatStream) {
      _beatSub?.cancel();
      _beatSub = widget.beatStream.listen((_) {
        _pulseController.forward(from: 0.0);
      });
    }
  }

  @override
  void dispose() {
    _beatSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _voiceDot(),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse = 1.0 - _pulseController.value * 0.4;
            return Transform.scale(
              scale: 1.0 + (1.0 - pulse) * 0.2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.beatFlash.withValues(
                    alpha: 0.4 + _pulseController.value * 0.6,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          '${widget.bpm.round()} BPM',
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 13,
            color: AppColors.sectionHeader,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _voiceDot() {
    final clampedEnergy = (widget.voiceEnergy / 0.1).clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isVoiceActive
            ? AppColors.voiceActive
            : AppColors.voiceInactive,
        boxShadow: widget.isVoiceActive
            ? [BoxShadow(
                color: AppColors.voiceActive.withValues(alpha: clampedEnergy),
                blurRadius: 6,
                spreadRadius: 1,
              )]
            : null,
      ),
    );
  }
}
