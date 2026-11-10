import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/entities/customer_contact.dart';
import '../../domain/failures/customer_failures.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_local_data_source.dart';
import '../datasources/customer_remote_data_source.dart';
import '../exceptions/customer_exceptions.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
  });

  final CustomerLocalDataSource localDataSource;
  final CustomerRemoteDataSource? remoteDataSource;

  bool get _hasRemote => remoteDataSource != null;

  @override
  Future<Either<Failure, CustomerPage>> getCustomers(CustomerQuery query) {
    return _guard(() async {
      if (_hasRemote) {
        try {
          final remote = await remoteDataSource!.listCustomers(
            search: query.search,
            status: query.status,
          );
          for (final customer in remote) {
            await localDataSource.upsertCustomer(customer);
          }
        } on NetworkException {
          // Offline / API down — serve local cache.
        } on ServerException {
          // Fall through to local cache.
        }
      }
      return localDataSource.getCustomers(query);
    });
  }

  @override
  Future<Either<Failure, Customer>> getCustomerById(String id) {
    return _guard(() async {
      try {
        return await localDataSource.getCustomerById(id);
      } on CustomerNotFoundException {
        if (!_hasRemote) rethrow;
        final remote = await remoteDataSource!.getCustomerById(id);
        return localDataSource.upsertCustomer(remote);
      }
    });
  }

  @override
  Future<Either<Failure, Customer>> createCustomer(CustomerInput input) {
    return _guard(() async {
      if (_hasRemote) {
        try {
          final remote = await remoteDataSource!.createCustomer(input);
          return await localDataSource.upsertCustomer(remote);
        } on NetworkException {
          return await localDataSource.createCustomer(input);
        }
      }
      return localDataSource.createCustomer(input);
    });
  }

  @override
  Future<Either<Failure, Customer>> updateCustomer({
    required String id,
    required CustomerInput input,
  }) {
    return _guard(() => localDataSource.updateCustomer(id: id, input: input));
  }

  @override
  Future<Either<Failure, Customer>> changeStatus({
    required String id,
    required CustomerStatus status,
  }) {
    return _guard(() async {
      if (_hasRemote) {
        try {
          final remote = await remoteDataSource!.changeStatus(
            id: id,
            status: status,
          );
          return await localDataSource.upsertCustomer(remote);
        } on NetworkException {
          return await localDataSource.changeStatus(id: id, status: status);
        }
      }
      return localDataSource.changeStatus(id: id, status: status);
    });
  }

  @override
  Future<Either<Failure, List<CustomerAddress>>> getAddresses(
    String customerId,
  ) {
    return _guard(() => localDataSource.getAddresses(customerId));
  }

  @override
  Future<Either<Failure, CustomerAddress>> addAddress(AddressInput input) {
    return _guard(() => localDataSource.addAddress(input));
  }

  @override
  Future<Either<Failure, CustomerAddress>> updateAddress({
    required String id,
    required AddressInput input,
  }) {
    return _guard(() => localDataSource.updateAddress(id: id, input: input));
  }

  @override
  Future<Either<Failure, Unit>> deleteAddress({
    required String customerId,
    required String addressId,
  }) {
    return _guard(() async {
      await localDataSource.deleteAddress(
        customerId: customerId,
        addressId: addressId,
      );
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> setPrimaryAddress({
    required String customerId,
    required String addressId,
  }) {
    return _guard(() async {
      await localDataSource.setPrimaryAddress(
        customerId: customerId,
        addressId: addressId,
      );
      return unit;
    });
  }

  @override
  Future<Either<Failure, List<CustomerContact>>> getContacts(
    String customerId,
  ) {
    return _guard(() => localDataSource.getContacts(customerId));
  }

  @override
  Future<Either<Failure, CustomerContact>> addContact(ContactInput input) {
    return _guard(() => localDataSource.addContact(input));
  }

  @override
  Future<Either<Failure, CustomerContact>> updateContact({
    required String id,
    required ContactInput input,
  }) {
    return _guard(() => localDataSource.updateContact(id: id, input: input));
  }

  @override
  Future<Either<Failure, Unit>> deleteContact({
    required String customerId,
    required String contactId,
  }) {
    return _guard(() async {
      await localDataSource.deleteContact(
        customerId: customerId,
        contactId: contactId,
      );
      return unit;
    });
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on CustomerNotFoundException {
      return const Left(CustomerNotFoundFailure());
    } on AddressNotFoundException {
      return const Left(AddressNotFoundFailure());
    } on ContactNotFoundException {
      return const Left(ContactNotFoundFailure());
    } on DuplicateExternalCustomerException {
      return const Left(DuplicateExternalCustomerFailure());
    } on CacheException {
      return const Left(CacheFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException {
      return const Left(ServerFailure());
    }
  }
}
