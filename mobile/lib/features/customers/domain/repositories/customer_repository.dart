import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer.dart';
import '../entities/customer_address.dart';
import '../entities/customer_contact.dart';

abstract class CustomerRepository {
  Future<Either<Failure, CustomerPage>> getCustomers(CustomerQuery query);

  /// Clears the on-device customer cache (call on logout / account switch).
  Future<void> clearLocalCache();

  Future<Either<Failure, Customer>> getCustomerById(String id);

  Future<Either<Failure, Customer>> createCustomer(CustomerInput input);

  Future<Either<Failure, Customer>> updateCustomer({
    required String id,
    required CustomerInput input,
  });

  Future<Either<Failure, Customer>> changeStatus({
    required String id,
    required CustomerStatus status,
  });

  Future<Either<Failure, Unit>> deleteCustomer(String id);

  Future<Either<Failure, List<CustomerAddress>>> getAddresses(
    String customerId,
  );

  Future<Either<Failure, CustomerAddress>> addAddress(AddressInput input);

  Future<Either<Failure, CustomerAddress>> updateAddress({
    required String id,
    required AddressInput input,
  });

  Future<Either<Failure, Unit>> deleteAddress({
    required String customerId,
    required String addressId,
  });

  Future<Either<Failure, Unit>> setPrimaryAddress({
    required String customerId,
    required String addressId,
  });

  Future<Either<Failure, List<CustomerContact>>> getContacts(String customerId);

  Future<Either<Failure, CustomerContact>> addContact(ContactInput input);

  Future<Either<Failure, CustomerContact>> updateContact({
    required String id,
    required ContactInput input,
  });

  Future<Either<Failure, Unit>> deleteContact({
    required String customerId,
    required String contactId,
  });
}
