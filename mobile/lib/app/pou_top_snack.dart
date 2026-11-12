import 'package:flutter/material.dart';

const _ink = Color(0xFF121417);

enum PouTopSnackTone { success, info }

OverlayEntry? _activePouTopSnack;

/// Removes the current top toast immediately, if any.
void dismissPouTopSnack() {
  final entry = _activePouTopSnack;
  _activePouTopSnack = null;
  if (entry == null) return;
  if (entry.mounted) entry.remove();
}

/// Top toast that slides in from the right and stays long enough to read.
Future<void> showPouTopSnack(
  BuildContext context, {
  required String message,
  required IconData icon,
  PouTopSnackTone tone = PouTopSnackTone.success,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future<void>.value();

  dismissPouTopSnack();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return _PouTopSnackHost(
        message: message,
        icon: icon,
        tone: tone,
        duration: duration,
        onDone: () {
          if (_activePouTopSnack == entry) {
            _activePouTopSnack = null;
          }
          if (entry.mounted) entry.remove();
        },
      );
    },
  );
  _activePouTopSnack = entry;
  overlay.insert(entry);
  // Do not await the toast — callers (and the back button) stay free.
  return Future<void>.value();
}

class _PouTopSnackHost extends StatefulWidget {
  const _PouTopSnackHost({
    required this.message,
    required this.icon,
    required this.tone,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final PouTopSnackTone tone;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_PouTopSnackHost> createState() => _PouTopSnackHostState();
}

class _PouTopSnackHostState extends State<_PouTopSnackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(widget.duration);
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInfo = widget.tone == PouTopSnackTone.info;
    final iconColor = isInfo ? const Color(0xFF1D4ED8) : const Color(0xFF146C43);
    final iconFill = isInfo ? const Color(0xFFDBEAFE) : const Color(0xFFD8F5E4);

    // AppBar row, tucked to the right so the back button stays tappable.
    final media = MediaQuery.of(context);
    final top = media.padding.top + 8;
    final maxWidth = (media.size.width - 72 - 16).clamp(180.0, 320.0);
    return Positioned(
      top: top,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
