import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/catalog.dart';

enum VoiceIntent {
  addDraftItem,
  repriceDraftItem,
  consultAccount,
  setDueDate,
  arrangePayment,
  reviewDelivery,
  unsupported,
  unclear,
}

/// What the assistant still needs before it can run the pending command.
enum VoiceGap { none, customer, product, quantity, price, unit, due, payment }

/// How a spoken amount of money applies to the item.
enum VoicePriceBasis { perUnit, total }

enum VoiceUnit { kilogram, piece, bunch, box, dozen }

class VoiceItem extends Equatable {
  const VoiceItem({
    this.productQuery,
    this.productId,
    this.quantity,
    this.unit,
    this.priceCents,
    this.priceBasis,
    this.gap = VoiceGap.none,
  });

  final String? productQuery;
  final String? productId;
  final double? quantity;
  final VoiceUnit? unit;
  final int? priceCents;
  final VoicePriceBasis? priceBasis;
  final VoiceGap gap;

  VoiceItem copyWith({
    String? productQuery,
    String? productId,
    double? quantity,
    VoiceUnit? unit,
    int? priceCents,
    VoicePriceBasis? priceBasis,
    VoiceGap? gap,
    bool clearUnit = false,
  }) {
    return VoiceItem(
      productQuery: productQuery ?? this.productQuery,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unit: clearUnit ? null : unit ?? this.unit,
      priceCents: priceCents ?? this.priceCents,
      priceBasis: priceBasis ?? this.priceBasis,
      gap: gap ?? this.gap,
    );
  }

  @override
  List<Object?> get props => [
    productQuery,
    productId,
    quantity,
    unit,
    priceCents,
    priceBasis,
    gap,
  ];
}

class VoiceCommand extends Equatable {
  const VoiceCommand({
    required this.intent,
    required this.transcript,
    this.customerQuery,
    this.productQuery,
    this.quantity,
    this.unit,
    this.customerId,
    this.productId,
    this.lineId,
    this.priceCents,
    this.priceBasis,
    this.looseText,
    this.reply,
    this.reviewToken,
    this.accepted = false,
    this.dueOn,
    this.settlement,
    this.tenderedCents,
    this.payAll = false,
    this.includePriorDebt = false,
    this.items = const [],
    this.gap = VoiceGap.none,
  });

  final VoiceIntent intent;
  final String transcript;
  final String? customerQuery;
  final String? productQuery;
  final double? quantity;
  final VoiceUnit? unit;
  final String? customerId;
  final String? productId;
  final String? lineId;

  /// Negotiated amount, in cents, before it is applied per unit or as a total.
  final int? priceCents;
  final VoicePriceBasis? priceBasis;

  /// Customer and product still written together, split against the catalog.
  final String? looseText;

  /// Spoken when the phrase is understood but cannot run yet.
  final String? reply;

  /// Set while the assistant is waiting for the missing piece.
  final VoiceGap gap;

  /// Binds a spoken "confirmar" to the review that was shown.
  final String? reviewToken;
  final bool accepted;

  /// Due date already resolved, as `yyyy-MM-dd`.
  final String? dueOn;

  /// `cash`, `pix`, `fiado` or `promised`.
  final String? settlement;
  final int? tenderedCents;
  final bool payAll;
  final bool includePriorDebt;

  /// More than one product in the same phrase. Empty for a single item.
  final List<VoiceItem> items;

  VoiceCommand copyWith({
    String? customerQuery,
    String? productQuery,
    String? customerId,
    String? productId,
    String? lineId,
    int? priceCents,
    VoicePriceBasis? priceBasis,
    String? looseText,
    String? reviewToken,
    String? dueOn,
    String? settlement,
    int? tenderedCents,
    bool? payAll,
    bool? includePriorDebt,
    double? quantity,
    VoiceUnit? unit,
    VoiceGap? gap,
    bool? accepted,
    List<VoiceItem>? items,
    bool clearUnit = false,
    bool clearCustomerId = false,
    bool clearCustomerQuery = false,
    bool clearProductId = false,
    bool clearReview = false,
  }) {
    return VoiceCommand(
      intent: intent,
      transcript: transcript,
      customerQuery: clearCustomerQuery
          ? null
          : customerQuery ?? this.customerQuery,
      productQuery: productQuery ?? this.productQuery,
      quantity: quantity ?? this.quantity,
      unit: clearUnit ? null : unit ?? this.unit,
      customerId: clearCustomerId ? null : customerId ?? this.customerId,
      productId: clearProductId ? null : productId ?? this.productId,
      lineId: lineId ?? this.lineId,
      priceCents: priceCents ?? this.priceCents,
      priceBasis: priceBasis ?? this.priceBasis,
      looseText: looseText ?? this.looseText,
      reply: reply,
      reviewToken: clearReview ? null : reviewToken ?? this.reviewToken,
      accepted: accepted ?? this.accepted,
      dueOn: dueOn ?? this.dueOn,
      settlement: settlement ?? this.settlement,
      tenderedCents: tenderedCents ?? this.tenderedCents,
      payAll: payAll ?? this.payAll,
      includePriorDebt: includePriorDebt ?? this.includePriorDebt,
      items: items ?? this.items,
      gap: gap ?? this.gap,
    );
  }

  @override
  List<Object?> get props => [
    intent,
    transcript,
    customerQuery,
    productQuery,
    quantity,
    unit,
    customerId,
    productId,
    lineId,
    priceCents,
    priceBasis,
    looseText,
    reply,
    reviewToken,
    accepted,
    dueOn,
    settlement,
    tenderedCents,
    payAll,
    includePriorDebt,
    items,
    gap,
  ];
}

class VoicePerson extends Equatable {
  const VoicePerson({required this.id, required this.name, this.neighborhood});

  final String id;
  final String name;
  final String? neighborhood;

  @override
  List<Object?> get props => [id, name, neighborhood];
}

class VoiceGoods extends Equatable {
  const VoiceGoods({
    required this.id,
    required this.name,
    required this.unit,
    required this.salePriceCents,
    required this.active,
  });

  final String id;
  final String name;
  final CatalogUnit unit;
  final int salePriceCents;
  final bool active;

  @override
  List<Object?> get props => [id, name, unit, salePriceCents, active];
}

enum VoiceAliasKind { customer, neighborhood }

class VoiceAlias extends Equatable {
  const VoiceAlias({
    required this.kind,
    required this.alias,
    required this.target,
  });

  final VoiceAliasKind kind;
  final String alias;
  final String target;

  @override
  List<Object?> get props => [kind, alias, target];
}

class VoiceChoice extends Equatable {
  const VoiceChoice({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

class VoiceDebtNote extends Equatable {
  const VoiceDebtNote({
    required this.description,
    required this.amountCents,
    required this.openCents,
    required this.legacyWithoutItems,
    this.dueOn,
    this.overdue = false,
    this.lines = const [],
  });

  final String description;
  final int amountCents;
  final int openCents;
  final bool legacyWithoutItems;
  final String? dueOn;
  final bool overdue;
  final List<String> lines;

  @override
  List<Object?> get props => [
    description,
    amountCents,
    openCents,
    legacyWithoutItems,
    dueOn,
    overdue,
    lines,
  ];
}

class VoicePaymentLine extends Equatable {
  const VoicePaymentLine({
    required this.label,
    required this.amountCents,
    this.creditCents = 0,
  });

  final String label;
  final int amountCents;
  final int creditCents;

  @override
  List<Object?> get props => [label, amountCents, creditCents];
}

class VoiceAccountBrief extends Equatable {
  const VoiceAccountBrief({
    required this.customerId,
    required this.name,
    required this.balanceCents,
    required this.overdueCents,
    required this.creditCents,
    this.neighborhood,
    this.notes = const [],
    this.payments = const [],
  });

  final String customerId;
  final String name;
  final String? neighborhood;
  final int balanceCents;
  final int overdueCents;
  final int creditCents;
  final List<VoiceDebtNote> notes;
  final List<VoicePaymentLine> payments;

  @override
  List<Object?> get props => [
    customerId,
    name,
    neighborhood,
    balanceCents,
    overdueCents,
    creditCents,
    notes,
    payments,
  ];
}

enum VoiceOutcomeKind {
  completed,
  clarify,
  unsupported,
  repeated,
  undone,
  blocked,
}

class VoiceOutcome extends Equatable {
  const VoiceOutcome({
    required this.kind,
    required this.message,
    this.understood = '',
    this.spoken = '',
    this.choices = const [],
    this.command,
    this.account,
    this.executionId,
    this.subjectId,
    this.subjectName,
    this.subjectPlace,
    this.openNote = false,
    this.note,
  });

  final VoiceOutcomeKind kind;
  final String message;
  final String understood;
  final String spoken;
  final List<VoiceChoice> choices;
  final VoiceCommand? command;
  final VoiceAccountBrief? account;

  /// Identifies one request. A later request keeps a different id.
  final String? executionId;

  /// Customer this result is about, so the next phrase can continue with her.
  final String? subjectId;
  final String? subjectName;
  final String? subjectPlace;

  /// The draft was saved, so the note screen can open on this customer.
  final bool openNote;
  final VoiceNoteBrief? note;

  @override
  List<Object?> get props => [
    kind,
    message,
    understood,
    spoken,
    choices,
    command,
    account,
    executionId,
    subjectId,
    subjectName,
    subjectPlace,
    openNote,
    note,
  ];
}

class VoiceNoteBrief extends Equatable {
  const VoiceNoteBrief({required this.totalCents, required this.lines});

  final int totalCents;
  final List<String> lines;

  @override
  List<Object?> get props => [totalCents, lines];
}
