import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pouapp/features/auth/presentation/bloc/auth_event.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('should display the application name and description', (
    tester,
  ) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();

    expect(find.text('PouApp'), findsOneWidget);
    expect(find.text('Sistema de Gestão Empresarial'), findsOneWidget);
  });

  testWidgets(
    'should sign in with the simulated account, restore it and sign out',
    (tester) async {
      await tester.pumpWidget(const PouApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email')),
        'mike@gmail.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'mike@123',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_home')), findsOneWidget);

      await tester.pumpWidget(const PouApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_home')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsNothing);

      tester
          .element(find.byKey(const Key('workspace_home')))
          .read<AuthBloc>()
          .add(const AuthLogoutRequested());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.text('Mike'), findsNothing);
    },
  );

  testWidgets('should create an account and enter the workspace', (
    tester,
  ) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_account')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register_name')),
      'Carla Lima',
    );
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'carla@pouapp.dev',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'senha-nova',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace_home')), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsWidgets);
  });
}
