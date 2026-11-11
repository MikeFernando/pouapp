import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_alphabet_index.dart';
import '../../../../app/pou_app_colors.dart';
import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../../customers/presentation/widgets/customer_new_sheet.dart';
import '../../domain/entities/street_ledger.dart';
import '../bloc/company_operation_bloc.dart';
import '../bloc/home_board_bloc.dart';

/// Lista clientes para iniciar uma venda: ao tocar, abre a ficha do cliente.
class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key, required this.onOpenCustomer});

  final ValueChanged<String> onOpenCustomer;

  @override
  State<AddDeliveryPage> createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  final _search = TextEditingController();
  var _loading = true;
  var _failed = false;
  var _customers = const <Customer>[];
  String? _filterLetter;
  var _scrubbing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
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

  Future<void> _openNewCustomer() async {
    final saved = await showNewCustomerSheet(context);
    if (saved == true && mounted) {
      await _load();
    }
  }

  void _setLetter(String? letter) {
    if (_filterLetter == letter && _scrubbing) return;
    setState(() {
      _filterLetter = letter;
      _scrubbing = true;
    });
  }

  void _tapLetter(String letter) {
    if (_filterLetter == letter) {
      setState(() {
        _filterLetter = null;
        _scrubbing = false;
      });
      return;
    }
    setState(() {
      _filterLetter = letter;
      _scrubbing = false;
    });
  }

  void _endScrub() {
    if (!_scrubbing) return;
    setState(() => _scrubbing = false);
  }

  List<Customer> _filteredCustomers() {
    final query = _search.text.trim().toLowerCase();
    final letter = _filterLetter;
    return [
      for (final customer in _customers)
        if ((letter == null || pouAlphabetInitial(customer.name) == letter) &&
            (query.isEmpty || _matchesSearch(customer, query)))
          customer,
    ];
  }

  bool _matchesSearch(Customer customer, String query) {
    final name = customer.name.toLowerCase();
    final trade = (customer.tradeName ?? '').toLowerCase();
    final phone = [
      customer.mobilePhone ?? '',
      customer.phone ?? '',
    ].join(' ').replaceAll(RegExp(r'\D'), '');
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return name.contains(query) ||
        trade.contains(query) ||
        (digits.isNotEmpty && phone.contains(digits));
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

    final available = _filteredCustomers();
    final searching = _search.text.trim().isNotEmpty;
    final letter = _filterLetter;

    return ColoredBox(
      color: const Color(0xFFF6F5F7),
      child: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? const Center(
                    child: Text('Não foi possível carregar as pessoas.'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: TextField(
                          key: const Key('add_delivery_search'),
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0E0D0F),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar cliente',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 28,
                              color: Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
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
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: _customers.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum cliente ativo cadastrado.',
                                ),
                              )
                            : Stack(
                                children: [
                                  if (available.isEmpty && letter == null)
                                    Center(
                                      child: Text(
                                        searching
                                            ? 'Nenhum cliente encontrado.'
                                            : 'Nenhum cliente ativo cadastrado.',
                                        key: const Key(
                                          'add_delivery_search_empty',
                                        ),
                                      ),
                                    )
                                  else if (available.isNotEmpty)
                                    ListView(
                                      key: const Key('add_delivery_list'),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        28,
                                        88,
                                      ),
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            4,
                                            0,
                                            4,
                                            12,
                                          ),
                                          child: Text(
                                            'Escolha o cliente da venda.',
                                            style: TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        for (final customer in available)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Material(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: InkWell(
                                                key: Key(
                                                  'delivery_person_${customer.id}',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: () =>
                                                    widget.onOpenCustomer(
                                                      customer.id,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
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
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      if (onRoute.contains(
                                                        customer.id,
                                                      ))
                                                        const Text(
                                                          'Na home',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFF6B7280,
                                                            ),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
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
                                  if (letter != null &&
                                      (available.isEmpty || _scrubbing))
                                    IgnorePointer(
                                      child: Center(
                                        child: PouAlphabetLetterPreview(
                                          key: Key(
                                            available.isEmpty
                                                ? 'add_delivery_letter_empty'
                                                : 'add_delivery_letter_scrub',
                                          ),
                                          letter: letter,
                                          faint: available.isNotEmpty,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    key: const Key('add_delivery_alphabet'),
                                    right: 0,
                                    top: 8,
                                    bottom: 88,
                                    child: PouAlphabetIndex(
                                      keyPrefix: 'add_delivery',
                                      activeLetter: _filterLetter,
                                      scrubbing: _scrubbing,
                                      onDragLetter: _setLetter,
                                      onTapLetter: _tapLetter,
                                      onDragEnd: _endScrub,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
          if (!_loading && !_failed)
            Positioned(
              right: 20,
              bottom: 16,
              child: FloatingActionButton(
                key: const Key('add_delivery_new_customer'),
                heroTag: 'add_delivery_new_customer',
                tooltip: 'Novo cliente',
                backgroundColor: pouBrand,
                foregroundColor: Colors.white,
                onPressed: _openNewCustomer,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }
}
