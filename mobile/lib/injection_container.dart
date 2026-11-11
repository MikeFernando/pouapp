import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/auth_token_store.dart';
import 'core/network/network_info.dart';
import 'features/assistant/data/device_voice.dart';
import 'features/assistant/data/voice_repository_impl.dart';
import 'features/assistant/domain/devices/voice_devices.dart';
import 'features/assistant/domain/repositories/voice_repository.dart';
import 'features/assistant/domain/usecases/voice_use_cases.dart';
import 'features/auth/data/datasources/api_auth_remote_data_source.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/datasources/profile_avatar_store.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/get_current_user.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/domain/usecases/register_account.dart';
import 'features/auth/domain/usecases/update_user_name.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/license/data/datasources/license_local_data_source.dart';
import 'features/license/data/datasources/license_remote_data_source.dart';
import 'features/license/data/repositories/license_repository_impl.dart';
import 'features/license/domain/repositories/license_repository.dart';
import 'features/license/domain/usecases/check_license.dart';
import 'features/license/presentation/bloc/license_bloc.dart';
import 'features/catalog/data/datasources/catalog_local_data_source.dart';
import 'features/catalog/data/repositories/catalog_repository_impl.dart';
import 'features/catalog/domain/repositories/catalog_repository.dart';
import 'features/customers/data/datasources/customer_local_data_source.dart';
import 'features/customers/data/datasources/customer_note_local_data_source.dart';
import 'features/customers/data/datasources/customer_remote_data_source.dart';
import 'features/customers/data/repositories/customer_note_repository_impl.dart';
import 'features/customers/data/repositories/customer_repository_impl.dart';
import 'features/customers/domain/repositories/customer_note_repository.dart';
import 'features/customers/domain/repositories/customer_repository.dart';
import 'features/customers/domain/usecases/address_use_cases.dart';
import 'features/customers/domain/usecases/contact_use_cases.dart';
import 'features/customers/domain/usecases/customer_use_cases.dart';
import 'features/customers/presentation/bloc/customer_details_bloc.dart';
import 'features/customers/presentation/bloc/customer_form_bloc.dart';
import 'features/customers/presentation/bloc/customers_bloc.dart';
import 'features/workspace/data/operation_store.dart';
import 'features/workspace/data/sync_worker.dart';
import 'features/workspace/data/delivery_store.dart';
import 'features/workspace/data/receivable_store.dart';
import 'features/workspace/data/datasources/home_remote_data_source.dart';
import 'features/workspace/data/datasources/workspace_local_data_source.dart';
import 'features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'features/workspace/data/repositories/workspace_repository_impl.dart';
import 'features/workspace/domain/repositories/workspace_repository.dart';
import 'features/workspace/domain/usecases/home_use_cases.dart';
import 'features/workspace/domain/usecases/workspace_use_cases.dart';
import 'features/workspace/presentation/bloc/company_operation_bloc.dart';
import 'features/workspace/presentation/bloc/home_board_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => InternetConnection());
  sl.registerLazySingleton(() => AuthTokenStore(sharedPreferences: sl()));
  sl.registerLazySingleton(() => ApiClient(tokenStore: sl()));
  sl.registerLazySingleton(
    () => ProfileAvatarStore(sharedPreferences: sl()),
  );

  //! Features - Auth
  sl.registerFactory(
    () => AuthBloc(
      login: sl(),
      registerAccount: sl(),
      getCurrentUser: sl(),
      logout: sl(),
      updateUserName: sl(),
    ),
  );
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => RegisterAccount(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  sl.registerLazySingleton(() => UpdateUserName(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      tokenStore: ApiConfig.useRemoteApi ? sl() : null,
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(() {
    if (ApiConfig.useRemoteApi) {
      return ApiAuthRemoteDataSource(apiClient: sl(), tokenStore: sl());
    }
    return SimulatedAuthRemoteDataSource(sharedPreferences: sl());
  });
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  //! Features - License (payment kill switch)
  sl.registerFactory(
    () => LicenseBloc(checkLicense: sl(), repository: sl()),
  );
  sl.registerLazySingleton(() => CheckLicense(sl()));
  sl.registerLazySingleton<LicenseRepository>(
    () => LicenseRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: ApiConfig.useRemoteApi ? sl() : null,
    ),
  );
  sl.registerLazySingleton<LicenseLocalDataSource>(
    () => LicenseLocalDataSourceImpl(sharedPreferences: sl()),
  );
  if (ApiConfig.useRemoteApi) {
    sl.registerLazySingleton<LicenseRemoteDataSource>(
      () => LicenseRemoteDataSourceImpl(apiClient: sl()),
    );
  }

  //! Features - Customers
  // The local database opens on the first customer operation, not during init.
  sl.registerFactory(() => CustomersBloc(getCustomers: sl()));
  sl.registerFactory(
    () => CustomerFormBloc(
      getCustomerById: sl(),
      createCustomer: sl(),
      updateCustomer: sl(),
    ),
  );
  sl.registerFactory(
    () => CustomerDetailsBloc(
      getCustomerById: sl(),
      changeCustomerStatus: sl(),
      getCustomerAddresses: sl(),
      addCustomerAddress: sl(),
      updateCustomerAddress: sl(),
      deleteCustomerAddress: sl(),
      setPrimaryCustomerAddress: sl(),
      getCustomerContacts: sl(),
      addCustomerContact: sl(),
      updateCustomerContact: sl(),
      deleteCustomerContact: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetCustomers(sl()));
  sl.registerLazySingleton(() => GetCustomerById(sl()));
  sl.registerLazySingleton(() => CreateCustomer(sl()));
  sl.registerLazySingleton(() => UpdateCustomer(sl()));
  sl.registerLazySingleton(() => ChangeCustomerStatus(sl()));
  sl.registerLazySingleton(() => GetCustomerAddresses(sl()));
  sl.registerLazySingleton(() => AddCustomerAddress(sl()));
  sl.registerLazySingleton(() => UpdateCustomerAddress(sl()));
  sl.registerLazySingleton(() => DeleteCustomerAddress(sl()));
  sl.registerLazySingleton(() => SetPrimaryCustomerAddress(sl()));
  sl.registerLazySingleton(() => GetCustomerContacts(sl()));
  sl.registerLazySingleton(() => AddCustomerContact(sl()));
  sl.registerLazySingleton(() => UpdateCustomerContact(sl()));
  sl.registerLazySingleton(() => DeleteCustomerContact(sl()));
  if (ApiConfig.useRemoteApi) {
    sl.registerLazySingleton<CustomerRemoteDataSource>(
      () => CustomerRemoteDataSourceImpl(apiClient: sl()),
    );
  }
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: ApiConfig.useRemoteApi ? sl() : null,
    ),
  );
  sl.registerLazySingleton<CustomerLocalDataSource>(
    () => CustomerLocalDataSourceImpl(seedDemo: !ApiConfig.useRemoteApi),
  );
  sl.registerLazySingleton<CustomerNoteRepository>(
    () => CustomerNoteRepositoryImpl(
      localDataSource: CustomerNoteLocalDataSourceImpl(
        openDatabase: () => sl<OperationStore>().database(),
      ),
    ),
  );

  //! Features - Catalog
  sl.registerLazySingleton<CatalogRepository>(
    () => CatalogRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<CatalogLocalDataSource>(
    () => CatalogLocalDataSourceImpl(seedDemo: !ApiConfig.useRemoteApi),
  );

  //! Features - Workspace
  sl.registerLazySingleton(() => CompanyOperationBloc(getOperation: sl()));
  sl.registerLazySingleton(() => GetCompanyOperation(sl()));
  sl.registerLazySingleton(() => ApplyStreetChange(sl()));
  if (ApiConfig.useRemoteApi) {
    sl.registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(apiClient: sl()),
    );
    sl.registerLazySingleton(() => GetHomeBoard(sl()));
    sl.registerLazySingleton(() => CreateHomeNote(sl()));
    sl.registerLazySingleton(() => ClearHomeNote(sl()));
    sl.registerLazySingleton(() => HomeBoardBloc(getHomeBoard: sl()));
  }
  sl.registerLazySingleton(
    () => ReceivableStore(
      openDatabase: () => sl<CatalogLocalDataSource>().database(),
    ),
  );
  sl.registerLazySingleton(
    () => DeliveryStore(
      openDatabase: () => sl<CatalogLocalDataSource>().database(),
    ),
  );
  sl.registerLazySingleton<VoiceRepository>(
    () => VoiceRepositoryImpl(
      customers: sl(),
      catalog: sl(),
      notes: sl(),
      receivables: sl(),
      deliveries: sl(),
      openCatalog: () => sl<CatalogLocalDataSource>().database(),
    ),
  );
  sl.registerLazySingleton(() => SubmitVoiceCommand(sl()));
  sl.registerLazySingleton(() => UndoVoiceCommand(sl()));
  sl.registerLazySingleton(() => SaveVoiceAlias(sl()));
  sl.registerLazySingleton<VoiceCapture>(DeviceVoiceCapture.new);
  sl.registerLazySingleton<VoiceSpeaker>(DeviceVoiceSpeaker.new);
  sl.registerLazySingleton<WorkspaceRepository>(
    () => WorkspaceRepositoryImpl(
      localDataSource: sl(),
      simulatedDataSource: sl(),
      catalogRepository: sl(),
      operationStore: sl(),
      receivableStore: sl(),
      deliveryStore: sl(),
      customers: sl(),
    ),
  );
  sl.registerLazySingleton<WorkspaceLocalDataSource>(
    () => WorkspaceLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton(WorkspaceSimulatedDataSource.new);
  sl.registerLazySingleton(
    () => OperationStore(
      openDatabase: () => sl<CatalogLocalDataSource>().database(),
      readStreetOrigin: () => sl<WorkspaceLocalDataSource>().readStreetLedger(),
      openCustomerDatabase: () => sl<CustomerLocalDataSource>().database(),
    ),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(
    () => SyncWorker(
      openDatabase: () => sl<CatalogLocalDataSource>().database(),
      online: () async {
        try {
          return await sl<NetworkInfo>().isConnected.timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
        } catch (_) {
          return false;
        }
      },
      transport: const NoServerSyncTransport(),
    ),
  );

  await sl<CatalogRepository>().load();
  await sl<OperationStore>().ensureActive();
}
