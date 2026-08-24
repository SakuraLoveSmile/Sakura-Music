import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/settings_repository.dart';
import 'package:sakuramusic/features/settings/membership_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('MembershipController defaults to inactive and activates with valid code', () async {
    final controller = container.read(membershipControllerProvider.notifier);
    final initial = await container.read(membershipControllerProvider.future);
    expect(initial.active, isFalse);
    expect(initial.method, isNull);

    final wrongResult = await controller.activateWithCode('invalid_code');
    expect(wrongResult, isFalse);
    expect(container.read(membershipControllerProvider).value?.active, isFalse);

    final validResult = await controller.activateWithCode('  sakurasep  ');
    expect(validResult, isTrue);
    final activatedState = container.read(membershipControllerProvider).value;
    expect(activatedState?.active, isTrue);
    expect(activatedState?.method, 'code');

    await controller.deactivate();
    final deactivatedState = container.read(membershipControllerProvider).value;
    expect(deactivatedState?.active, isFalse);
    expect(deactivatedState?.method, isNull);
  });

  test('MembershipController activates and deactivates via Star toggle', () async {
    final controller = container.read(membershipControllerProvider.notifier);
    await container.read(membershipControllerProvider.future);

    await controller.setStarActivation(true);
    final starState = container.read(membershipControllerProvider).value;
    expect(starState?.active, isTrue);
    expect(starState?.method, 'star');

    await controller.setStarActivation(false);
    final inactiveState = container.read(membershipControllerProvider).value;
    expect(inactiveState?.active, isFalse);
    expect(inactiveState?.method, isNull);
  });

  testWidgets('MembershipScreen renders activation cards and allows activating', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MembershipScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify unactivated cards
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    // Enter wrong code
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(container.read(membershipControllerProvider).value?.active, isFalse);

    // Enter correct code
    await tester.enterText(find.byType(TextField), 'sakurasep');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Verify activated state
    expect(container.read(membershipControllerProvider).value?.active, isTrue);
    expect(container.read(membershipControllerProvider).value?.method, 'code');
  });
}
