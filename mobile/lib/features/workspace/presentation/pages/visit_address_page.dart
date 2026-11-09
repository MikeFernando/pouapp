import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/street_ledger.dart';

class VisitAddressPage extends StatelessWidget {
  const VisitAddressPage({super.key, required this.visit});

  final RouteVisit visit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('Endereço')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visit.customerName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              visit.address,
              key: const Key('address_text'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
