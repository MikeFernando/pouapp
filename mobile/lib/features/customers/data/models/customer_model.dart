import '../../domain/entities/customer.dart';

class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.type,
    required super.name,
    required super.status,
    required super.externalSource,
    required super.createdAt,
    required super.updatedAt,
    super.tradeName,
    super.document,
    super.email,
    super.phone,
    super.mobilePhone,
    super.notes,
    super.externalId,
  });

  factory CustomerModel.fromMap(Map<String, Object?> map) {
    return CustomerModel(
      id: map['id'] as String,
      type: CustomerType.values.byName(map['type'] as String),
      name: map['name'] as String,
      tradeName: _nullable(map['trade_name']),
      document: _nullable(map['document']),
      email: _nullable(map['email']),
      phone: _nullable(map['phone']),
      mobilePhone: _nullable(map['mobile_phone']),
      status: CustomerStatus.values.byName(map['status'] as String),
      notes: _nullable(map['notes']),
      externalId: _nullable(map['external_id']),
      externalSource: CustomerSource.values.byName(
        map['external_source'] as String,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({
    required String searchName,
    required String searchTradeName,
    required String searchPhones,
    required String searchDocument,
  }) {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'trade_name': tradeName,
      'document': document,
      'email': email,
      'phone': phone,
      'mobile_phone': mobilePhone,
      'status': status.name,
      'notes': notes,
      'external_id': externalId,
      'external_source': externalSource.name,
      'search_name': searchName,
      'search_trade_name': searchTradeName,
      'search_phones': searchPhones,
      'search_document': searchDocument,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

String? _nullable(Object? value) {
  if (value == null) return null;
  final text = value as String;
  return text.isEmpty ? null : text;
}
