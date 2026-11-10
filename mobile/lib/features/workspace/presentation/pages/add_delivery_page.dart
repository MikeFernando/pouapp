import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/entities/customer_address.dart';
import '../../../customers/domain/usecases/address_use_cases.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../domain/entities/street_ledger.dart';
import '../../domain/usecases/home_use_cases.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';
import '../street_actions.dart';

/// Chooses people who will receive a delivery and puts them on today's route.
///
/// With the remote API, creates a draft note due today and refreshes the home.
class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key, this.onRemoteAdded});

  final VoidCallback? onRemoteAdded;

  @override
  State<AddDeliveryPage> createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  var _loading = true;
  var _failed = false;
  var _customers = const <Customer>[];
  var _addingId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetCustomers>()(
      const CustomerQuery(status: CustomerStatus.active, pageSize: 100),
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _loading = false;
        _failed = true;
      }),
      (page) => setState(() {
        _loading = false;
        _customers = page.items;
      }),
    );
  }

  Future<void> _add(Customer customer) async {
    if (ApiConfig.useRemoteApi) {
      await _addRemote(customer);
      return;
    }

    setState(() => _addingId = customer.id);
    final addresses = await sl<GetCustomerAddresses>()(customer.id);
    if (!mounted) return;
    final address = addresses.fold((_) => '', _addressLine);
    final saved = await applyStreetChange(
      context,
      AddRouteVisit(
        customerId: customer.id,
        customerName: customer.name,
        address: address.isEmpty ? 'Endereço não informado' : address,
        reasons: const [VisitReason.delivery],
      ),
    );
    if (!mounted) return;
    setState(() => _addingId = '');
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} entrou na lista.')),
      );
    }
  }

  Future<void> _addRemote(Customer customer) async {
    final amount = await _askAmount(customer.name);
    if (amount == null || !mounted) return;

    setState(() => _addingId = customer.id);
    final today = isoDate(DateTime.now());
    final result = await sl<CreateHomeNote>()(
      customerId: customer.id,
      dueOn: today,
      totalCents: amount,
    );
    if (!mounted) return;
    setState(() => _addingId = '');

    final ok = result.fold((_) => false, (_) => true);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar na home.')),
      );
      return;
    }

    if (context.mounted && ApiConfig.useRemoteApi) {
      context.read<HomeBoardBloc>().add(const HomeBoardRequested());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${customer.name} entrou nos recebimentos de hoje.')),
    );
    widget.onRemoteAdded?.call();
  }

  Future<int?> _askAmount(String customerName) async {
    final controller = TextEditingController(text: '10,00');
    final amount = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Valor para $customerName'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Valor (R\$)',
              hintText: '10,00',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final cents = _parseBrlToCents(controller.text);
                if (cents == null || cents <= 0) return;
                Navigator.of(context).pop(cents);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> onRoute;
    if (ApiConfig.useRemoteApi) {
      final board = context.watch<HomeBoardBloc>().state.board;
      onRoute = {
        if (board != null)
          for (final item in board.receiptsDueToday) item.customerId,
      };
    } else {
      onRoute = context.select<CompanyOperationBloc, Set<String>>((bloc) {
        final ledger = bloc.state.operation?.street;
        if (ledger == null) return const {};
        return {
          for (final visit in visitsOnDay(ledger, ledger.day))
            if (visit.status != VisitStatus.missed) visit.customerId,
        };
      });
    }

    final available = [
      for (final customer in _customers)
        if (!onRoute.contains(customer.id)) customer,
    ];

    return ColoredBox(
      color: const Color(0xFFF6F5F7),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? const Center(child: Text('Não foi possível carregar as pessoas.'))
          : available.isEmpty
          ? const Center(
              child: Text('Todas as pessoas já estão na lista de hoje.'),
            )
          : ListView(
              key: const Key('add_delivery_list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    ApiConfig.useRemoteApi
                        ? 'Escolha quem entra nos recebimentos de hoje.'
                        : 'Escolha quem vai receber a entrega.',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final customer in available)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: Key('delivery_person_${customer.id}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: _addingId.isEmpty ? () => _add(customer) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                color: pouAppBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_addingId == customer.id)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _addressLine(List<CustomerAddress> addresses) {
  if (addresses.isEmpty) return '';
  final primary = addresses.firstWhere(
    (address) => address.isPrimary,
    orElse: () => addresses.first,
  );
  final street = '${primary.street}, ${primary.number}'.trim();
  final place = primary.neighborhood.trim();
  if (place.isEmpty) return street;
  return '$street · $place';
}

int? _parseBrlToCents(String raw) {
  final cleaned = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (cleaned.isEmpty) return null;
  final normalized = cleaned.contains(',')
      ? cleaned.replaceAll('.', '').replaceAll(',', '.')
      : cleaned;
  final value = double.tryParse(normalized);
  if (value == null) return null;
  return (value * 100).round();
}
