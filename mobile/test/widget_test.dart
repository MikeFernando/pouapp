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
        'ana.souza@pouapp.dev',
      );
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'senha-dev',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_mode_rua')), findsOneWidget);

      await tester.pumpWidget(const PouApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace_mode_rua')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsNothing);

      tester
          .element(find.byKey(const Key('workspace_mode_rua')))
          .read<AuthBloc>()
          .add(const AuthLogoutRequested());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.text('Ana Souza'), findsNothing);
    },
  );
}
