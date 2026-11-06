import '../../domain/entities/customer_address.dart';

class CustomerAddressModel extends CustomerAddress {
  const CustomerAddressModel({
    required super.id,
    required super.customerId,
    required super.label,
    required super.street,
    required super.number,
    required super.neighborhood,
    required super.city,
    required super.state,
    required super.isPrimary,
    super.recipientName,
    super.zipCode,
    super.complement,
    super.reference,
  });

  factory CustomerAddressModel.fromMap(Map<String, Object?> map) {
    return CustomerAddressModel(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      label: map['label'] as String,
      recipientName: map['recipient_name'] as String?,
      zipCode: map['zip_code'] as String?,
      street: map['street'] as String,
      number: map['number'] as String,
      complement: map['complement'] as String?,
      neighborhood: map['neighborhood'] as String,
      city: map['city'] as String,
      state: map['state'] as String,
      reference: map['reference_note'] as String?,
      isPrimary: (map['is_primary'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'label': label,
      'recipient_name': recipientName,
      'zip_code': zipCode,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'reference_note': reference,
      'is_primary': isPrimary ? 1 : 0,
    };
  }
}
