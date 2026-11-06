import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/catalog.dart';
import '../rules/note_rules.dart';

enum NoteStatus { draft, delivered }

/// A draft is not a sale. A delivered note keeps the prices and items of
/// the confirmation and can no longer be edited here.
class CustomerNote extends Equatable {
  const CustomerNote({
    required this.id,
    required this.customerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    this.dueOn,
  });

  final String id;
  final String customerId;
  final NoteStatus status;
  final DateTime? dueOn;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoteLine> lines;

  int get totalCents =>
      lines.fold<int>(0, (sum, line) => sum + line.totalCents);

  CustomerNote copyWith({
    NoteStatus? status,
    DateTime? dueOn,
    bool clearDueOn = false,
    DateTime? updatedAt,
    List<NoteLine>? lines,
  }) {
    return CustomerNote(
      id: id,
      customerId: customerId,
      status: status ?? this.status,
      dueOn: clearDueOn ? null : dueOn ?? this.dueOn,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lines: lines ?? this.lines,
    );
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    status,
    dueOn,
    createdAt,
    updatedAt,
    lines,
  ];
}

class NoteLine extends Equatable {
  const NoteLine({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPriceCents,
    int? referencePriceCents,
    this.productId,
  }) : referencePriceCents = referencePriceCents ?? unitPriceCents;

  final String id;
  final String? productId;
  final String name;
  final CatalogUnit unit;

  /// Grams when [unit] is kilogram. Whole count for piece, bunch and box.
  final int quantity;

  /// Price practiced on this line, in cents. The note total uses only this.
  final int unitPriceCents;

  /// Catalog price captured with the line. A lower practiced price shows a
  /// discount and is not subtracted again.
  final int referencePriceCents;

  int get discountCents => referencePriceCents > unitPriceCents
      ? referencePriceCents - unitPriceCents
      : 0;

  int get totalCents => lineTotalCents(
    unit: unit,
    quantity: quantity,
    unitPriceCents: unitPriceCents,
  );

  @override
  List<Object?> get props => [
    id,
    productId,
    name,
    unit,
    quantity,
    unitPriceCents,
    referencePriceCents,
  ];
}

class NoteLineDraft extends Equatable {
  const NoteLineDraft({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPriceCents,
    int? referencePriceCents,
    this.id,
    this.productId,
  }) : referencePriceCents = referencePriceCents ?? unitPriceCents;

  factory NoteLineDraft.fromLine(NoteLine line) {
    return NoteLineDraft(
      id: line.id,
      productId: line.productId,
      name: line.name,
      unit: line.unit,
      quantity: line.quantity,
      unitPriceCents: line.unitPriceCents,
      referencePriceCents: line.referencePriceCents,
    );
  }

  final String? id;
  final String? productId;
  final String name;
  final CatalogUnit unit;
  final int quantity;
  final int unitPriceCents;
  final int referencePriceCents;

  @override
  List<Object?> get props => [
    id,
    productId,
    name,
    unit,
    quantity,
    unitPriceCents,
    referencePriceCents,
  ];
}
