import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';

void main() {
  for (final texts in [('41', '42'), ('Copy', 'Copied'), ('Copied', 'Copy')]) {
    testWidgets('single label compute ${texts.$1} -> ${texts.$2}',
        (tester) async {
      Widget frame(String text) => Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: ReelText(
                text,
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 24),
                options: const ReelTextOptions(
                  duration: Duration(milliseconds: 200),
                  stagger: Duration(milliseconds: 30),
                  exitOffset: Duration.zero,
                  bounce: 0,
                  color: Colors.blue,
                  colorFade: Duration(milliseconds: 400),
                ),
              ),
            ),
          );

      await tester.pumpWidget(frame(texts.$1));
      await tester.pumpWidget(frame(texts.$2));
      await tester.pump();
      final surface = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      );
      final initial = (surface as dynamic).debugGeometryCalculationCount as int;
      final startWidth = surface.size.width;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final afterMotion =
          (surface as dynamic).debugGeometryCalculationCount as int;
      final finalWidth = surface.size.width;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final afterFade =
          (surface as dynamic).debugGeometryCalculationCount as int;
      expect(afterFade, afterMotion,
          reason: 'Color fading must not recalculate settled widths');
      if (texts.$1.length == texts.$2.length) {
        expect(afterMotion, initial,
            reason: 'Tabular counter digits keep their geometry during motion');
      }
      expect(surface.size.width, finalWidth);
      if (texts.$2.length > texts.$1.length) {
        expect(finalWidth, greaterThan(startWidth));
      } else if (texts.$2.length < texts.$1.length) {
        expect(finalWidth, lessThan(startWidth));
      }
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      final idleCount = (surface as dynamic).debugGeometryCalculationCount;
      await tester.pump(const Duration(seconds: 1));
      expect((surface as dynamic).debugGeometryCalculationCount, idleCount);
      // A subsequent transition must invalidate the retained final geometry.
      await tester.pumpWidget(frame('${texts.$2}!'));
      await tester.pumpAndSettle();
      expect(surface.size.width, greaterThan(finalWidth));
      expect(tester.takeException(), isNull);
    });
  }
}
