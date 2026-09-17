import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/constants.dart';
import 'app_logo.dart';

class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;

    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          // macOS: native traffic lights occupy ~72px at top-left — leave room
          if (isMac) const SizedBox(width: 76),

          // Draggable title area
          Expanded(
            child: DragToMoveArea(
              child: Align(
                alignment:
                    isMac ? Alignment.center : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: isMac ? 0 : 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Music Teleprompter',
                        style: TextStyle(
                          fontFamily: AppTextStyles.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.uiHint,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Windows / Linux: custom window buttons
          if (!isMac) ...[
            _WinButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onTap: () => windowManager.minimize(),
            ),
            _WinButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              onTap: () => _isMaximized
                  ? windowManager.unmaximize()
                  : windowManager.maximize(),
            ),
            _WinButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              isClose: true,
              onTap: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WinButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : AppColors.surfaceElevated;
    final iconColor =
        (_hovered && widget.isClose) ? Colors.white : AppColors.uiHint;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 46,
            height: 36,
            color: _hovered ? hoverBg : Colors.transparent,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
