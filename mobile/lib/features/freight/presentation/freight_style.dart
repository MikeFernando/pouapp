import 'package:flutter/material.dart';

import '../domain/entities/freight_ledger.dart';
import 'freight_labels.dart';

const freightBlue = Color(0xFF1E88E5);
const freightAccent = Color(0xFF1565C0);
const freightSoft = Color(0xFFE3F2FD);
const freightCanvas = Color(0xFFF4F6F8);
const freightInk = Color(0xFF1C1C1E);
const freightMuted = Color(0xFF6B7280);

AppBar freightBar(String title) {
  return AppBar(
    backgroundColor: freightBlue,
    foregroundColor: Colors.white,
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}

final freightFilled = FilledButton.styleFrom(
  backgroundColor: freightBlue,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightFilledWide = FilledButton.styleFrom(
  backgroundColor: freightBlue,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightOutlined = OutlinedButton.styleFrom(
  foregroundColor: freightAccent,
  backgroundColor: Colors.white,
  side: const BorderSide(color: freightAccent),
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

final freightOutlinedWide = OutlinedButton.styleFrom(
  foregroundColor: freightAccent,
  backgroundColor: Colors.white,
  side: const BorderSide(color: freightAccent),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

InputDecoration freightField(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF3F4F6),
    labelStyle: const TextStyle(fontSize: 14, color: freightMuted),
    floatingLabelStyle: const TextStyle(color: freightAccent),
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
      borderSide: const BorderSide(color: freightBlue),
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
        : freightAccent;
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
