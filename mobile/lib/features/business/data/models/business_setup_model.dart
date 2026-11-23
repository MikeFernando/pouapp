import '../../domain/entities/business_setup.dart';

class BusinessSetupModel extends BusinessSetup {
  const BusinessSetupModel({
    required super.userId,
    required super.status,
    required super.categories,
    super.kind,
  });

  /// [setupStatus] decides the account. A missing status is legacy hortifruti.
  /// An empty type on a `pending` profile stays pending.
  factory BusinessSetupModel.fromJson(
    String userId,
    Map<String, dynamic> json,
  ) {
    final status = json['setupStatus'];
    if (status == 'pending') {
      return BusinessSetupModel(
        userId: userId,
        status: BusinessSetupStatus.pending,
        categories: const [],
      );
    }

    if (status == 'configured') {
      final kind =
          businessKindFromId(json['businessType'] as String?) ??
          BusinessKind.hortifruti;
      return BusinessSetupModel(
        userId: userId,
        status: BusinessSetupStatus.configured,
        kind: kind,
        categories: _categoriesFromJson(json['suggestedCategories'], kind),
      );
    }

    return BusinessSetupModel(
      userId: userId,
      status: BusinessSetupStatus.configured,
      kind: BusinessKind.hortifruti,
      categories: categorySuggestionsFor(BusinessKind.hortifruti),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'setupStatus': status == BusinessSetupStatus.pending
          ? 'pending'
          : 'configured',
      if (kind != null) 'businessType': kind!.name,
      'suggestedCategories': [
        for (final category in categories)
          {'id': category.id, 'label': category.label},
      ],
    };
  }
}

List<BusinessCategory> _categoriesFromJson(Object? raw, BusinessKind kind) {
  if (raw is! List || raw.isEmpty) return categorySuggestionsFor(kind);
  final parsed = <BusinessCategory>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    final label = item['label'];
    if (id is! String || label is! String || id.isEmpty || label.isEmpty) {
      continue;
    }
    if (!seen.add(id)) continue;
    parsed.add(BusinessCategory(id: id, label: label));
  }
  if (parsed.isEmpty) return categorySuggestionsFor(kind);
  return parsed;
}
