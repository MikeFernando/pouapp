import 'package:equatable/equatable.dart';

class CustomerAddress extends Equatable {
  const CustomerAddress({
    required this.id,
    required this.customerId,
    required this.label,
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.isPrimary,
    this.recipientName,
    this.zipCode,
    this.complement,
    this.reference,
  });

  final String id;
  final String customerId;
  final String label;
  final String? recipientName;
  final String? zipCode;
  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;
  final String? reference;
  final bool isPrimary;

  CustomerAddress copyWith({bool? isPrimary}) {
    return CustomerAddress(
      id: id,
      customerId: customerId,
      label: label,
      recipientName: recipientName,
      zipCode: zipCode,
      street: street,
      number: number,
      complement: complement,
      neighborhood: neighborhood,
      city: city,
      state: state,
      reference: reference,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    label,
    recipientName,
    zipCode,
    street,
    number,
    complement,
    neighborhood,
    city,
    state,
    reference,
    isPrimary,
  ];
}

class AddressInput extends Equatable {
  const AddressInput({
    required this.customerId,
    required this.label,
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.city,
    required this.state,
    this.recipientName,
    this.zipCode,
    this.complement,
    this.reference,
    this.isPrimary = false,
  });

  final String customerId;
  final String label;
  final String? recipientName;
  final String? zipCode;
  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;
  final String? reference;
  final bool isPrimary;

  @override
  List<Object?> get props => [
    customerId,
    label,
    recipientName,
    zipCode,
    street,
    number,
    complement,
    neighborhood,
    city,
    state,
    reference,
    isPrimary,
  ];
}
