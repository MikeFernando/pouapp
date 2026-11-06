import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../catalog/domain/entities/catalog.dart';
import '../../catalog/domain/repositories/catalog_repository.dart';
import '../../customers/data/datasources/customer_local_data_source.dart';
import '../../customers/domain/entities/customer_note.dart';
import '../../customers/domain/repositories/customer_note_repository.dart';
import '../../workspace/data/delivery_store.dart';
import '../../workspace/data/receivable_store.dart';
import '../../workspace/domain/entities/receivable.dart';
import '../../workspace/domain/entities/street_ledger.dart';
import '../domain/entities/voice_command.dart';
import '../domain/repositories/voice_repository.dart';
import '../domain/rules/voice_dates.dart';
import '../domain/rules/voice_interpreter.dart';
import '../domain/rules/voice_resolver.dart';
import '../domain/voice_text.dart';

const _samePerson = {
  'ela',
  'ele',
  'dela',
  'dele',
  'essa',
  'esse',
  'essa cliente',
  'esse cliente',
  'a cliente',
  'o cliente',
  'essa nota',
  'a nota',
  'nesse cliente',
  'nesta cliente',
  'neste cliente',
  'nessa cliente',
  'nesta nota',
  'nessa nota',
  'desta nota',
  'dessa nota',
};

class VoiceRepositoryImpl implements VoiceRepository {
  VoiceRepositoryImpl({
    required this.customers,
    required this.catalog,
    required this.notes,
    required this.receivables,
    required this.deliveries,
    required this.openCatalog,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CustomerLocalDataSource customers;
  final CatalogRepository catalog;
  final CustomerNoteRepository notes;
  final ReceivableStore receivables;
  final DeliveryStore deliveries;
  final Future<Database> Function() openCatalog;
  final Map<String, _VoicePay> _payments = {};
  final DateTime Function() _clock;
  final Map<String, Future<Either<Failure, VoiceOutcome>>> _runs = {};
  var _localIds = 0;

  @override
  Future<Either<Failure, VoiceOutcome>> submit({
    required String transcript,
    required String executionId,
    VoiceCommand? pending,
    String? choiceId,
    DateTime? today,
    String? contextCustomerId,
    String? contextLabel,
    bool contextFresh = false,
  }) {
    final id = _executionId(executionId);
    final current = _runs[id];
    if (current != null) return current;
    final run = _submit(
      transcript: transcript,
      executionId: id,
      pending: pending,
      choiceId: choiceId,
      today: today,
      contextCustomerId: contextCustomerId,
      contextLabel: contextLabel,
      contextFresh: contextFresh,
    );
    _runs[id] = run;
    return run.whenComplete(() => _runs.remove(id));
  }

  String _executionId(String executionId) {
    final trimmed = executionId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    _localIds += 1;
    return 'exec-${_clock().microsecondsSinceEpoch}-$_localIds';
  }

  Future<Either<Failure, VoiceOutcome>> _submit({
    required String transcript,
    required String executionId,
    VoiceCommand? pending,
    String? choiceId,
    DateTime? today,
    String? contextCustomerId,
    String? contextLabel,
    bool contextFresh = false,
  }) async {
    try {
      final heard = _command(transcript, pending, choiceId);
      final continued = _continueVisit(
        heard,
        contextCustomerId: contextCustomerId,
        contextLabel: contextLabel,
        contextFresh: contextFresh,
      );
      if (continued != null) return Right(continued);
      var command = _bindVisit(heard, contextCustomerId);
      if (command.intent == VoiceIntent.unsupported ||
          command.intent == VoiceIntent.unclear) {
        final reply = command.reply ?? 'Não entendi o comando.';
        return Right(
          VoiceOutcome(
            kind: command.intent == VoiceIntent.unsupported
                ? VoiceOutcomeKind.unsupported
                : VoiceOutcomeKind.blocked,
            message: reply,
            understood: reply,
            spoken: reply,
            command: command,
          ),
        );
      }
      final people = await _people();
      final goods = await _goods();
      final aliases = await _aliases();
      command = _attachLoose(command, goods);
      if (command.intent == VoiceIntent.setDueDate) {
        return Right(await _setDue(command, today ?? _clock()));
      }
      if (command.intent == VoiceIntent.arrangePayment) {
        return Right(await _arrangePayment(command));
      }
      if (command.intent == VoiceIntent.reviewDelivery) {
        return Right(await _reviewDelivery(command, today ?? _clock()));
      }
      final resolution = resolveVoice(
        command: command,
        people: people,
        goods: goods,
        aliases: aliases,
      );
      if (command.items.length > 1) {
        return Right(
          await _addMany(command, people, goods, aliases, executionId),
        );
      }
      if (command.intent == VoiceIntent.consultAccount) {
        if (resolution.customer == null) {
          return Right(_clarify(command, resolution));
        }
        final account = await _account(resolution.customer!, today ?? _clock());
        final spoken = _speakAccount(account);
        return Right(
          VoiceOutcome(
            kind: VoiceOutcomeKind.completed,
            message: spoken,
            understood: 'Consultar a conta de ${account.name}',
            spoken: spoken,
            account: account,
            command: command,
            subjectId: account.customerId,
            subjectName: account.name,
            subjectPlace: account.neighborhood,
          ),
        );
      }
      if (command.intent == VoiceIntent.repriceDraftItem) {
        if (!resolution.readyToReprice) {
          return Right(_clarify(command, resolution));
        }
        return Right(await _reprice(command, resolution, executionId));
      }
      if (!resolution.readyToAdd) {
        return Right(_clarify(command, resolution));
      }
      return Right(await _add(command, resolution, executionId));
    } on CacheException {
      return const Left(CacheFailure());
    } on DatabaseException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, VoiceOutcome>> undo(String executionId) async {
    try {
      final db = await openCatalog();
      final rows = await db.query(
        'voice_commands',
        where: 'execution_id = ? OR execution_id LIKE ?',
        whereArgs: [executionId, '$executionId~%'],
        orderBy: 'execution_id ASC',
      );
      if (rows.isEmpty) {
        return const Right(
          VoiceOutcome(
            kind: VoiceOutcomeKind.blocked,
            message: 'Não encontrei esse comando para desfazer.',
            spoken: 'Não encontrei esse comando para desfazer.',
          ),
        );
      }
      if (rows.length > 1) {
        return Right(await _undoMany(db, rows));
      }
      final row = rows.single;
      if (row['undone'] == 1) {
        return const Right(
          VoiceOutcome(
            kind: VoiceOutcomeKind.repeated,
            message: 'Esse comando já foi desfeito.',
            spoken: 'Esse comando já foi desfeito.',
          ),
        );
      }
      final noteId = row['note_id']! as String;
      final lineId = row['line_id']! as String;
      final noteResult = await notes.note(noteId);
      final note = noteResult.fold(
        (failure) => throw failure,
        (value) => value,
      );
      if (note.status != NoteStatus.draft) {
        return const Right(
          VoiceOutcome(
            kind: VoiceOutcomeKind.blocked,
            message: 'A nota já foi entregue. O rascunho não foi alterado.',
            spoken: 'A nota já foi entregue. O rascunho não foi alterado.',
          ),
        );
      }
      NoteLine? line;
      for (final item in note.lines) {
        if (item.id == lineId) line = item;
      }
      final history = await db.query(
        'voice_commands',
        where: 'note_id = ? AND line_id = ?',
        whereArgs: [noteId, lineId],
        orderBy: 'recorded_at ASC, execution_id ASC',
      );
      final kind = row['command_kind'] as String? ?? 'add';
      if (kind == 'reprice') {
        return Right(await _undoReprice(db, row, note, line));
      }
      final practiced = row['unit_price_cents'] as int;
      final added = row['added_quantity'] as int;
      final beforeVoice = history.first['previous_quantity'] as int;
      final stillAdded = history
          .where((item) => item['undone'] != 1)
          .fold<int>(0, (sum, item) => sum + (item['added_quantity'] as int));
      final expected = beforeVoice + stillAdded;
      final currentLine = line;
      final same =
          currentLine != null &&
          currentLine.quantity == expected &&
          currentLine.unitPriceCents == practiced &&
          currentLine.quantity >= added;
      if (currentLine == null || !same) {
        return const Right(
          VoiceOutcome(
            kind: VoiceOutcomeKind.blocked,
            message: 'Esse item foi editado depois. As outras linhas da nota foram preservadas.',
            spoken: 'Esse item foi editado depois. As outras linhas da nota foram preservadas.',
          ),
        );
      }
      final restored = currentLine.quantity - added;
      final saved = await notes.saveLines(
        noteId: noteId,
        lines: [
          for (final item in note.lines)
            if (item.id == lineId && restored > 0)
              NoteLineDraft(
                id: item.id,
                productId: item.productId,
                name: item.name,
                unit: item.unit,
                quantity: restored,
                unitPriceCents: item.unitPriceCents,
                referencePriceCents: item.referencePriceCents,
              )
            else if (item.id != lineId)
              NoteLineDraft.fromLine(item),
        ],
      );
      if (saved.isLeft()) return const Left(CacheFailure());
      await db.update(
        'voice_commands',
        {'undone': 1},
        where: 'execution_id = ?',
        whereArgs: [executionId],
      );
      const message =
          'Desfiz o acréscimo desta solicitação. O restante da nota continua.';
      return const Right(
        VoiceOutcome(
          kind: VoiceOutcomeKind.undone,
          message: message,
          spoken: message,
        ),
      );
    } on Failure {
      return const Left(CacheFailure());
    } on DatabaseException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveAlias({
    required VoiceAliasKind kind,
    required String alias,
    required String target,
  }) async {
    final folded = foldVoice(alias);
    final meaning = target.trim();
    if (folded.isEmpty || meaning.isEmpty) {
      return const Left(CacheFailure());
    }
    try {
      var stored = meaning;
      if (kind == VoiceAliasKind.customer) {
        final people = await _people();
        final matches = [
          for (final person in people)
            if (person.id == meaning ||
                foldVoice(person.name) == foldVoice(meaning))
              person,
        ];
        if (matches.length != 1) return const Left(CacheFailure());
        stored = matches.single.id;
      }
      final db = await openCatalog();
      await db.insert('voice_aliases', {
        'id': 'alias-${kind.name}-$folded',
        'kind': kind.name,
        'alias': folded,
        'target': stored,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return const Right(unit);
    } on DatabaseException {
      return const Left(CacheFailure());
    }
  }

  Future<VoiceOutcome> _undoMany(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.any((row) => row['undone'] == 1)) {
      const message = 'Esse comando já foi desfeito.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.repeated,
        message: message,
        spoken: message,
      );
    }
    final noteId = rows.first['note_id']! as String;
    final noteResult = await notes.note(noteId);
    final note = noteResult.fold((failure) => throw failure, (value) => value);
    if (note.status != NoteStatus.draft) {
      const message = 'A nota já foi entregue. O rascunho não foi alterado.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: message,
      );
    }
    final subtract = <String, int>{};
    for (final row in rows) {
      final lineId = row['line_id']! as String;
      final added = row['added_quantity'] as int;
      final practiced = row['unit_price_cents'] as int;
      NoteLine? line;
      for (final item in note.lines) {
        if (item.id == lineId) line = item;
      }
      final history = await db.query(
        'voice_commands',
        where: 'note_id = ? AND line_id = ?',
        whereArgs: [noteId, lineId],
        orderBy: 'recorded_at ASC, execution_id ASC',
      );
      final beforeVoice = history.first['previous_quantity'] as int;
      final stillAdded = history
          .where((item) => item['undone'] != 1)
          .fold<int>(0, (sum, item) => sum + (item['added_quantity'] as int));
      final expected = beforeVoice + stillAdded;
      final current = line;
      final same =
          current != null &&
          current.quantity == expected &&
          current.unitPriceCents == practiced &&
          current.quantity >= added;
      if (current == null || !same) {
        const message =
            'Esse item foi editado depois. As outras linhas da nota foram preservadas.';
        return const VoiceOutcome(
          kind: VoiceOutcomeKind.blocked,
          message: message,
          spoken: message,
        );
      }
      subtract[lineId] = (subtract[lineId] ?? 0) + added;
    }
    final saved = await notes.saveLines(
      noteId: noteId,
      lines: [
        for (final item in note.lines)
          if ((subtract[item.id] ?? 0) == 0 ||
              item.quantity - subtract[item.id]! > 0)
            NoteLineDraft(
              id: item.id,
              productId: item.productId,
              name: item.name,
              unit: item.unit,
              quantity: item.quantity - (subtract[item.id] ?? 0),
              unitPriceCents: item.unitPriceCents,
              referencePriceCents: item.referencePriceCents,
            ),
      ],
    );
    if (saved.isLeft()) throw const CacheFailure();
    for (final row in rows) {
      await db.update(
        'voice_commands',
        {'undone': 1},
        where: 'execution_id = ?',
        whereArgs: [row['execution_id']],
      );
    }
    const message =
        'Desfiz o acréscimo desta solicitação. O restante da nota continua.';
    return const VoiceOutcome(
      kind: VoiceOutcomeKind.undone,
      message: message,
      spoken: message,
    );
  }

  Future<VoiceOutcome> _undoReprice(
    Database db,
    Map<String, Object?> row,
    CustomerNote note,
    NoteLine? line,
  ) async {
    final executionId = row['execution_id']! as String;
    final lineId = row['line_id']! as String;
    final newPrice = row['unit_price_cents'] as int;
    final previousPrice = row['previous_price_cents'] as int? ?? newPrice;
    final quantity = row['previous_quantity'] as int;
    final current = line;
    if (current == null ||
        current.unitPriceCents != newPrice ||
        current.quantity != quantity) {
      const message =
          'Esse item foi editado depois. As outras linhas da nota foram preservadas.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: message,
      );
    }
    final saved = await notes.saveLines(
      noteId: note.id,
      lines: [
        for (final item in note.lines)
          if (item.id == lineId)
            NoteLineDraft(
              id: item.id,
              productId: item.productId,
              name: item.name,
              unit: item.unit,
              quantity: item.quantity,
              unitPriceCents: previousPrice,
              referencePriceCents: item.referencePriceCents,
            )
          else
            NoteLineDraft.fromLine(item),
      ],
    );
    if (saved.isLeft()) throw CacheException();
    await db.update(
      'voice_commands',
      {'undone': 1},
      where: 'execution_id = ?',
      whereArgs: [executionId],
    );
    const message = 'Desfiz a alteração de preço desta solicitação.';
    return const VoiceOutcome(
      kind: VoiceOutcomeKind.undone,
      message: message,
      spoken: message,
    );
  }

  Future<CustomerNote?> _openDraft(String customerId) async {
    final db = await openCatalog();
    final rows = await db.query(
      'customer_notes',
      columns: ['id'],
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, NoteStatus.draft.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final result = await notes.note(rows.single['id']! as String);
    return result.fold((failure) => throw failure, (value) => value);
  }

  VoiceCommand _attachLoose(VoiceCommand command, List<VoiceGoods> goods) {
    if (command.intent == VoiceIntent.setDueDate ||
        command.intent == VoiceIntent.arrangePayment ||
        command.intent == VoiceIntent.reviewDelivery) {
      return command;
    }
    final phrase = command.looseText?.trim() ?? '';
    if (phrase.isEmpty || command.productId != null) return command;
    if ((command.productQuery ?? '').isNotEmpty) return command;
    VoiceGoods? best;
    for (final item in goods) {
      if (!item.active) continue;
      final name = foldVoice(item.name);
      if (name.isEmpty) continue;
      if (phrase != name && !phrase.endsWith(' $name')) continue;
      if (best == null || name.length > foldVoice(best.name).length) {
        best = item;
      }
    }
    if (best == null) {
      final parts = phrase.split(' ').where((part) => part.isNotEmpty).toList();
      if (parts.isEmpty) return command;
      final customer = _looseCustomer(
        parts.length == 1 ? '' : parts.sublist(0, parts.length - 1).join(' '),
      );
      return command.copyWith(
        customerQuery: (command.customerQuery ?? '').isEmpty
            ? customer
            : command.customerQuery,
        productQuery: parts.last,
      );
    }
    final name = foldVoice(best.name);
    final customer = _looseCustomer(
      phrase.substring(0, phrase.length - name.length).trim(),
    );
    return command.copyWith(
      customerQuery: (command.customerQuery ?? '').isEmpty
          ? customer
          : command.customerQuery,
      productId: best.id,
      productQuery: name,
    );
  }

  String? _looseCustomer(String value) {
    var customer = value.trim();
    if (customer.startsWith('cliente ')) {
      customer = customer.substring(8).trim();
    }
    if (customer == 'cliente') customer = '';
    return customer.isEmpty ? null : customer;
  }

  VoiceOutcome? _continueVisit(
    VoiceCommand command, {
    required String? contextCustomerId,
    required String? contextLabel,
    required bool contextFresh,
  }) {
    if (contextFresh || !_refersToVisit(command)) return null;
    final id = contextCustomerId?.trim() ?? '';
    if (id.isEmpty) return null;
    final label = (contextLabel ?? '').trim();
    final who = label.isEmpty ? 'a cliente atual' : label;
    return VoiceOutcome(
      kind: VoiceOutcomeKind.clarify,
      message: 'Continuo com $who?',
      understood: 'Continuo com $who?',
      spoken: 'Continuo com $who?',
      choices: [VoiceChoice(id: 'customer:$id', label: who)],
      command: command.copyWith(gap: VoiceGap.customer, clearCustomerId: true),
    );
  }

  VoiceCommand _bindVisit(VoiceCommand command, String? contextCustomerId) {
    final id = contextCustomerId?.trim() ?? '';
    if (id.isEmpty || !_refersToVisit(command)) return command;
    return command.copyWith(customerId: id);
  }

  bool _refersToVisit(VoiceCommand command) {
    if (command.customerId != null || command.gap != VoiceGap.none) {
      return false;
    }
    if (command.intent != VoiceIntent.addDraftItem &&
        command.intent != VoiceIntent.repriceDraftItem &&
        command.intent != VoiceIntent.consultAccount &&
        command.intent != VoiceIntent.reviewDelivery &&
        command.intent != VoiceIntent.setDueDate &&
        command.intent != VoiceIntent.arrangePayment) {
      return false;
    }
    final query = foldVoice(command.customerQuery ?? '');
    return query.isEmpty || _samePerson.contains(query);
  }

  VoiceCommand _command(
    String transcript,
    VoiceCommand? pending,
    String? choiceId,
  ) {
    if (choiceId != null && pending != null) {
      if (choiceId.startsWith('customer:')) {
        return pending.copyWith(
          customerId: choiceId.substring(9),
          gap: VoiceGap.none,
        );
      }
      if (choiceId.startsWith('product:')) {
        return pending.copyWith(
          productId: choiceId.substring(8),
          gap: VoiceGap.none,
        );
      }
      if (choiceId.startsWith('line:')) {
        return pending.copyWith(
          lineId: choiceId.substring(5),
          gap: VoiceGap.none,
        );
      }
      if (choiceId == 'price:unit' || choiceId == 'price:total') {
        return pending.copyWith(
          priceBasis: choiceId == 'price:total'
              ? VoicePriceBasis.total
              : VoicePriceBasis.perUnit,
          gap: VoiceGap.none,
        );
      }
    }
    if (pending == null) return interpretVoice(transcript);
    return continueVoiceCommand(pending, transcript);
  }

  VoiceOutcome _clarify(VoiceCommand command, VoiceResolution resolution) {
    final choices = <VoiceChoice>[];
    if (resolution.customers.length > 1) {
      for (final person in resolution.customers) {
        final place = (person.neighborhood ?? '').trim();
        choices.add(
          VoiceChoice(
            id: 'customer:${person.id}',
            label: place.isEmpty ? person.name : '${person.name} · $place',
          ),
        );
      }
    } else if (resolution.products.length > 1) {
      for (final item in resolution.products) {
        choices.add(VoiceChoice(id: 'product:${item.id}', label: item.name));
      }
    } else if (resolution.needsPriceBasis) {
      final per = resolution.product?.unit == CatalogUnit.kilogram
          ? 'quilo'
          : 'unidade';
      choices.add(VoiceChoice(id: 'price:unit', label: 'Preço por $per'));
      choices.add(const VoiceChoice(id: 'price:total', label: 'Preço total'));
    }
    final message = resolution.message ?? 'Preciso de um esclarecimento.';
    final gap = resolution.customer == null
        ? VoiceGap.customer
        : resolution.product == null
        ? VoiceGap.product
        : resolution.needsPriceBasis
        ? VoiceGap.price
        : resolution.needsUnit
        ? VoiceGap.unit
        : VoiceGap.quantity;
    return VoiceOutcome(
      kind: VoiceOutcomeKind.clarify,
      message: message,
      understood: message,
      spoken: message,
      choices: choices,
      command: command.copyWith(gap: gap),
    );
  }

  Future<VoiceOutcome> _add(
    VoiceCommand command,
    VoiceResolution resolution,
    String executionId,
  ) async {
    final customer = resolution.customer!;
    final product = resolution.product!;
    final quantity = resolution.quantity!;
    final db = await openCatalog();
    final existing = await db.query(
      'voice_commands',
      where: 'execution_id = ?',
      whereArgs: [executionId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      const message = 'Esta solicitação já foi gravada.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.repeated,
        message: message,
        understood: 'Adicionar ${product.name} para ${customer.name}',
        spoken: message,
        executionId: executionId,
        command: command.copyWith(gap: VoiceGap.none),
      );
    }
    final draftResult = await notes.activeDraft(customer.id);
    final draft = draftResult.fold(
      (failure) => throw failure,
      (value) => value,
    );
    NoteLine? current;
    late final int practiced;
    if (command.priceCents == null) {
      for (final line in draft.lines) {
        if (line.productId == product.id && line.unit == product.unit) {
          current = line;
          break;
        }
      }
      practiced = current?.unitPriceCents ?? product.salePriceCents;
    } else {
      practiced = _practicedCents(
        spokenCents: command.priceCents!,
        basis: command.priceBasis,
        unit: product.unit,
        quantity: quantity,
      );
      for (final line in draft.lines) {
        if (line.productId == product.id &&
            line.unit == product.unit &&
            line.unitPriceCents == practiced) {
          current = line;
          break;
        }
      }
    }
    final previous = current?.quantity ?? 0;
    final reference = current?.referencePriceCents ?? product.salePriceCents;
    final lineId = current?.id ?? 'voice-$executionId';
    final saved = await notes.saveLines(
      noteId: draft.id,
      lines: [
        for (final line in draft.lines)
          if (line.id == current?.id)
            NoteLineDraft(
              id: line.id,
              productId: line.productId,
              name: line.name,
              unit: line.unit,
              quantity: line.quantity + quantity,
              unitPriceCents: line.unitPriceCents,
              referencePriceCents: line.referencePriceCents,
            )
          else
            NoteLineDraft.fromLine(line),
        if (current == null)
          NoteLineDraft(
            id: lineId,
            productId: product.id,
            name: product.name,
            unit: product.unit,
            quantity: quantity,
            unitPriceCents: practiced,
            referencePriceCents: reference,
          ),
      ],
    );
    final note = saved.fold((failure) => throw failure, (value) => value);
    await db.insert('voice_commands', {
      'execution_id': executionId,
      'customer_id': customer.id,
      'note_id': note.id,
      'line_id': lineId,
      'product_id': product.id,
      'added_quantity': quantity,
      'previous_quantity': previous,
      'unit_price_cents': practiced,
      'previous_price_cents': practiced,
      'command_kind': 'add',
      'undone': 0,
      'recorded_at': _clock().toIso8601String(),
    });
    final priced = command.priceCents != null;
    final spoken = priced
        ? _pricedSpoken(
            product: product,
            quantity: quantity,
            priceCents: command.priceCents!,
            basis: command.priceBasis,
            customerName: customer.name,
          )
        : 'Anotei ${_quantitySpoken(product, quantity)} de ${product.name} para ${customer.name}.';
    final total = _money(note.totalCents);
    final message = priced
        ? spoken
        : '$spoken O rascunho ficou em $total. Isso ainda não é uma venda.';
    return VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message: message,
      understood: 'Adicionar ${product.name} para ${customer.name}',
      spoken: spoken,
      executionId: executionId,
      command: command.copyWith(gap: VoiceGap.none),
      subjectId: customer.id,
      subjectName: customer.name,
      subjectPlace: customer.neighborhood,
      openNote: true,
    );
  }

  Future<VoiceOutcome> _setDue(VoiceCommand command, DateTime today) async {
    final who = await _customerGate(command);
    if (who is VoiceOutcome) return who;
    final customerId = command.customerId!;
    final draft = await _openDraft(customerId);
    if (draft == null || draft.lines.isEmpty) {
      const message = 'Não há rascunho em atendimento. Nada foi alterado.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    DateTime? date;
    if (command.gap == VoiceGap.none && command.dueOn != null) {
      date = DateTime.tryParse(command.dueOn!);
    } else {
      final spoken = readSpokenDate(command.looseText ?? '');
      if (spoken == null) {
        const message = 'Qual é o dia do vencimento?';
        return VoiceOutcome(
          kind: VoiceOutcomeKind.clarify,
          message: message,
          understood: message,
          spoken: '',
          command: command.copyWith(gap: VoiceGap.due),
          subjectId: customerId,
        );
      }
      final resolved = resolveSpokenDate(spoken, today);
      if (resolved.date == null) {
        final alternative = resolved.alternative;
        final message = resolved.question ?? 'Qual é o vencimento?';
        return VoiceOutcome(
          kind: VoiceOutcomeKind.clarify,
          message: message,
          understood: message,
          spoken: '',
          command: command.copyWith(
            gap: VoiceGap.due,
            dueOn: alternative == null ? null : _isoDay(alternative),
          ),
          subjectId: customerId,
        );
      }
      date = resolved.date;
    }
    if (date == null) {
      const message = 'Qual é o dia do vencimento?';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        spoken: '',
      );
    }
    final saved = await notes.setDueOn(noteId: draft.id, dueOn: date);
    if (saved.isLeft()) {
      const message = 'O vencimento não foi alterado.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    final label = formatSpokenDate(date);
    final message = 'Vencimento do rascunho: $label.';
    return VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message: message,
      understood: message,
      spoken: '',
      command: command.copyWith(dueOn: _isoDay(date), gap: VoiceGap.none),
      subjectId: customerId,
      subjectName: who is VoicePerson ? who.name : null,
      openNote: true,
    );
  }

  Future<VoiceOutcome> _arrangePayment(VoiceCommand command) async {
    if (command.settlement == 'promised') {
      const message = 'O Pix ainda não entrou. Nada foi recebido.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    final who = await _customerGate(command);
    if (who is VoiceOutcome) return who;
    final customerId = command.customerId!;
    final draft = await _openDraft(customerId);
    if (draft == null || draft.lines.isEmpty) {
      const message = 'Não há rascunho em atendimento. Nada foi alterado.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    if (command.gap == VoiceGap.payment || command.settlement == null) {
      final message = command.priceCents == null && !command.payAll
          ? 'Qual valor foi recebido?'
          : 'Em dinheiro ou no Pix?';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        understood: message,
        spoken: '',
        command: command.copyWith(gap: VoiceGap.payment),
        subjectId: customerId,
      );
    }
    if (command.settlement == 'fiado') {
      _payments.remove(customerId);
      const message = 'A compra fica fiada. Nenhum pagamento foi recebido.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.completed,
        message: message,
        understood: message,
        spoken: '',
        command: command.copyWith(gap: VoiceGap.none),
        subjectId: customerId,
      );
    }
    final total = draft.totalCents;
    var amount = command.payAll ? total : command.priceCents;
    if (command.payAll && command.includePriorDebt) {
      final account = await receivables.account(customerId);
      amount = total + account.balanceCents;
    }
    final tendered = command.tenderedCents;
    if (amount == null && tendered != null) {
      final message =
          'Os ${_money(tendered)} são o valor pago ou o que ela entregou?';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        understood: message,
        spoken: '',
        command: command.copyWith(gap: VoiceGap.payment),
        subjectId: customerId,
      );
    }
    if (amount == null || amount <= 0) {
      const message = 'Qual valor foi recebido?';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        understood: message,
        spoken: '',
        command: command.copyWith(gap: VoiceGap.payment),
        subjectId: customerId,
      );
    }
    if (amount > total && (tendered == null || tendered < amount)) {
      final message =
          '${_money(amount)} passa dos ${_money(total)} desta compra. '
          'Diga o valor pago e o que ela entregou, para separar o troco.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        understood: message,
        spoken: '',
        command: command,
        subjectId: customerId,
      );
    }
    if (tendered != null && tendered < amount) {
      const message = 'O valor entregue não cobre o pagamento.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    _payments[customerId] = _VoicePay(
      method: command.settlement!,
      amountCents: amount,
      tenderedCents: command.settlement == 'cash' ? tendered : null,
      payAll: command.payAll,
      includePriorDebt: command.includePriorDebt,
    );
    final method = command.settlement == 'pix' ? 'Pix' : 'dinheiro';
    final change = tendered == null ? null : tendered - amount;
    final message = change != null && change > 0
        ? 'Recebido ${_money(amount)} em $method. Ela entregou ${_money(tendered!)}. Troco ${_money(change)}.'
        : 'Recebido ${_money(amount)} em $method nesta compra.';
    return VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message: message,
      understood: message,
      spoken: '',
      command: command.copyWith(gap: VoiceGap.none),
      subjectId: customerId,
    );
  }

  Future<VoiceOutcome> _reviewDelivery(
    VoiceCommand command,
    DateTime today,
  ) async {
    final noteId = _reviewedNoteId(command.reviewToken);
    if (command.accepted && noteId != null) {
      final db = await openCatalog();
      final existing = await db.query(
        'door_sales',
        where: 'id = ?',
        whereArgs: [noteId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        const message = 'Esta entrega já estava confirmada.';
        return const VoiceOutcome(
          kind: VoiceOutcomeKind.repeated,
          message: message,
          spoken: '',
        );
      }
    }
    final who = await _customerGate(command);
    if (who is VoiceOutcome) return who;
    final customerId = command.customerId!;
    final person = who! as VoicePerson;
    var draft = await _openDraft(customerId);
    if (draft == null || draft.lines.isEmpty) {
      const message = 'Não há rascunho para confirmar. Nada foi alterado.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    final pay = _payments[customerId];
    final applied = _applied(pay, draft.totalCents);
    if (draft.dueOn == null && applied >= draft.totalCents && applied > 0) {
      final saved = await notes.setDueOn(
        noteId: draft.id,
        dueOn: DateTime(today.year, today.month, today.day),
      );
      final updated = saved.fold<CustomerNote?>((_) => null, (note) => note);
      if (updated != null) draft = updated;
    }
    if (draft.dueOn == null && applied < draft.totalCents) {
      const message = 'Qual é o vencimento do restante?';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: message,
        understood: message,
        spoken: '',
        command: VoiceCommand(
          intent: VoiceIntent.setDueDate,
          transcript: command.transcript,
          customerId: customerId,
          gap: VoiceGap.due,
        ),
        subjectId: customerId,
        subjectName: person.name,
      );
    }
    final preview = await _preview(person, draft, pay, today);
    if (command.accepted) {
      if (command.reviewToken != preview.token) {
        const message =
            'A revisão mudou. A confirmação anterior não vale. Nada foi alterado.';
        return const VoiceOutcome(
          kind: VoiceOutcomeKind.blocked,
          message: message,
          spoken: '',
        );
      }
      return _confirmDelivery(person, draft, pay, preview, today);
    }
    return VoiceOutcome(
      kind: VoiceOutcomeKind.clarify,
      message: preview.message,
      understood: preview.message,
      spoken: '',
      command: command.copyWith(reviewToken: preview.token, gap: VoiceGap.none),
      note: VoiceNoteBrief(totalCents: draft.totalCents, lines: preview.lines),
      subjectId: customerId,
      subjectName: person.name,
      subjectPlace: person.neighborhood,
    );
  }

  Future<VoiceOutcome> _confirmDelivery(
    VoicePerson person,
    CustomerNote draft,
    _VoicePay? pay,
    _DeliveryPreview preview,
    DateTime today,
  ) async {
    DeliveryPayment? payment;
    if (pay != null && pay.method != 'fiado') {
      final amount = pay.amountCents;
      payment = DeliveryPayment(
        id: 'voice-pay-${draft.id}',
        amountCents: amount,
        paidOn: _isoDay(today),
        method: pay.method == 'pix' ? PaymentMethod.pix : PaymentMethod.cash,
        receivableIds: preview.receivableIds,
        tenderedCents: pay.method == 'cash' ? pay.tenderedCents : null,
      );
    }
    try {
      final result = await deliveries.confirm(
        noteId: draft.id,
        payment: payment,
      );
      if (result.alreadyRecorded) {
        const message = 'Esta entrega já estava confirmada.';
        return const VoiceOutcome(
          kind: VoiceOutcomeKind.repeated,
          message: message,
          spoken: '',
        );
      }
      _payments.remove(person.id);
      final account = await receivables.account(person.id);
      final stock = preview.lines
          .where((line) => line.startsWith('Saída'))
          .join(' ');
      final message =
          'Entrega confirmada. Venda de ${_money(result.totalCents)}. '
          '${person.name} fica devendo ${_money(account.balanceCents)}. $stock';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.completed,
        message: message,
        understood: message,
        spoken: '',
        command: const VoiceCommand(
          intent: VoiceIntent.reviewDelivery,
          transcript: 'confirmar',
        ),
        subjectId: person.id,
        subjectName: person.name,
        subjectPlace: person.neighborhood,
        openNote: true,
        note: VoiceNoteBrief(
          totalCents: result.totalCents,
          lines: preview.lines,
        ),
      );
    } on DeliveryException catch (error) {
      return VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: error.message,
        understood: error.message,
        spoken: '',
        subjectId: person.id,
        subjectName: person.name,
      );
    }
  }

  Future<Object?> _customerGate(VoiceCommand command) async {
    if (command.customerId == null) {
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: 'Para qual cliente?',
        understood: 'Para qual cliente?',
        spoken: '',
        command: command.copyWith(gap: VoiceGap.customer),
      );
    }
    final people = await _people();
    final named = people.where((item) => item.id == command.customerId);
    if (named.isEmpty) {
      const message = 'Não encontrei essa cliente.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: '',
      );
    }
    return named.first;
  }

  Future<_DeliveryPreview> _preview(
    VoicePerson person,
    CustomerNote draft,
    _VoicePay? pay,
    DateTime today,
  ) async {
    final account = await receivables.account(person.id);
    final prior = account.balanceCents;
    final applied = _applied(pay, draft.totalCents);
    final predicted = prior + draft.totalCents - applied;
    final db = await openCatalog();
    final lines = <String>[
      for (final line in draft.lines)
        '${line.name} · ${_quantitySpoken(_goodsOf(line), line.quantity)}',
    ];
    final stockParts = <String>[];
    final stockKey = <String>[];
    for (final line in draft.lines) {
      final productId = line.productId;
      if (productId == null) continue;
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity), 0) AS total
        FROM movements
        WHERE product_id = ? AND location_code = 'montana'
        ''',
        [productId],
      );
      final have = rows.single['total'] as int? ?? 0;
      stockParts.add(
        'Saída prevista da Montana: ${line.name} ${_briefQuantity(line.unit, line.quantity)} '
        '(há ${_briefQuantity(line.unit, have)}).',
      );
      stockKey.add('$productId:$have:${line.quantity}');
    }
    final due = draft.dueOn == null
        ? 'Sem vencimento.'
        : 'Vencimento do restante: ${formatSpokenDate(draft.dueOn!)}.';
    final paymentText = _paymentText(pay, draft.totalCents, applied);
    final priorText = prior == 0
        ? 'Não há dívida anterior.'
        : pay?.includePriorDebt == true
        ? 'Dívida anterior ${_money(prior)} entra nesta distribuição.'
        : 'Dívida anterior ${_money(prior)} não entra neste pagamento.';
    final saleId = saleReceivableId(draft.id);
    final selected = <Receivable>[
      Receivable(
        id: saleId,
        customerId: person.id,
        description: 'esta compra',
        amountCents: draft.totalCents,
        openCents: draft.totalCents,
        occurredOn: _isoDay(today),
      ),
      if (pay?.includePriorDebt == true) ...account.receivables,
    ];
    final message = [
      'Revisão da entrega de ${person.name}.',
      lines.join(', '),
      'Total ${_money(draft.totalCents)}.',
      due,
      paymentText,
      priorText,
      'Saldo previsto ${_money(predicted)}.',
      ...stockParts,
      'Diga confirmar, corrigir ou cancelar.',
    ].join(' ');
    final payKey = pay == null
        ? 'nenhum'
        : '${pay.method}:$applied:${pay.tenderedCents ?? ''}:${pay.includePriorDebt}';
    final token = [
      person.id,
      draft.id,
      draft.totalCents,
      draft.dueOn == null ? '' : _isoDay(draft.dueOn!),
      draft.updatedAt.toIso8601String(),
      payKey,
      prior,
      stockKey.join(','),
    ].join('|');
    return _DeliveryPreview(
      token: token,
      message: message,
      lines: [...lines, ...stockParts],
      receivableIds: [for (final item in selected) item.id],
    );
  }

  String _paymentText(_VoicePay? pay, int total, int applied) {
    if (pay == null || pay.method == 'fiado' || applied <= 0) {
      return 'Pagamento: nenhum. A compra fica fiada.';
    }
    final method = pay.method == 'pix' ? 'Pix' : 'dinheiro';
    final tendered = pay.tenderedCents;
    final change = tendered == null ? 0 : tendered - applied;
    final changeText = change > 0
        ? ' Ela entregou ${_money(tendered!)}. Troco ${_money(change)}.'
        : '';
    final rest = total - applied;
    final restText = rest > 0
        ? ' Restante a prazo ${_money(rest)}.'
        : ' Esta compra fica quitada.';
    return 'Pagamento: ${_money(applied)} em $method nesta compra.$changeText$restText';
  }

  int _applied(_VoicePay? pay, int total) {
    if (pay == null || pay.method == 'fiado') return 0;
    if (pay.payAll) return total;
    final amount = pay.amountCents;
    if (amount <= 0) return 0;
    return amount > total ? total : amount;
  }

  String? _reviewedNoteId(String? token) {
    if (token == null) return null;
    final parts = token.split('|');
    if (parts.length < 2 || parts[1].isEmpty) return null;
    return parts[1];
  }

  String _isoDay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  VoiceGoods _goodsOf(NoteLine line) {
    return VoiceGoods(
      id: line.productId ?? line.id,
      name: line.name,
      unit: line.unit,
      salePriceCents: line.unitPriceCents,
      active: true,
    );
  }

  Future<VoiceOutcome> _addMany(
    VoiceCommand command,
    List<VoicePerson> people,
    List<VoiceGoods> goods,
    List<VoiceAlias> aliases,
    String executionId,
  ) async {
    final db = await openCatalog();
    final existing = await db.query(
      'voice_commands',
      where: 'execution_id = ? OR execution_id LIKE ?',
      whereArgs: [executionId, '$executionId~%'],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      const message = 'Esta solicitação já foi gravada.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.repeated,
        message: message,
        spoken: '',
        executionId: executionId,
        command: command.copyWith(gap: VoiceGap.none),
      );
    }
    final slices = <VoiceCommand>[];
    final pending = <VoiceItem>[];
    String? question;
    for (final item in command.items) {
      final slice = VoiceCommand(
        intent: VoiceIntent.addDraftItem,
        transcript: command.transcript,
        customerQuery: command.customerQuery,
        customerId: command.customerId,
        productQuery: item.productQuery,
        productId: item.productId,
        quantity: item.quantity,
        unit: item.unit,
        priceCents: item.priceCents,
        priceBasis: item.priceBasis,
      );
      final resolution = resolveVoice(
        command: slice,
        people: people,
        goods: goods,
        aliases: aliases,
      );
      if (resolution.customer == null) {
        final message =
            resolution.message ?? 'Para qual cliente é esse produto?';
        return VoiceOutcome(
          kind: VoiceOutcomeKind.clarify,
          message: message,
          understood: message,
          spoken: '',
          command: command.copyWith(gap: VoiceGap.customer),
        );
      }
      if (!resolution.readyToAdd) {
        question ??= resolution.message ?? 'Preciso de um esclarecimento.';
        pending.add(
          item.copyWith(
            productId: resolution.product?.id ?? item.productId,
            productQuery: resolution.product?.name ?? item.productQuery,
            gap: resolution.needsUnit
                ? VoiceGap.unit
                : resolution.needsPriceBasis
                ? VoiceGap.price
                : resolution.product == null
                ? VoiceGap.product
                : VoiceGap.quantity,
          ),
        );
        continue;
      }
      slices.add(
        slice.copyWith(
          customerId: resolution.customer!.id,
          productId: resolution.product!.id,
          productQuery: resolution.product!.name,
          quantity: resolution.quantity!.toDouble(),
          unit:
              item.unit == VoiceUnit.piece &&
                  resolution.product!.unit == CatalogUnit.kilogram
              ? VoiceUnit.piece
              : _voiceUnit(resolution.product!.unit),
        ),
      );
      pending.add(
        item.copyWith(
          productId: resolution.product!.id,
          productQuery: resolution.product!.name,
          gap: VoiceGap.none,
        ),
      );
    }
    if (question != null) {
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: question,
        understood: question,
        spoken: '',
        command: command.copyWith(
          items: pending,
          gap: pending.firstWhere((item) => item.gap != VoiceGap.none).gap,
        ),
        subjectId: command.customerId,
      );
    }
    final customerId = slices.first.customerId!;
    final draftResult = await notes.activeDraft(customerId);
    final draft = draftResult.fold(
      (failure) => throw failure,
      (value) => value,
    );
    final lines = [
      for (final line in draft.lines) NoteLineDraft.fromLine(line),
    ];
    final effects = <Map<String, Object>>[];
    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final product = goods.firstWhere((item) => item.id == slice.productId);
      final quantity = slice.quantity!.round();
      final lineUnit =
          slice.unit == VoiceUnit.piece && product.unit == CatalogUnit.kilogram
          ? CatalogUnit.piece
          : product.unit;
      final practiced = slice.priceCents == null
          ? null
          : _practicedCents(
              spokenCents: slice.priceCents!,
              basis: slice.priceBasis,
              unit: product.unit,
              quantity: quantity,
            );
      var found = -1;
      for (var line = 0; line < lines.length; line++) {
        final samePrice =
            practiced == null || lines[line].unitPriceCents == practiced;
        if (lines[line].productId == product.id &&
            lines[line].unit == lineUnit &&
            samePrice &&
            (practiced != null || slice.priceCents == null)) {
          found = line;
          if (practiced == null) break;
        }
      }
      if (slice.priceCents == null) {
        found = -1;
        for (var line = 0; line < lines.length; line++) {
          if (lines[line].productId == product.id &&
              lines[line].unit == lineUnit) {
            found = line;
            break;
          }
        }
      }
      final previous = found < 0 ? 0 : lines[found].quantity;
      final unitPrice =
          practiced ??
          (found < 0 ? product.salePriceCents : lines[found].unitPriceCents);
      final reference = found < 0
          ? product.salePriceCents
          : lines[found].referencePriceCents;
      final lineId = found < 0
          ? 'voice-$executionId${index == 0 ? '' : '~$index'}'
          : lines[found].id ?? 'voice-$executionId~$index';
      if (found < 0) {
        lines.add(
          NoteLineDraft(
            id: lineId,
            productId: product.id,
            name: product.name,
            unit: lineUnit,
            quantity: quantity,
            unitPriceCents: unitPrice,
            referencePriceCents: reference,
          ),
        );
      } else {
        final current = lines[found];
        lines[found] = NoteLineDraft(
          id: current.id,
          productId: current.productId,
          name: current.name,
          unit: current.unit,
          quantity: current.quantity + quantity,
          unitPriceCents: current.unitPriceCents,
          referencePriceCents: current.referencePriceCents,
        );
      }
      effects.add({
        'execution_id': index == 0 ? executionId : '$executionId~$index',
        'line_id': lineId,
        'product_id': product.id,
        'added_quantity': quantity,
        'previous_quantity': previous,
        'unit_price_cents': unitPrice,
      });
    }
    final saved = await notes.saveLines(noteId: draft.id, lines: lines);
    final note = saved.fold((failure) => throw failure, (value) => value);
    final recordedAt = _clock().toIso8601String();
    for (final effect in effects) {
      await db.insert('voice_commands', {
        'execution_id': effect['execution_id'],
        'customer_id': customerId,
        'note_id': note.id,
        'line_id': effect['line_id'],
        'product_id': effect['product_id'],
        'added_quantity': effect['added_quantity'],
        'previous_quantity': effect['previous_quantity'],
        'unit_price_cents': effect['unit_price_cents'],
        'previous_price_cents': effect['unit_price_cents'],
        'command_kind': 'add',
        'undone': 0,
        'recorded_at': recordedAt,
      });
    }
    final person = people.firstWhere((item) => item.id == customerId);
    final summary = slices
        .map((slice) {
          final product = goods.firstWhere(
            (item) => item.id == slice.productId,
          );
          final unit =
              slice.unit == VoiceUnit.piece &&
                  product.unit == CatalogUnit.kilogram
              ? CatalogUnit.piece
              : product.unit;
          return '${product.name} ${_briefQuantity(unit, slice.quantity!.round())}';
        })
        .join(' e ');
    final message =
        'Adicionados: $summary. O rascunho ficou em ${_money(note.totalCents)}. Isso ainda não é uma venda.';
    return VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message: message,
      understood: 'Adicionar ${slices.length} itens para ${person.name}',
      spoken: '',
      executionId: executionId,
      command: command.copyWith(items: pending, gap: VoiceGap.none),
      subjectId: person.id,
      subjectName: person.name,
      subjectPlace: person.neighborhood,
      openNote: true,
      note: VoiceNoteBrief(
        totalCents: note.totalCents,
        lines: [
          for (final line in note.lines)
            '${line.name} · ${_quantitySpoken(_goodsOf(line), line.quantity)}',
        ],
      ),
    );
  }

  VoiceUnit _voiceUnit(CatalogUnit unit) {
    return switch (unit) {
      CatalogUnit.kilogram => VoiceUnit.kilogram,
      CatalogUnit.piece => VoiceUnit.piece,
      CatalogUnit.bunch => VoiceUnit.bunch,
      CatalogUnit.box => VoiceUnit.box,
      CatalogUnit.dozen => VoiceUnit.dozen,
    };
  }

  Future<VoiceOutcome> _reprice(
    VoiceCommand command,
    VoiceResolution resolution,
    String executionId,
  ) async {
    final customer = resolution.customer!;
    final product = resolution.product!;
    final db = await openCatalog();
    final existing = await db.query(
      'voice_commands',
      where: 'execution_id = ?',
      whereArgs: [executionId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      const message = 'Esta solicitação já foi gravada.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.repeated,
        message: message,
        spoken: message,
        executionId: executionId,
        command: command.copyWith(gap: VoiceGap.none),
      );
    }
    final draft = await _openDraft(customer.id);
    if (draft == null) {
      const message = 'Não há rascunho. A nota entregue não foi alterada.';
      return const VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: message,
      );
    }
    final matches = [
      for (final line in draft.lines)
        if (line.productId == product.id) line,
    ];
    if (matches.isEmpty) {
      final message = 'Não há ${product.name} no rascunho.';
      return VoiceOutcome(
        kind: VoiceOutcomeKind.blocked,
        message: message,
        spoken: message,
        command: command,
      );
    }
    NoteLine? line;
    if (command.lineId != null) {
      for (final item in matches) {
        if (item.id == command.lineId) line = item;
      }
    } else if (matches.length == 1) {
      line = matches.single;
    }
    if (line == null) {
      return VoiceOutcome(
        kind: VoiceOutcomeKind.clarify,
        message: 'Há mais de uma ${product.name} no rascunho. Qual delas?',
        understood: 'Há mais de uma ${product.name} no rascunho. Qual delas?',
        spoken: 'Qual ${product.name} muda de preço?',
        choices: [
          for (final item in matches)
            VoiceChoice(
              id: 'line:${item.id}',
              label:
                  '${item.name} · ${_quantitySpoken(product, item.quantity)} · ${_money(item.unitPriceCents)}',
            ),
        ],
        command: command.copyWith(gap: VoiceGap.product),
      );
    }
    final current = line;
    final practiced = _practicedCents(
      spokenCents: command.priceCents!,
      basis: command.priceBasis,
      unit: product.unit,
      quantity: current.quantity,
    );
    final saved = await notes.saveLines(
      noteId: draft.id,
      lines: [
        for (final item in draft.lines)
          if (item.id == current.id)
            NoteLineDraft(
              id: item.id,
              productId: item.productId,
              name: item.name,
              unit: item.unit,
              quantity: item.quantity,
              unitPriceCents: practiced,
              referencePriceCents: item.referencePriceCents,
            )
          else
            NoteLineDraft.fromLine(item),
      ],
    );
    if (saved.isLeft()) throw CacheException();
    await db.insert('voice_commands', {
      'execution_id': executionId,
      'customer_id': customer.id,
      'note_id': draft.id,
      'line_id': current.id,
      'product_id': product.id,
      'added_quantity': 0,
      'previous_quantity': current.quantity,
      'unit_price_cents': practiced,
      'previous_price_cents': current.unitPriceCents,
      'command_kind': 'reprice',
      'undone': 0,
      'recorded_at': _clock().toIso8601String(),
    });
    final money = _reaisSpoken(command.priceCents!);
    final spoken = command.priceBasis == VoicePriceBasis.total
        ? '${product.name} ficou por $money no total.'
        : '${product.name} ficou por $money.';
    return VoiceOutcome(
      kind: VoiceOutcomeKind.completed,
      message: spoken,
      understood: 'Alterar o preço de ${product.name}',
      spoken: spoken,
      executionId: executionId,
      command: command.copyWith(gap: VoiceGap.none, lineId: current.id),
      subjectId: customer.id,
      subjectName: customer.name,
      subjectPlace: customer.neighborhood,
      openNote: true,
    );
  }

  Future<List<VoicePerson>> _people() async {
    final db = await customers.database();
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.name,
        (
          SELECT neighborhood FROM customer_addresses
          WHERE customer_id = c.id AND is_primary = 1
          LIMIT 1
        ) AS neighborhood
      FROM customers c
      WHERE c.status = ?
      ORDER BY c.name COLLATE NOCASE
      ''',
      ['active'],
    );
    return [
      for (final row in rows)
        VoicePerson(
          id: row['id']! as String,
          name: row['name']! as String,
          neighborhood: row['neighborhood'] as String?,
        ),
    ];
  }

  Future<List<VoiceGoods>> _goods() async {
    final snapshot = await catalog.load();
    return snapshot.fold((failure) => throw failure, (value) {
      return [
        for (final row in value.products)
          VoiceGoods(
            id: row.product.id,
            name: row.product.name,
            unit: row.product.unit,
            salePriceCents: row.product.salePriceCents,
            active: row.product.active,
          ),
      ];
    });
  }

  Future<List<VoiceAlias>> _aliases() async {
    final db = await openCatalog();
    final rows = await db.query('voice_aliases');
    return [
      for (final row in rows)
        VoiceAlias(
          kind: VoiceAliasKind.values.byName(row['kind']! as String),
          alias: row['alias']! as String,
          target: row['target']! as String,
        ),
    ];
  }

  Future<VoiceAccountBrief> _account(VoicePerson person, DateTime today) async {
    final account = await receivables.account(person.id);
    final db = await openCatalog();
    final rows = await db.query(
      'receivables',
      where: 'customer_id = ?',
      whereArgs: [person.id],
    );
    final kinds = {
      for (final row in rows) row['id']! as String: row['kind'] as String?,
    };
    final day = _day(today);
    final notes = <VoiceDebtNote>[];
    var overdue = 0;
    for (final item in account.receivables) {
      final lines = <String>[];
      final sale = kinds[item.id] == 'sale' && item.id.startsWith('sale-');
      if (sale) {
        final stored = await db.query(
          'door_sale_lines',
          where: 'sale_id = ?',
          whereArgs: [item.id.substring(5)],
          orderBy: 'position ASC',
        );
        for (final line in stored) {
          lines.add(
            '${line['name']} · ${_lineQuantity(line['unit'] as String, line['quantity'] as int)}',
          );
        }
      }
      final late =
          item.openCents > 0 &&
          item.dueOn != null &&
          item.dueOn!.compareTo(day) < 0;
      if (late) overdue += item.openCents;
      notes.add(
        VoiceDebtNote(
          description: item.description,
          amountCents: item.amountCents,
          openCents: item.openCents,
          dueOn: item.dueOn,
          overdue: late,
          legacyWithoutItems: lines.isEmpty,
          lines: lines,
        ),
      );
    }
    final payments = <VoicePaymentLine>[];
    var credit = 0;
    for (final receipt in account.receipts) {
      if (receipt.reversed) continue;
      final available = receipt.creditCents - receipt.appliedCreditCents;
      if (available > 0) credit += available;
      payments.add(
        VoicePaymentLine(
          label: switch (receipt.method) {
            PaymentMethod.pix => 'Pix',
            PaymentMethod.cash => 'Dinheiro',
            PaymentMethod.card => 'Cartão',
          },
          amountCents: receipt.amountCents,
          creditCents: available > 0 ? available : 0,
        ),
      );
    }
    return VoiceAccountBrief(
      customerId: person.id,
      name: person.name,
      neighborhood: person.neighborhood,
      balanceCents: account.balanceCents,
      overdueCents: overdue,
      creditCents: credit,
      notes: notes,
      payments: payments,
    );
  }
}

String _speakAccount(VoiceAccountBrief account) {
  final place = (account.neighborhood ?? '').trim();
  final who = place.isEmpty ? account.name : '${account.name}, do $place';
  final debt = account.balanceCents > 0
      ? '$who deve ${_money(account.balanceCents)}.'
      : '$who não tem dívida em aberto.';
  final late = account.overdueCents > 0
      ? ' ${_money(account.overdueCents)} estão vencidos.'
      : '';
  return '$debt$late';
}

int _practicedCents({
  required int spokenCents,
  required VoicePriceBasis? basis,
  required CatalogUnit unit,
  required int quantity,
}) {
  if (basis != VoicePriceBasis.total || quantity <= 0) return spokenCents;
  if (unit == CatalogUnit.kilogram) {
    return ((spokenCents * 1000) + quantity ~/ 2) ~/ quantity;
  }
  return (spokenCents + quantity ~/ 2) ~/ quantity;
}

String _pricedSpoken({
  required VoiceGoods product,
  required int quantity,
  required int priceCents,
  required VoicePriceBasis? basis,
  required String customerName,
}) {
  final money = _reaisSpoken(priceCents);
  final total = basis == VoicePriceBasis.total ? ' no total' : '';
  final who = customerName.trim().split(' ').first;
  return 'Anotei ${_itemPhrase(product, quantity)} por $money$total para $who.';
}

String _itemPhrase(VoiceGoods product, int quantity) {
  final name = product.name.toLowerCase();
  if (product.unit == CatalogUnit.kilogram) {
    return '${_quantitySpoken(product, quantity)} de $name';
  }
  if (quantity == 1) {
    final article = foldVoice(name).endsWith('a') ? 'uma' : 'um';
    return '$article $name';
  }
  return '$quantity $name';
}

String _reaisSpoken(int cents) {
  if (cents < 0 || cents % 100 != 0) return _money(cents);
  const ones = [
    'zero',
    'um',
    'dois',
    'tres',
    'quatro',
    'cinco',
    'seis',
    'sete',
    'oito',
    'nove',
    'dez',
    'onze',
    'doze',
    'treze',
    'quatorze',
    'quinze',
    'dezesseis',
    'dezessete',
    'dezoito',
    'dezenove',
  ];
  const tens = [
    '',
    '',
    'vinte',
    'trinta',
    'quarenta',
    'cinquenta',
    'sessenta',
    'setenta',
    'oitenta',
    'noventa',
  ];
  final reais = cents ~/ 100;
  String? words;
  if (reais < ones.length) {
    words = ones[reais];
  } else if (reais == 100) {
    words = 'cem';
  } else if (reais < 100 && reais >= 20) {
    final ten = tens[reais ~/ 10];
    final one = reais % 10;
    words = one == 0 ? ten : '$ten e ${ones[one]}';
  }
  if (words == null) return _money(cents);
  return reais == 1 ? '$words real' : '$words reais';
}

String _money(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final whole = value ~/ 100;
  final fraction = (value % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}R\$ $whole,$fraction';
}

String _briefQuantity(CatalogUnit unit, int quantity) {
  if (unit == CatalogUnit.kilogram) {
    final kilos = quantity / 1000;
    final text = kilos == kilos.roundToDouble()
        ? kilos.toStringAsFixed(0)
        : kilos.toStringAsFixed(1).replaceAll('.', ',');
    return '$text kg';
  }
  return '$quantity ${_unitName(unit)}';
}

String _quantitySpoken(VoiceGoods product, int quantity) {
  if (product.unit == CatalogUnit.kilogram) {
    final kilos = quantity / 1000;
    final text = kilos == kilos.roundToDouble()
        ? kilos.toStringAsFixed(0)
        : kilos.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${kilos == 1 ? 'quilo' : 'quilos'}';
  }
  return '$quantity ${_unitName(product.unit)}';
}

String _lineQuantity(String unit, int quantity) {
  if (unit == CatalogUnit.kilogram.name) {
    return _quantitySpoken(
      VoiceGoods(
        id: '',
        name: '',
        unit: CatalogUnit.kilogram,
        salePriceCents: 0,
        active: true,
      ),
      quantity,
    );
  }
  return '$quantity $unit';
}

String _unitName(CatalogUnit unit) {
  return switch (unit) {
    CatalogUnit.kilogram => 'quilos',
    CatalogUnit.piece => 'unidades',
    CatalogUnit.bunch => 'maços',
    CatalogUnit.box => 'caixas',
    CatalogUnit.dozen => 'dúzias',
  };
}

String _day(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

class _VoicePay {
  const _VoicePay({
    required this.method,
    required this.amountCents,
    required this.payAll,
    required this.includePriorDebt,
    this.tenderedCents,
  });

  final String method;
  final int amountCents;
  final int? tenderedCents;
  final bool payAll;
  final bool includePriorDebt;
}

class _DeliveryPreview {
  const _DeliveryPreview({
    required this.token,
    required this.message,
    required this.lines,
    required this.receivableIds,
  });

  final String token;
  final String message;
  final List<String> lines;
  final List<String> receivableIds;
}
