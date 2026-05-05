import 'package:flutter/widgets.dart';

class MirrorTransform extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const MirrorTransform({super.key, required this.child, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(0, 0, -1.0),
      child: child,
    );
  }
}
