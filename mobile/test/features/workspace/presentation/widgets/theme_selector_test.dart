import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/app/business_look.dart';
import 'package:pouapp/app/business_theme_scope.dart';
import 'package:pouapp/app/pou_app_colors.dart';
import 'package:pouapp/features/auth/domain/entities/user.dart';
import 'package:pouapp/features/business/data/datasources/business_theme_store.dart';
import 'package:pouapp/features/business/domain/entities/business_setup.dart';
import 'package:pouapp/features/workspace/presentation/widgets/pou_drawer_3d.dart';
import 'package:pouapp/features/workspace/presentation/widgets/theme_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme names follow the business type labels', () {
    expect(
      pouThemeLabel(PouChrome.botanical),
      businessKindLabel(BusinessKind.hortifruti),
    );
    expect(
      pouThemeLabel(PouChrome.cleaning),
      businessKindLabel(BusinessKind.cleaning),
    );
    expect(
      pouThemeLabel(PouChrome.meals),
      businessKindLabel(BusinessKind.meals),
    );
    expect(
      pouThemeLabel(PouChrome.pizzas),
      businessKindLabel(BusinessKind.pizzas),
    );
    expect(pouSelectableThemes, [
      PouChrome.botanical,
      PouChrome.cleaning,
      PouChrome.meals,
      PouChrome.pizzas,
      PouChrome.snacks,
      PouChrome.cakes,
    ]);
    expect(pouThemeLetter(PouChrome.botanical), 'H');
    expect(pouThemeLetter(PouChrome.cleaning), 'L');
    expect(pouThemeLetter(PouChrome.meals), 'M');
    expect(pouThemeLetter(PouChrome.pizzas), 'P');
    expect(pouThemeLetter(PouChrome.snacks), 'X');
    expect(pouThemeLetter(PouChrome.cakes), 'B');
    expect(
      pouThemeLabel(PouChrome.snacks),
      businessKindLabel(BusinessKind.snacks),
    );
    expect(
      pouThemeLabel(PouChrome.cakes),
      businessKindLabel(BusinessKind.cakes),
    );
  });

  testWidgets(
    'starts from the business type and keeps the eye row independent',
    (tester) async {
      final themes = await _store();
      await _pump(tester, themes);

      expect(find.text('H'), findsOneWidget);
      expect(find.text('Hortifruti'), findsNothing);
      expect(find.bySemanticsLabel('Hortifruti'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('profile_avatar'))),
        const Size(32, 32),
      );
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const Key('theme_selector')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, pouThemeChip(PouChrome.botanical).background);
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
        pouLeafChrome,
      );
    },
  );

  testWidgets('the profile photo opens the 3D menu with the options', (
    tester,
  ) async {
    final themes = await _store();
    await _pump(tester, themes);

    expect(
      tester
          .widget<Transform>(find.byKey(const Key('pou_drawer_front')))
          .transform
          .isIdentity(),
      isTrue,
    );

    await tester.tap(find.text('H'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Transform>(find.byKey(const Key('pou_drawer_front')))
          .transform
          .isIdentity(),
      isFalse,
    );
    expect(find.text('ALTERNAR NEGÓCIO'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('Hortifruti'), findsOneWidget);
    expect(find.text('Produtos de limpeza'), findsOneWidget);
    expect(find.text('Marmitas'), findsOneWidget);
    expect(find.text('Pizzas'), findsOneWidget);
    expect(find.text('Lanches'), findsOneWidget);
    expect(find.text('Bolos de pote'), findsOneWidget);
    expect(find.byIcon(Icons.cake_outlined), findsOneWidget);
    expect(find.byIcon(Icons.fastfood_outlined), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    expect(find.byIcon(Icons.soup_kitchen_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_pizza_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('MEU PERFIL'), findsOneWidget);
    expect(find.text('Alterar foto do perfil'), findsOneWidget);
    expect(find.byKey(const Key('profile_menu_settings')), findsOneWidget);
    expect(find.byKey(const Key('profile_menu_logout')), findsOneWidget);
  });

  testWidgets('choosing a theme updates the home chrome and survives reopen', (
    tester,
  ) async {
    final themes = await _store();
    await _pump(tester, themes);

    await tester.tap(find.byKey(const Key('theme_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme_option_cleaning')));
    await tester.pumpAndSettle();

    expect(find.text('L'), findsOneWidget);
    expect(find.text('Produtos de limpeza'), findsNothing);
    expect(find.bySemanticsLabel('Produtos de limpeza'), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouCleaningChrome,
    );
    expect(themes.read('biz-1'), PouChrome.cleaning);
    expect(themes.read('biz-2'), isNull);

    await _pump(tester, themes, userId: 'biz-1');
    expect(find.text('L'), findsOneWidget);
    expect(find.bySemanticsLabel('Produtos de limpeza'), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('chrome'))).color,
      pouCleaningChrome,
    );

    await _pump(tester, themes, userId: 'biz-2');
    expect(find.text('H'), findsOneWidget);
    expect(find.bySemanticsLabel('Hortifruti'), findsOneWidget);
  });
}

Future<BusinessThemeStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return BusinessThemeStore(sharedPreferences: prefs);
}

Future<void> _pump(
  WidgetTester tester,
  BusinessThemeStore themes, {
  String userId = 'biz-1',
  PouChrome fallback = PouChrome.botanical,
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BusinessThemeScope(
        userId: userId,
        fallback: fallback,
        suggestions: const [],
        store: themes,
        child: PouDrawer3D(
          user: User(id: userId, name: 'Mike', email: 'mike@pou.app'),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ThemeSelector(userId: userId),
                    Builder(
                      builder: (context) => ColoredBox(
                        key: const Key('chrome'),
                        color: pouChromeColor(context),
                        child: const SizedBox(width: 4, height: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
