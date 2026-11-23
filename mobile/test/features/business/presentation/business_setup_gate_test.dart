import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/app/pou_app_colors.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/auth/domain/usecases/get_current_user.dart';
import 'package:pouapp/features/auth/domain/usecases/login.dart';
import 'package:pouapp/features/auth/domain/usecases/logout.dart';
import 'package:pouapp/features/auth/domain/usecases/register_account.dart';
import 'package:pouapp/features/auth/domain/usecases/update_user_name.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_event.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_state.dart';
import 'package:pouapp/features/business/domain/entities/business_setup.dart';
import 'package:pouapp/features/business/domain/repositories/business_setup_repository.dart';
import 'package:pouapp/features/business/domain/usecases/business_setup_use_cases.dart';
import 'package:pouapp/features/business/presentation/bloc/business_setup_bloc.dart';
import 'package:pouapp/features/business/presentation/widgets/business_setup_gate.dart';

class MockLogin extends Mock implements Login {}

class MockRegisterAccount extends Mock implements RegisterAccount {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

class MockLogout extends Mock implements Logout {}

class MockUpdateUserName extends Mock implements UpdateUserName {}

void main() {
  late MockGetCurrentUser getCurrentUser;

  const user = User(id: 'user-ana', name: 'Ana', email: 'ana@pouapp.dev');

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    getCurrentUser = MockGetCurrentUser();
    when(() => getCurrentUser(any()))
        .thenAnswer((_) async => const Right(user));
  });

  Future<AuthBloc> signedIn() async {
    final auth = AuthBloc(
      login: MockLogin(),
      registerAccount: MockRegisterAccount(),
      getCurrentUser: getCurrentUser,
      logout: MockLogout(),
      updateUserName: MockUpdateUserName(),
    )..add(const AuthSessionRequested());
    await auth.stream.firstWhere((state) => state is Authenticated);
    return auth;
  }

  Future<void> pumpGate(
    WidgetTester tester, {
    required AuthBloc auth,
    required _MemorySetup repository,
    Widget? child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider(
              create: (_) => BusinessSetupBloc(
                getBusinessSetup: GetBusinessSetup(repository),
                saveBusinessSetup: SaveBusinessSetup(repository),
              ),
            ),
          ],
          child: BusinessSetupGate(
            child:
                child ??
                Navigator(
                  initialRoute: '/customers/ana',
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => Text(settings.name ?? 'home'),
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }

  Future<void> tapOn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('a new account stays on setup until the choice is saved', (
    tester,
  ) async {
    final repository = _MemorySetup()..current = BusinessSetup.pending(user.id);
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Qual é o tipo do seu negócio?'), findsOneWidget);
    expect(find.text('/customers/ana'), findsNothing);

    await tapOn(tester, find.byKey(const Key('business_setup_continue')));
    await tester.pump();
    expect(repository.saves, 0);

    await tester.tap(find.byKey(const Key('business_kind_grocery')));
    await tester.pump();
    await tapOn(tester, find.byKey(const Key('business_setup_continue')));
    await tester.pumpAndSettle();

    expect(find.text('Qual é o tipo do seu negócio?'), findsNothing);
    expect(find.text('/customers/ana'), findsOneWidget);
    expect(repository.current?.kind, BusinessKind.grocery);
    expect(repository.current?.isConfigured, isTrue);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(await navigator.maybePop(), isFalse);
    expect(find.text('/customers/ana'), findsOneWidget);

    auth.close();
  });

  testWidgets('closing the app before finishing resumes setup', (tester) async {
    final repository = _MemorySetup()..current = BusinessSetup.pending(user.id);
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pumpAndSettle();
    expect(find.text('Qual é o tipo do seu negócio?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = await signedIn();
    await pumpGate(tester, auth: reopened, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Qual é o tipo do seu negócio?'), findsOneWidget);
    expect(find.text('/customers/ana'), findsNothing);
    expect(repository.saves, 0);

    auth.close();
    reopened.close();
  });

  testWidgets('a configured account opens the inner route directly', (
    tester,
  ) async {
    final repository = _MemorySetup()..current = BusinessSetup.legacy(user.id);
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Qual é o tipo do seu negócio?'), findsNothing);
    expect(find.text('/customers/ana'), findsOneWidget);
    expect(find.bySemanticsLabel('Verificando sessão'), findsNothing);

    auth.close();
  });

  testWidgets('a failed save keeps the selection and allows another try', (
    tester,
  ) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.pending(user.id)
      ..failTimes = 1;
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('business_kind_cleaning')));
    await tester.pump();
    await tapOn(tester, find.byKey(const Key('business_setup_continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('business_setup_error')), findsOneWidget);
    expect(
      find.byKey(const Key('business_kind_selected_cleaning')),
      findsOneWidget,
    );
    expect(find.text('/customers/ana'), findsNothing);
    expect(repository.current?.status, BusinessSetupStatus.pending);

    await tapOn(tester, find.byKey(const Key('business_setup_continue')));
    await tester.pumpAndSettle();

    expect(find.text('/customers/ana'), findsOneWidget);
    expect(repository.current?.kind, BusinessKind.cleaning);
    expect(repository.saves, 2);

    auth.close();
  });

  testWidgets('repeated taps save the business once', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.pending(user.id)
      ..delay = const Duration(milliseconds: 300);
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('business_kind_apparel')));
    await tester.pump();
    final continueButton = find.byKey(const Key('business_setup_continue'));
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.saves, 1);
    expect(repository.current?.kind, BusinessKind.apparel);
    final ids = repository.current!.categories.map((item) => item.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(find.text('/customers/ana'), findsOneWidget);

    auth.close();
  });

  testWidgets('the home shell stays hidden while setup is loading', (
    tester,
  ) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.pending(user.id)
      ..readDelay = const Duration(milliseconds: 200);
    final auth = await signedIn();

    await pumpGate(tester, auth: auth, repository: repository);
    await tester.pump();

    expect(find.bySemanticsLabel('Verificando sessão'), findsOneWidget);
    expect(find.text('/customers/ana'), findsNothing);
    expect(find.text('Qual é o tipo do seu negócio?'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Qual é o tipo do seu negócio?'), findsOneWidget);

    auth.close();
  });

  testWidgets('hortifruti keeps the leaf chrome', (tester) async {
    final repository = _MemorySetup()..current = BusinessSetup.legacy(user.id);
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => ColoredBox(
          key: const Key('chrome'),
          color: pouChromeColor(context),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouLeafChrome,
    );

    auth.close();
  });

  testWidgets('other business types use the neutral brand chrome', (
    tester,
  ) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.grocery,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => ColoredBox(
          key: const Key('chrome'),
          color: pouChromeColor(context),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouBrand,
    );

    auth.close();
  });

  testWidgets('cleaning uses the petrol water chrome', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.cleaning,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => Column(
          children: [
            ColoredBox(
              key: const Key('chrome'),
              color: pouChromeColor(context),
              child: const SizedBox(width: 8, height: 8),
            ),
            SizedBox(width: 40, height: 40, child: pouChromeFill(context)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouCleaningChrome,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, pouCleaningNavAsset);
    expect(image.alignment, Alignment.topCenter);
    expect(
      Theme.of(tester.element(find.byKey(const Key('chrome'))))
          .colorScheme
          .primary,
      pouCleaning,
    );

    auth.close();
  });

  testWidgets('marmitas uses the graphite tray chrome', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.meals,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => Column(
          children: [
            ColoredBox(
              key: const Key('chrome'),
              color: pouChromeColor(context),
              child: const SizedBox(width: 8, height: 8),
            ),
            SizedBox(width: 40, height: 40, child: pouChromeFill(context)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouMealsChrome,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, pouMealsNavAsset);
    expect(image.alignment, Alignment.center);
    expect(
      Theme.of(tester.element(find.byKey(const Key('chrome'))))
          .colorScheme
          .primary,
      pouMeals,
    );

    auth.close();
  });

  testWidgets('pizzas uses the red crust chrome', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.pizzas,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => Column(
          children: [
            ColoredBox(
              key: const Key('chrome'),
              color: pouChromeColor(context),
              child: const SizedBox(width: 8, height: 8),
            ),
            SizedBox(width: 40, height: 40, child: pouChromeFill(context)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouPizzasChrome,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, pouPizzasNavAsset);
    expect(image.alignment, Alignment.center);
    expect(
      Theme.of(tester.element(find.byKey(const Key('chrome'))))
          .colorScheme
          .primary,
      pouPizzas,
    );

    auth.close();
  });

  testWidgets('lanches uses the toasted burger chrome', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.snacks,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => Column(
          children: [
            ColoredBox(
              key: const Key('chrome'),
              color: pouChromeColor(context),
              child: const SizedBox(width: 8, height: 8),
            ),
            SizedBox(width: 40, height: 40, child: pouChromeFill(context)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouSnacksChrome,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, pouSnacksNavAsset);
    expect(image.alignment, Alignment.center);
    expect(
      Theme.of(tester.element(find.byKey(const Key('chrome'))))
          .colorScheme
          .primary,
      pouSnacks,
    );

    auth.close();
  });

  testWidgets('bolos de pote uses the cocoa cup chrome', (tester) async {
    final repository = _MemorySetup()
      ..current = BusinessSetup.configured(
        userId: user.id,
        kind: BusinessKind.cakes,
      );
    final auth = await signedIn();

    await pumpGate(
      tester,
      auth: auth,
      repository: repository,
      child: Builder(
        builder: (context) => Column(
          children: [
            ColoredBox(
              key: const Key('chrome'),
              color: pouChromeColor(context),
              child: const SizedBox(width: 8, height: 8),
            ),
            SizedBox(width: 40, height: 40, child: pouChromeFill(context)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouCakesChrome,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, pouCakesNavAsset);
    expect(image.alignment, Alignment.center);
    expect(
      Theme.of(tester.element(find.byKey(const Key('chrome'))))
          .colorScheme
          .primary,
      pouCakes,
    );

    auth.close();
  });
}

class _MemorySetup implements BusinessSetupRepository {
  BusinessSetup? current;
  var saves = 0;
  var failTimes = 0;
  Duration delay = Duration.zero;
  Duration readDelay = Duration.zero;

  @override
  Future<Either<Failure, BusinessSetup>> read(String userId) async {
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    return Right(current ?? BusinessSetup.legacy(userId));
  }

  @override
  Future<Either<Failure, BusinessSetup>> save({
    required String userId,
    required BusinessKind kind,
  }) async {
    saves += 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failTimes > 0) {
      failTimes -= 1;
      return const Left(NetworkFailure());
    }
    final setup = BusinessSetup.configured(userId: userId, kind: kind);
    current = setup;
    return Right(setup);
  }
}
