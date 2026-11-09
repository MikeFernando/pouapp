import 'package:flutter/material.dart';

import '../../../app/pou_app_colors.dart';

import '../domain/entities/freight_ledger.dart';
import 'freight_labels.dart';

const freightBlue = pouInk;
const freightAccent = pouAccent;
const freightSoft = pouSurface;
const freightCanvas = pouCanvas;
const freightInk = pouInk;
const freightMuted = Color(0xFF6B7280);

AppBar freightBar(String title) {
  return AppBar(
    backgroundColor: freightBlue,
    foregroundColor: pouCanvas,
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}

final freightFilled = FilledButton.styleFrom(
  backgroundColor: pouInk,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightFilledWide = FilledButton.styleFrom(
  backgroundColor: pouInk,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightOutlined = OutlinedButton.styleFrom(
  foregroundColor: pouInk,
  backgroundColor: pouCanvas,
  side: const BorderSide(color: pouInk),
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightOutlinedWide = OutlinedButton.styleFrom(
  foregroundColor: pouInk,
  backgroundColor: pouCanvas,
  side: const BorderSide(color: pouInk),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

InputDecoration freightField(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: pouSurface,
    labelStyle: const TextStyle(fontSize: 14, color: freightMuted),
    floatingLabelStyle: const TextStyle(color: pouInk),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: pouAccent),
    ),
  );
}

class FreightPill extends StatelessWidget {
  const FreightPill({super.key, required this.label, required this.late});

  final String label;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final done =
        label == freightPaymentLabel(FreightPaymentStanding.paid) ||
        label == 'Concluída' ||
        label == 'Entregue';
    final warn =
        label == freightPaymentLabel(FreightPaymentStanding.partial) ||
        label == 'Coletado';
    final bad =
        late ||
        label == 'Atrasado' ||
        label == 'Cancelada' ||
        label == 'Cancelado';
    final background = bad
        ? const Color(0xFFFDECEC)
        : done
        ? const Color(0xFFD8F5E4)
        : warn
        ? const Color(0xFFFFF4E5)
        : freightSoft;
    final foreground = bad
        ? const Color(0xFFC62828)
        : done
        ? const Color(0xFF146C43)
        : warn
        ? const Color(0xFFB45309)
        : pouInk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
