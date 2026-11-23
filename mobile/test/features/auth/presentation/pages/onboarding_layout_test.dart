import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/auth/presentation/pages/welcome_page.dart';

void main() {
  testWidgets('keeps the actions reachable on a short screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          );
        },
        home: WelcomePage(onLogin: () {}, onRegister: () {}),
      ),
    );
    await tester.pump();

    expect(find.textContaining('ORGANIZAR'), findsOneWidget);
    expect(find.textContaining('SEUS PRODUTOS'), findsOneWidget);
    expect(find.textContaining('Monte seu catálogo'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('welcome_order_now')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding_start')));
    await tester.pump();

    expect(find.byKey(const Key('welcome_order_now')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_start')), findsOneWidget);
  });
}
