import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/pou_app_colors.dart';

import '../../../../injection_container.dart' as di;
import '../../domain/entities/customer.dart';
import '../bloc/customers_bloc.dart';
import '../customer_messages.dart';
import '../customer_routes.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<CustomersBloc>()..add(const CustomersRequested()),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F7),
      body: SafeArea(
        child: Column(
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
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < state.items.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFE9E8EB),
                                ),
                              ListTile(
                                key: Key('customer_${state.items[index].id}'),
                                title: Text(
                                  state.items[index].name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0E0D0F),
                                  ),
                                ),
                                onTap: () => _openDetails(
                                  context,
                                  state.items[index].id,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  key: const Key('customer_add'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pouInk,
                    side: const BorderSide(color: pouInk),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _openForm(context),
                  child: const Text('Novo Cliente'),
                ),
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
    }
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await Navigator.of(context)
        .pushNamed<bool>(CustomerRoutes.create);
    if (saved == true && context.mounted) {
      _notifySaved(context);
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
      appBar: AppBar(backgroundColor: pouAppBlue, foregroundColor: pouCanvas, title: const Text('Clientes')),
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
                        label: const Text('Inativos'),
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
    final saved = await Navigator.of(context)
        .pushNamed<bool>(CustomerRoutes.create);
    if (saved == true && context.mounted) {
      _notifySaved(context);
    }
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      trailing: Text(
        customerStatusLabel(customer.status),
        style: theme.textTheme.labelLarge?.copyWith(
          color: customer.status == CustomerStatus.active
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
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
