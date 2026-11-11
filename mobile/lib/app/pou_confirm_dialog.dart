import 'package:flutter/material.dart';

import 'pou_app_colors.dart';

/// Shows a centered confirm dialog and returns `true` when the primary
/// action is confirmed.
Future<bool> showPouConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
  String cancelLabel = 'Cancelar',
  IconData icon = Icons.delete_outline_rounded,
  Key? confirmKey,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x990E0D0F),
    builder: (context) => PouConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      confirmKey: confirmKey,
    ),
  );
  return result == true;
}

class PouConfirmDialog extends StatelessWidget {
  const PouConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Continuar',
    this.cancelLabel = 'Cancelar',
    this.icon = Icons.delete_outline_rounded,
    this.confirmKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F0F2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: pouInk,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 22, color: pouInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: pouInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: confirmKey,
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: pouBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
