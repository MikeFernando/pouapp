import 'package:equatable/equatable.dart';

enum CustomerType { individual, company }

enum CustomerStatus { active, inactive }

enum CustomerSource { local, contaAzul }

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    required this.externalSource,
    required this.createdAt,
    required this.updatedAt,
    this.tradeName,
    this.document,
    this.email,
    this.phone,
    this.mobilePhone,
    this.notes,
    this.externalId,
  });

  final String id;
  final CustomerType type;
  final String name;
  final String? tradeName;
  final String? document;
  final String? email;
  final String? phone;
  final String? mobilePhone;
  final CustomerStatus status;
  final String? notes;
  final String? externalId;
  final CustomerSource externalSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    tradeName,
    document,
    email,
    phone,
    mobilePhone,
    status,
    notes,
    externalId,
    externalSource,
    createdAt,
    updatedAt,
  ];
}

class CustomerQuery extends Equatable {
  const CustomerQuery({
    this.search = '',
    this.status,
    this.page = 0,
    this.pageSize = 20,
  });

  final String search;
  final CustomerStatus? status;
  final int page;
  final int pageSize;

  CustomerQuery copyWith({
    String? search,
    CustomerStatus? status,
    int? page,
    int? pageSize,
    bool clearStatus = false,
  }) {
    return CustomerQuery(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [search, status, page, pageSize];
}

class CustomerPage extends Equatable {
  const CustomerPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Customer> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => (page + 1) * pageSize < total;

  @override
  List<Object?> get props => [items, total, page, pageSize];
}

class CustomerInput extends Equatable {
  const CustomerInput({
    required this.type,
    required this.name,
    this.tradeName,
    this.document,
    this.email,
    this.phone,
    this.mobilePhone,
    this.status = CustomerStatus.active,
    this.notes,
    this.externalId,
    this.externalSource = CustomerSource.local,
  });

  final CustomerType type;
  final String name;
  final String? tradeName;
  final String? document;
  final String? email;
  final String? phone;
  final String? mobilePhone;
  final CustomerStatus status;
  final String? notes;
  final String? externalId;
  final CustomerSource externalSource;

  @override
  List<Object?> get props => [
    type,
    name,
    tradeName,
    document,
    email,
    phone,
    mobilePhone,
    status,
    notes,
    externalId,
    externalSource,
  ];
}
