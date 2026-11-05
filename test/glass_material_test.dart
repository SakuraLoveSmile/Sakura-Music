import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/widgets/glass.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  bool highContrast = false,
}) => MaterialApp(
  theme: ThemeData.dark().copyWith(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('Android edge blur needs only one clipped backdrop pass', (
    tester,
  ) async {
    for (final bottom in [false, true]) {
      await tester.pumpWidget(
        _app(ProgressiveGlassBlur(height: 80, bottom: bottom)),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(ProgressiveGlassBlur)).height, 80);
    }
  });

  testWidgets('other platforms retain progressive blur and contrast bypass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ProgressiveGlassBlur(), platform: TargetPlatform.iOS),
    );
    expect(find.byType(BackdropFilter).evaluate().length, greaterThan(1));
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ProgressiveGlassBlur(),
              GlassSurface(child: SizedBox.square(dimension: 44)),
            ],
          ),
          platform: platform,
          highContrast: true,
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });

  testWidgets(
    'glass controls keep their touch target without backdrop passes',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        _app(
          GlassSurface(
            blur: false,
            child: GlassIconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play',
              size: 24,
              onPressed: () => presses++,
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getSize(find.byType(IconButton)), const Size(44, 44));
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(presses, 1);
    },
  );
}
