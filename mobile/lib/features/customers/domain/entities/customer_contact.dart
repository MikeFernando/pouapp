import 'package:equatable/equatable.dart';

class CustomerContact extends Equatable {
  const CustomerContact({
    required this.id,
    required this.customerId,
    required this.name,
    required this.isPrimary,
    this.role,
    this.phone,
    this.email,
    this.canReceiveBilling = false,
    this.canReceiveDelivery = false,
    this.canReceiveWhatsApp = false,
  });

  final String id;
  final String customerId;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final bool isPrimary;
  final bool canReceiveBilling;
  final bool canReceiveDelivery;
  final bool canReceiveWhatsApp;

  @override
  List<Object?> get props => [
    id,
    customerId,
    name,
    role,
    phone,
    email,
    isPrimary,
    canReceiveBilling,
    canReceiveDelivery,
    canReceiveWhatsApp,
  ];
}

class ContactInput extends Equatable {
  const ContactInput({
    required this.customerId,
    required this.name,
    this.role,
    this.phone,
    this.email,
    this.isPrimary = false,
    this.canReceiveBilling = false,
    this.canReceiveDelivery = false,
    this.canReceiveWhatsApp = false,
  });

  final String customerId;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final bool isPrimary;
  final bool canReceiveBilling;
  final bool canReceiveDelivery;
  final bool canReceiveWhatsApp;

  @override
  List<Object?> get props => [
    customerId,
    name,
    role,
    phone,
    email,
    isPrimary,
    canReceiveBilling,
    canReceiveDelivery,
    canReceiveWhatsApp,
  ];
}
