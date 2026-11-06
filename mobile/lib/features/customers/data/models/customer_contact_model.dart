import '../../domain/entities/customer_contact.dart';

class CustomerContactModel extends CustomerContact {
  const CustomerContactModel({
    required super.id,
    required super.customerId,
    required super.name,
    required super.isPrimary,
    super.role,
    super.phone,
    super.email,
    super.canReceiveBilling,
    super.canReceiveDelivery,
    super.canReceiveWhatsApp,
  });

  factory CustomerContactModel.fromMap(Map<String, Object?> map) {
    return CustomerContactModel(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      name: map['name'] as String,
      role: map['role'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      isPrimary: (map['is_primary'] as int) == 1,
      canReceiveBilling: (map['can_receive_billing'] as int) == 1,
      canReceiveDelivery: (map['can_receive_delivery'] as int) == 1,
      canReceiveWhatsApp: (map['can_receive_whatsapp'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'is_primary': isPrimary ? 1 : 0,
      'can_receive_billing': canReceiveBilling ? 1 : 0,
      'can_receive_delivery': canReceiveDelivery ? 1 : 0,
      'can_receive_whatsapp': canReceiveWhatsApp ? 1 : 0,
    };
  }
}
