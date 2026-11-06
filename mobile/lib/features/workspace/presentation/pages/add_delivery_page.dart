import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/entities/customer_address.dart';
import '../../../customers/domain/usecases/address_use_cases.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../domain/entities/street_ledger.dart';
import '../bloc/company_operation_bloc.dart';
import '../street_actions.dart';

/// Chooses people who will receive a delivery and puts them on today's route.
class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final onRoute = context.select<CompanyOperationBloc, Set<String>>((bloc) {
      final ledger = bloc.state.operation?.street;
      if (ledger == null) return const {};
      return {
        for (final visit in visitsOnDay(ledger, ledger.day))
          if (visit.status != VisitStatus.missed) visit.customerId,
      };
    });
    final available = [
      for (final customer in _customers)
        if (!onRoute.contains(customer.id)) customer,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Nova venda'),
      ),
      body: _loading
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    'Escolha quem vai receber a entrega.',
                    style: TextStyle(
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
                                color: Color(0xFF1E88E5),
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
