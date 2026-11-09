import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../customers/presentation/customer_routes.dart';
import '../../domain/entities/freight_ledger.dart';
import '../bloc/freight_bloc.dart';
import '../freight_labels.dart';
import '../freight_style.dart';
import 'freight_page.dart';

class FreightTripFormPage extends StatefulWidget {
  const FreightTripFormPage({super.key});

  @override
  State<FreightTripFormPage> createState() => _FreightTripFormPageState();
}

class _FreightTripFormPageState extends State<FreightTripFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _depart;
  late final TextEditingController _returns;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _name = TextEditingController(text: 'Curitiba — ${_month(now)}');
    _depart = TextEditingController(text: freightDayLabel(freightIsoDate(now)));
    _returns = TextEditingController(
      text: freightDayLabel(freightIsoDate(now.add(const Duration(days: 1)))),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _depart.dispose();
    _returns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: freightCanvas,
      appBar: freightBar('Nova viagem'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('freight_trip_name'),
            controller: _name,
            decoration: freightField('Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_trip_depart'),
            controller: _depart,
            decoration: freightField('Ida'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_trip_return'),
            controller: _returns,
            decoration: freightField('Volta'),
          ),
          const SizedBox(height: 24),
          FilledButton(
                      style: freightFilledWide,
key: const Key('freight_trip_save'),
            onPressed: _saving ? null : _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final depart = _iso(_depart.text);
    final returns = _iso(_returns.text);
    if (depart == null || returns == null) return;
    setState(() => _saving = true);
    final ok = await submitFreight(
      context,
      SaveFreightTrip(name: _name.text, departOn: depart, returnOn: returns),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }
}

class FreightJobFormPage extends StatefulWidget {
  const FreightJobFormPage({super.key, this.tripId});

  final String? tripId;

  @override
  State<FreightJobFormPage> createState() => _FreightJobFormPageState();
}

class _FreightJobFormPageState extends State<FreightJobFormPage> {
  final _description = TextEditingController();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _price = TextEditingController();
  final _date = TextEditingController();
  FreightDirection _direction = FreightDirection.outbound;
  String? _customerId;
  String? _tripId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
    final ledger = context.read<FreightBloc>().state.ledger;
    final trip = ledger?.trips.where((item) => item.id == _tripId).firstOrNull;
    _date.text = freightDayLabel(
      trip?.departOn ?? freightIsoDate(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _pickup.dispose();
    _dropoff.dispose();
    _price.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FreightBloc>().state;
    final people = state.people;
    final trips = state.ledger?.trips ?? const <FreightTrip>[];
    return Scaffold(
      backgroundColor: freightCanvas,
      appBar: freightBar('Novo frete'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('freight_customer'),
            initialValue: _customerId,
            decoration: freightField('Cliente'),
            items: [
              for (final person in people)
                DropdownMenuItem(value: person.id, child: Text(person.name)),
            ],
            onChanged: (value) => setState(() => _customerId = value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: freightBlue),
              onPressed: () async {
                final saved = await Navigator.of(context)
                    .pushNamed<bool>(CustomerRoutes.create);
                if (saved == true && context.mounted) {
                  context.read<FreightBloc>().add(const FreightRequested());
                }
              },
              child: const Text('Novo cliente'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final direction in FreightDirection.values)
                ChoiceChip(
                  label: Text(
                    freightDirectionLabel(direction),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _direction == direction
                          ? freightAccent
                          : freightInk,
                    ),
                  ),
                  selected: _direction == direction,
                  selectedColor: freightSoft,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  side: BorderSide(
                    color: _direction == direction
                        ? freightBlue
                        : const Color(0xFFE4E7EB),
                  ),
                  onSelected: (_) => setState(() {
                    _direction = direction;
                    if (direction == FreightDirection.local) _tripId = null;
                  }),
                ),
            ],
          ),
          if (_direction != FreightDirection.local) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('freight_trip'),
              initialValue: _tripId,
              decoration: freightField('Viagem'),
              items: [
                for (final trip in trips)
                  DropdownMenuItem(value: trip.id, child: Text(trip.name)),
              ],
              onChanged: (value) => setState(() => _tripId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_description'),
            controller: _description,
            decoration: freightField('Descrição da carga'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_pickup'),
            controller: _pickup,
            decoration: freightField('Retirada'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_dropoff'),
            controller: _dropoff,
            decoration: freightField('Entrega'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_date'),
            controller: _date,
            decoration: freightField('Data prevista'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('freight_price'),
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: freightField('Valor do frete'),
          ),
          const SizedBox(height: 24),
          FilledButton(
                      style: freightFilledWide,
key: const Key('freight_job_save'),
            onPressed: _saving ? null : () => _save(draft: false),
            child: const Text('Salvar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: freightAccent),
            onPressed: _saving ? null : () => _save(draft: true),
            child: const Text('Salvar rascunho'),
          ),
        ],
      ),
    );
  }

  Future<void> _save({required bool draft}) async {
    final people = context.read<FreightBloc>().state.people;
    final person = people.where((item) => item.id == _customerId).firstOrNull;
    if (person == null) return;
    final planned = _iso(_date.text) ?? '';
    final cents = parseFreightCents(_price.text) ?? 0;
    var allowZero = false;
    if (!draft && cents == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Frete sem valor'),
            content: const Text('Confirmar este frete com valor zero?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                      style: freightFilled,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      allowZero = true;
    }
    setState(() => _saving = true);
    final ok = await submitFreight(
      context,
      SaveFreightJob(
        customerId: person.id,
        customerName: person.name,
        tripId: _direction == FreightDirection.local ? null : _tripId,
        direction: _direction,
        description: _description.text,
        pickup: _pickup.text,
        dropoff: _dropoff.text,
        plannedOn: planned,
        priceCents: cents,
        draft: draft,
        allowZero: allowZero,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }
}

String _month(DateTime date) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return months[date.month - 1];
}

String? _iso(String text) {
  final parts = text.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return freightIsoDate(DateTime(year, month, day));
}
