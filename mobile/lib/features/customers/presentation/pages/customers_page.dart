import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_alphabet_index.dart';
import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart' as di;
import '../../../workspace/data/receivable_store.dart';
import '../../../workspace/domain/entities/street_ledger.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customers_bloc.dart';
import '../customer_messages.dart';
import '../customer_routes.dart';
import '../widgets/customer_new_sheet.dart';
import '../widgets/customer_status_badge.dart';

enum _CustomerListMode {
  all,
  buyMore,
  buyLess,
  lateHistory,
  active,
  inactive,
}

extension on _CustomerListMode {
  String get label => switch (this) {
    _CustomerListMode.all => '#Todos',
    _CustomerListMode.buyMore => '#CompramMais',
    _CustomerListMode.buyLess => '#CompramMenos',
    _CustomerListMode.lateHistory => '#Atrasos',
    _CustomerListMode.active => '#Ativos',
    _CustomerListMode.inactive => '#Desativados',
  };

  String get keyName => switch (this) {
    _CustomerListMode.all => 'all',
    _CustomerListMode.buyMore => 'buy_more',
    _CustomerListMode.buyLess => 'buy_less',
    _CustomerListMode.lateHistory => 'late',
    _CustomerListMode.active => 'active',
    _CustomerListMode.inactive => 'inactive',
  };
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          di.sl<CustomersBloc>()..add(const CustomersFilterChanged(null)),
      child: const PeopleCustomersView(),
    );
  }
}

class PeopleCustomersView extends StatefulWidget {
  const PeopleCustomersView({super.key});

  @override
  State<PeopleCustomersView> createState() => _PeopleCustomersViewState();
}

class _PeopleCustomersViewState extends State<PeopleCustomersView> {
  final _search = TextEditingController();
  String? _filterLetter;
  var _scrubbing = false;
  var _mode = _CustomerListMode.all;
  var _purchaseCents = const <String, int>{};
  var _lateCount = const <String, int>{};
  var _lateCents = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _loadRanks();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    if (!di.sl.isRegistered<ReceivableStore>()) return;
    final sales = await di.sl<ReceivableStore>().postedSales();
    final today = isoDate(DateTime.now());
    final purchase = <String, int>{};
    final lateCount = <String, int>{};
    final lateCents = <String, int>{};
    for (final sale in sales) {
      if (sale.sale) {
        purchase[sale.customerId] =
            (purchase[sale.customerId] ?? 0) + sale.totalCents;
      }
      final due = sale.dueOn;
      if (due == null || due.compareTo(today) >= 0) continue;
      lateCount[sale.customerId] = (lateCount[sale.customerId] ?? 0) + 1;
      if (sale.openCents > 0) {
        lateCents[sale.customerId] =
            (lateCents[sale.customerId] ?? 0) + sale.openCents;
      }
    }
    if (!mounted) return;
    setState(() {
      _purchaseCents = purchase;
      _lateCount = lateCount;
      _lateCents = lateCents;
    });
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

  void _selectMode(_CustomerListMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _filterLetter = null;
      _scrubbing = false;
    });
    final status = switch (mode) {
      _CustomerListMode.active => CustomerStatus.active,
      _CustomerListMode.inactive => CustomerStatus.inactive,
      _ => null,
    };
    context.read<CustomersBloc>().add(CustomersFilterChanged(status));
  }

  List<Customer> _visible(List<Customer> items) {
    final letter = _filterLetter;
    final filtered = [
      for (final customer in items)
        if ((letter == null || pouAlphabetInitial(customer.name) == letter) &&
            (_mode != _CustomerListMode.lateHistory ||
                (_lateCount[customer.id] ?? 0) > 0))
          customer,
    ];
    filtered.sort(_compare);
    return filtered;
  }

  int _compare(Customer a, Customer b) {
    switch (_mode) {
      case _CustomerListMode.buyMore:
        final byPurchase =
            (_purchaseCents[b.id] ?? 0).compareTo(_purchaseCents[a.id] ?? 0);
        if (byPurchase != 0) return byPurchase;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _CustomerListMode.buyLess:
        final byPurchase =
            (_purchaseCents[a.id] ?? 0).compareTo(_purchaseCents[b.id] ?? 0);
        if (byPurchase != 0) return byPurchase;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _CustomerListMode.lateHistory:
        final byLate =
            (_lateCount[b.id] ?? 0).compareTo(_lateCount[a.id] ?? 0);
        if (byLate != 0) return byLate;
        final byCents =
            (_lateCents[b.id] ?? 0).compareTo(_lateCents[a.id] ?? 0);
        if (byCents != 0) return byCents;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _CustomerListMode.all:
      case _CustomerListMode.active:
      case _CustomerListMode.inactive:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    key: const Key('customer_search'),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                    onChanged: (value) {
                      context.read<CustomersBloc>().add(
                        CustomersSearchChanged(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    key: const Key('customers_filters'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    children: [
                      for (final mode in _CustomerListMode.values) ...[
                        if (mode != _CustomerListMode.values.first)
                          const SizedBox(width: 8),
                        Material(
                          color: _mode == mode ? pouBrand : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            key: Key('customers_filter_${mode.keyName}'),
                            onTap: () => _selectMode(mode),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _mode == mode
                                      ? pouBrand
                                      : const Color(0xFFE9E8EB),
                                ),
                              ),
                              child: Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _mode == mode
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: _mode == mode
                                      ? Colors.white
                                      : const Color(0xFF0E0D0F),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: BlocBuilder<CustomersBloc, CustomersState>(
                    builder: (context, state) {
                      if (state.items.isEmpty &&
                          (state.status == CustomersStatus.initial ||
                              state.status == CustomersStatus.loading)) {
                        return const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Carregando clientes',
                          ),
                        );
                      }
                      if (state.status == CustomersStatus.failure &&
                          state.items.isEmpty) {
                        return _CustomersMessage(
                          message:
                              state.message ??
                              'Não foi possível carregar os clientes.',
                          onRetry: () => context.read<CustomersBloc>().add(
                            const CustomersRequested(),
                          ),
                        );
                      }
                      if (state.items.isEmpty) {
                        return const _CustomersMessage(
                          key: Key('customer_empty'),
                          message: 'Nenhum cliente encontrado.',
                        );
                      }
                      final visible = _visible(state.items);
                      final letter = _filterLetter;
                      return Stack(
                        children: [
                          if (visible.isEmpty && letter == null)
                            Center(
                              child: Text(
                                _mode == _CustomerListMode.lateHistory
                                    ? 'Nenhum atraso registrado.'
                                    : 'Nenhum cliente encontrado.',
                                key: const Key('customers_letter_empty'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            )
                          else if (visible.isNotEmpty)
                            ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 28, 88),
                              children: [
                                Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < visible.length;
                                        index++
                                      ) ...[
                                        if (index > 0)
                                          const Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Color(0xFFE9E8EB),
                                          ),
                                        ListTile(
                                          key: Key(
                                            'customer_${visible[index].id}',
                                          ),
                                          title: Text(
                                            visible[index].name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0E0D0F),
                                            ),
                                          ),
                                          trailing: CustomerStatusBadge(
                                            status: visible[index].status,
                                            compact: true,
                                          ),
                                          onTap: () => _openDetails(
                                            context,
                                            visible[index].id,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (letter != null &&
                              (visible.isEmpty || _scrubbing))
                            IgnorePointer(
                              child: Center(
                                child: PouAlphabetLetterPreview(
                                  key: Key(
                                    visible.isEmpty
                                        ? 'customers_letter_empty'
                                        : 'customers_letter_scrub',
                                  ),
                                  letter: letter,
                                  faint: visible.isNotEmpty,
                                ),
                              ),
                            ),
                          Positioned(
                            key: const Key('customers_alphabet'),
                            right: 0,
                            top: 8,
                            bottom: 8,
                            child: PouAlphabetIndex(
                              keyPrefix: 'customers',
                              activeLetter: _filterLetter,
                              scrubbing: _scrubbing,
                              onDragLetter: _setLetter,
                              onTapLetter: _tapLetter,
                              onDragEnd: _endScrub,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 0,
              child: FloatingActionButton(
                key: const Key('customer_add'),
                heroTag: 'customer_add',
                tooltip: 'Novo cliente',
                backgroundColor: pouBrand,
                foregroundColor: Colors.white,
                onPressed: () => _openForm(context),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, String id) async {
    await Navigator.of(context).pushNamed(CustomerRoutes.details(id));
    if (context.mounted) {
      context.read<CustomersBloc>().add(const CustomersRefreshRequested());
      await _loadRanks();
    }
  }

  Future<void> _openForm(BuildContext context) async {
    final savedId = await showNewCustomerSheet(context);
    if (savedId != null && context.mounted) {
      _notifySaved(context);
      await _loadRanks();
    }
  }
}

class CustomersView extends StatefulWidget {
  const CustomersView({super.key});

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pouLeafChrome,
      appBar: pouLeafAppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('customer_add'),
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cliente'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('customer_search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Pesquisar clientes',
                  hintText: 'Nome, telefone ou documento',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _searchController.clear();
                      context.read<CustomersBloc>().add(
                        const CustomersSearchChanged(''),
                      );
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
                onSubmitted: (value) {
                  context.read<CustomersBloc>().add(
                    CustomersSearchChanged(value),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BlocBuilder<CustomersBloc, CustomersState>(
                buildWhen: (previous, current) =>
                    previous.query.status != current.query.status,
                builder: (context, state) {
                  return Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        key: const Key('customer_filter_active'),
                        label: const Text('Ativos'),
                        selected: state.query.status == CustomerStatus.active,
                        onSelected: (_) => _filter(CustomerStatus.active),
                      ),
                      FilterChip(
                        key: const Key('customer_filter_all'),
                        label: const Text('Todos'),
                        selected: state.query.status == null,
                        onSelected: (_) => _filter(null),
                      ),
                      FilterChip(
                        key: const Key('customer_filter_inactive'),
                        label: const Text('Desativados'),
                        selected: state.query.status == CustomerStatus.inactive,
                        onSelected: (_) => _filter(CustomerStatus.inactive),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  if (state.items.isEmpty &&
                      (state.status == CustomersStatus.initial ||
                          state.status == CustomersStatus.loading)) {
                    return const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Carregando clientes',
                      ),
                    );
                  }
                  if (state.status == CustomersStatus.failure &&
                      state.items.isEmpty) {
                    return _CustomersMessage(
                      message:
                          state.message ??
                          'Não foi possível carregar os clientes.',
                      onRetry: () => context.read<CustomersBloc>().add(
                        const CustomersRequested(),
                      ),
                    );
                  }
                  if (state.items.isEmpty) {
                    return const _CustomersMessage(
                      key: Key('customer_empty'),
                      message: 'Nenhum cliente encontrado.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<CustomersBloc>().add(
                        const CustomersRefreshRequested(),
                      );
                      await context.read<CustomersBloc>().stream.firstWhere(
                        (next) =>
                            next.status == CustomersStatus.success ||
                            next.status == CustomersStatus.failure,
                      );
                    },
                    child: ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE9E8EB),
                      ),
                      itemBuilder: (context, index) {
                        if (index >= state.items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(
                              key: const Key('customer_load_more'),
                              onPressed:
                                  state.status == CustomersStatus.loadingMore
                                  ? null
                                  : () => context.read<CustomersBloc>().add(
                                      const CustomersLoadMoreRequested(),
                                    ),
                              child: state.status == CustomersStatus.loadingMore
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Carregar mais'),
                            ),
                          );
                        }
                        final customer = state.items[index];
                        return _CustomerTile(customer: customer);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filter(CustomerStatus? status) {
    context.read<CustomersBloc>().add(CustomersFilterChanged(status));
  }

  Future<void> _openForm(BuildContext context) async {
    final savedId = await showNewCustomerSheet(context);
    if (savedId != null && context.mounted) {
      _notifySaved(context);
    }
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final phone = primaryPhone(customer);
    final document = formatDocument(customer.document);
    final details = [
      if ((customer.tradeName ?? '').isNotEmpty) customer.tradeName!,
      if (phone.isNotEmpty) phone,
      if (document.isNotEmpty) document,
      customerTypeLabel(customer.type),
    ].join(' · ');

    return ListTile(
      key: Key('customer_${customer.id}'),
      title: Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: details.length > 48,
      trailing: CustomerStatusBadge(
        status: customer.status,
        compact: true,
      ),
      onTap: () async {
        await Navigator.of(context)
            .pushNamed(CustomerRoutes.details(customer.id));
        if (context.mounted) {
          context.read<CustomersBloc>().add(const CustomersRefreshRequested());
        }
      },
    );
  }
}

class _CustomersMessage extends StatelessWidget {
  const _CustomersMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('customer_retry'),
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _notifySaved(BuildContext context) {
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Cliente salvo.')));
  context.read<CustomersBloc>().add(const CustomersRefreshRequested());
}
