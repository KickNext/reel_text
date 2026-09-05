import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';

void main() {
  test('chromatic creates a stable hue sweep', () {
    final sweep = chromatic(from: 20, spread: 120);

    expect(sweep(0, 3), isA<Color>());
    expect(sweep(0, 3), isNot(sweep(2, 3)));
    expect(sweep(0, 1), sweep(0, 1));
  });

  test('copyWith can replace inherited color mode', () {
    final options = ReelTextOptions(colorBuilder: chromatic());
    final replaced = options.copyWith(
      clearColor: true,
      color: const Color(0xff38bdf8),
    );

    expect(replaced.color, const Color(0xff38bdf8));
    expect(replaced.colorBuilder, isNull);
  });

  test('options helpers replace color modes and reverse direction', () {
    final base = ReelTextOptions(
      direction: ReelTextDirection.up,
      colorBuilder: chromatic(from: 20),
    );

    final tinted = base.withColor(const Color(0xff38bdf8));
    expect(tinted.color, const Color(0xff38bdf8));
    expect(tinted.colorBuilder, isNull);
    expect(tinted.direction, ReelTextDirection.up);

    final chromaticOptions = tinted.withChromatic(from: 40, spread: 80);
    expect(chromaticOptions.color, isNull);
    expect(chromaticOptions.colorBuilder!(0, 2), isA<Color>());

    final plain = chromaticOptions.withoutColor();
    expect(plain.color, isNull);
    expect(plain.colorBuilder, isNull);

    expect(plain.reversed().direction, ReelTextDirection.down);
  });

  test('animation options reject negative durations', () {
    final controller = ReelTextController(initialText: 'One');
    addTearDown(controller.dispose);

    expect(
      () => controller.set(
        'Two',
        options: const ReelTextOptions(
          stagger: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => controller.set(
        'Two',
        options: const ReelTextOptions(
          duration: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => controller.set(
        'Two',
        options: const ReelTextOptions(
          exitOffset: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => controller.set(
        'Two',
        options: const ReelTextOptions(
          colorFade: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => controller.flash(
        'Two',
        options: const ReelTextFlashOptions(
          revertAfter: Duration(microseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('controller progress rejects non-positive intervals', () {
    final controller = ReelTextController(initialText: 'One');
    addTearDown(controller.dispose);
    expect(
      () => controller.startProgress('One', interval: Duration.zero),
      throwsArgumentError,
    );
  });

  testWidgets('sequence rejects non-positive intervals', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.sequence(
          values: ['One', 'Two'],
          interval: Duration.zero,
        ),
      ),
    );

    expect(tester.takeException(), isArgumentError);
  });

  testWidgets('renders settled text without animation on first build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText('Copy'),
      ),
    );

    expect(find.bySemanticsLabel('Copy'), findsOneWidget);
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
  });

  testWidgets('sequence cycles values on its interval', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.sequence(
          values: ['One', 'Two'],
          interval: Duration(milliseconds: 50),
        ),
      ),
    );

    expect(find.bySemanticsLabel('One'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.bySemanticsLabel('Two'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.bySemanticsLabel('One'), findsOneWidget);
  });

  testWidgets('sequence optionsBuilder receives the next index and value', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.sequence(
          values: const ['A', 'B'],
          interval: const Duration(milliseconds: 50),
          optionsBuilder: (index, value) {
            calls.add('$index:$value');
            return const ReelTextOptions(duration: Duration(milliseconds: 20));
          },
        ),
      ),
    );

    expect(calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 60));
    expect(calls, ['1:B']);
  });

  testWidgets('first settled frame keeps the full text run width', (
    tester,
  ) async {
    const style = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.8,
    );
    const text = 'AVATAR';

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ReelText(text, style: style)),
      ),
    );

    final painter = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    expect(tester.getSize(find.byType(ReelText)).width, painter.size.width);
  });

  testWidgets('settled layout matches Text size exactly', (tester) async {
    const reelKey = ValueKey('reel_exact_size');
    const textKey = ValueKey('text_exact_size');
    const text = 'Draft 42';
    const style = TextStyle(
      fontSize: 38,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(text, key: reelKey, style: style),
              Text(text, key: textKey, style: style),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );
  });

  testWidgets('settled layout exposes Text-like alphabetic baseline', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_baseline_reel');
    const textKey = ValueKey('reel_baseline_text');
    const text = 'Invite copied';
    const style = TextStyle(fontSize: 13, height: 1);
    const strut = StrutStyle(fontSize: 13, height: 1, forceStrutHeight: true);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(text, key: textKey, style: style, strutStyle: strut),
            ReelText(text, key: reelKey, style: style, strutStyle: strut),
          ],
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(reelKey)).dy,
      tester.getTopLeft(find.byKey(textKey)).dy,
    );

    final reelBox = tester.renderObject<RenderBox>(find.byKey(reelKey));
    final textBox = tester.renderObject<RenderBox>(find.byKey(textKey));
    final reelSize = tester.getSize(find.byKey(reelKey));
    final textSize = tester.getSize(find.byKey(textKey));
    final dryBaseline = _dryBaselineFor(
      reelBox,
      BoxConstraints.tight(reelSize),
      TextBaseline.alphabetic,
    );
    final textDryBaseline = _dryBaselineFor(
      textBox,
      BoxConstraints.tight(textSize),
      TextBaseline.alphabetic,
    );
    if (dryBaseline != null && textDryBaseline != null) {
      expect(dryBaseline, closeTo(textDryBaseline, 0.001));
    }
  });

  testWidgets('rolling layout exposes Text-like alphabetic baseline', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rolling_baseline_reel');
    const textKey = ValueKey('reel_rolling_baseline_text');
    const style = TextStyle(fontSize: 13, height: 1);
    const strut = StrutStyle(fontSize: 13, height: 1, forceStrutHeight: true);
    final controller = ReelTextController(initialText: 'Cart updated');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Invite copied',
              key: textKey,
              style: style,
              strutStyle: strut,
            ),
            ReelText.controller(
              key: reelKey,
              controller: controller,
              style: style,
              strutStyle: strut,
              options: const ReelTextOptions(
                duration: Duration(milliseconds: 120),
                stagger: Duration.zero,
              ),
            ),
          ],
        ),
      ),
    );

    controller.set('Invite copied');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(reelKey)).dy,
      tester.getTopLeft(find.byKey(textKey)).dy,
    );

    final reelBox = tester.renderObject<RenderBox>(find.byKey(reelKey));
    final textBox = tester.renderObject<RenderBox>(find.byKey(textKey));
    final reelSize = tester.getSize(find.byKey(reelKey));
    final textSize = tester.getSize(find.byKey(textKey));
    final dryBaseline = _dryBaselineFor(
      reelBox,
      BoxConstraints.tight(reelSize),
      TextBaseline.alphabetic,
    );
    final textDryBaseline = _dryBaselineFor(
      textBox,
      BoxConstraints.tight(textSize),
      TextBaseline.alphabetic,
    );
    if (dryBaseline != null && textDryBaseline != null) {
      expect(dryBaseline, closeTo(textDryBaseline, 0.001));
    }
  });

  testWidgets('settled glyph subtree is reused across parent rebuilds', (
    tester,
  ) async {
    var revision = 0;
    late StateSetter rebuildParent;
    final textScaler = _CountingTextScaler();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuildParent = setState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('revision $revision'),
                MediaQuery(
                  data: MediaQueryData(textScaler: textScaler),
                  child: ReelText(
                    'Stable',
                    style: _textStyle(18),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final initialScaleCalls = textScaler.calls;
    expect(initialScaleCalls, greaterThan(0));
    rebuildParent(() {
      revision++;
    });
    await tester.pump();

    expect(textScaler.calls, initialScaleCalls);
  });

  testWidgets('roll reuses settled and target frame measurements', (
    tester,
  ) async {
    const reelKey = ValueKey('measurement_cache_reel');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text, {double fontSize = 18}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText(
          text,
          key: reelKey,
          options: options,
          style: _textStyle(fontSize),
        ),
      );
    }

    await tester.pumpWidget(frame('Alpha'));
    final state = tester.state(find.byKey(reelKey));
    expect((state as dynamic).debugFrameMeasureCount as int, 1);

    await tester.pumpWidget(frame('Bravo'));
    expect((state as dynamic).debugFrameMeasureCount as int, 2);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    expect((state as dynamic).debugFrameMeasureCount as int, 2);

    await tester.pumpWidget(frame('Delta'));
    expect((state as dynamic).debugFrameMeasureCount as int, 3);

    await tester.pumpAndSettle();
    await tester.pumpWidget(frame('Alpha'));
    expect((state as dynamic).debugFrameMeasureCount as int, 3);

    await tester.pumpAndSettle();
    await tester.pumpWidget(frame('Echo', fontSize: 24));
    expect((state as dynamic).debugFrameMeasureCount as int, 5);
  });

  testWidgets('settled locale layout matches Text size exactly', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_locale_size');
    const textKey = ValueKey('text_locale_size');
    const text = '漢字かな';
    const locale = Locale('ja');
    const style = TextStyle(
      fontSize: 34,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(text, key: reelKey, style: style, locale: locale),
              Text(text, key: textKey, style: style, locale: locale),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );
  });

  testWidgets('inherits locale changes for measurement cache keys', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_inherited_locale');

    Widget frame(Locale locale) {
      return Localizations(
        locale: locale,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ReelText('Locale', key: reelKey),
        ),
      );
    }

    await tester.pumpWidget(frame(const Locale('en')));
    final state = tester.state(find.byKey(reelKey));
    expect((state as dynamic).debugFrameMeasureCount as int, 1);

    await tester.pumpWidget(frame(const Locale('ja')));
    expect((state as dynamic).debugFrameMeasureCount as int, 2);
  });

  testWidgets('mixed bidi labels keep Text-like size and semantics', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bidi_size');
    const textKey = ValueKey('text_bidi_size');
    const text = 'ETA 12 שלום';
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(text, key: reelKey, style: style),
              ExcludeSemantics(
                child: Text(text, key: textKey, style: style),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(text), findsOneWidget);
    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );
  });

  testWidgets('settled mixed bidi glyphs follow Flutter visual order', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bidi_visual_order');
    const text = 'ETA 12 שלום';
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);

    await tester.pumpWidget(
      const Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText(text, key: reelKey, style: style),
        ),
      ),
    );

    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      _textPainterGlyphsLeftToRight(
        text: text,
        style: style,
        textDirection: direction,
      ),
    );
  });

  testWidgets('mixed bidi roll keeps unchanged glyphs in visual order', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bidi_rolling_order');
    const fromText = 'AB שלום';
    const toText = 'AC שלום';
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame(fromText));
    await tester.pumpWidget(frame(toText));
    await tester.pump(const Duration(milliseconds: 60));

    final actualStableGlyphs = _visibleReelGlyphsLeftToRight(
      tester,
      find.byKey(reelKey),
    ).where((glyph) => glyph != 'B' && glyph != 'C').toList();
    final expectedStableGlyphs = _textPainterGlyphsLeftToRight(
      text: toText,
      style: style,
      textDirection: direction,
    ).where((glyph) => glyph != 'C').toList();

    expect(actualStableGlyphs, expectedStableGlyphs);
  });

  testWidgets('RTL roll keeps source visual order on its first frame', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rtl_first_frame_order');
    const fromText = 'אבגד';
    const toText = 'אבג';
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 34, fontWeight: FontWeight.w700);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame(fromText));
    final sourceOrder = _visibleReelGlyphsLeftToRight(
      tester,
      find.byKey(reelKey),
    );

    await tester.pumpWidget(frame(toText));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      sourceOrder,
    );

    await tester.pumpAndSettle();

    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      _textPainterGlyphsLeftToRight(
        text: toText,
        style: style,
        textDirection: direction,
      ),
    );
  });

  testWidgets('mixed bidi roll keeps source visual order on its first frame', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_mixed_bidi_first_frame_order');
    const fromText = 'ETA 12 דק';
    const toText = 'ETA 12';
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame(fromText));
    final sourceOrder = _visibleReelGlyphsLeftToRight(
      tester,
      find.byKey(reelKey),
    );

    await tester.pumpWidget(frame(toText));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      sourceOrder,
    );

    await tester.pumpAndSettle();

    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      _textPainterGlyphsLeftToRight(
        text: toText,
        style: style,
        textDirection: direction,
      ),
    );
  });

  testWidgets(
    'mixed bidi rolling uses visual slots without positioned correction',
    (tester) async {
      const reelKey = ValueKey('reel_mixed_bidi_no_positioned');
      const fromText = 'ETA 12 דק';
      const toText = 'ETA 12';
      const direction = TextDirection.rtl;
      const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
      const options = ReelTextOptions(
        duration: Duration(milliseconds: 140),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
        bounce: 0,
        colorFade: Duration.zero,
      );

      Widget frame(String text) {
        return Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: 280,
              child: ReelText(
                text,
                key: reelKey,
                textAlign: TextAlign.start,
                style: style,
                options: options,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(frame(fromText));
      await tester.pumpWidget(frame(toText));

      expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reel_text_rolling')),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'mixed bidi stable glyphs keep their horizontal positions during roll',
    (tester) async {
      const reelKey = ValueKey('reel_mixed_bidi_stable_x');
      const fromText = 'ETA 12 דק';
      const toText = 'ETA 12';
      const direction = TextDirection.rtl;
      const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
      const options = ReelTextOptions(
        duration: Duration(milliseconds: 140),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      );

      Widget frame(String text) {
        return Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: 280,
              child: ReelText(
                text,
                key: reelKey,
                textAlign: TextAlign.start,
                style: style,
                options: options,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(frame(fromText));
      await tester.pumpWidget(frame(toText));

      final firstFrame = _visibleReelGlyphPositionsLeftToRight(
        tester,
        find.byKey(reelKey),
      );

      await tester.pump(const Duration(milliseconds: 70));

      final midFrame = _visibleReelGlyphPositionsLeftToRight(
        tester,
        find.byKey(reelKey),
      );

      for (final glyph in ['E', 'T', 'A', '1', '2']) {
        expect(
          _leftOfGlyph(midFrame, glyph),
          closeTo(_leftOfGlyph(firstFrame, glyph), 0.01),
        );
      }
    },
  );

  testWidgets(
    'mixed bidi final rolling frame matches settled glyph positions',
    (tester) async {
      const reelKey = ValueKey('reel_mixed_bidi_final_x');
      const fromText = 'ETA 12 דק';
      const toText = 'ETA 12';
      const direction = TextDirection.rtl;
      const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
      const options = ReelTextOptions(
        duration: Duration(milliseconds: 140),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      );

      Widget frame(String text) {
        return Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: 280,
              child: ReelText(
                text,
                key: reelKey,
                textAlign: TextAlign.start,
                style: style,
                options: options,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(frame(fromText));
      await tester.pumpWidget(frame(toText));
      await tester.pump(const Duration(milliseconds: 219));

      final finalRollingFrame = _visibleReelGlyphPositionsLeftToRight(
        tester,
        find.byKey(reelKey),
      );
      final finalRollingGlyphs = [
        for (final entry in finalRollingFrame) entry.text,
      ];

      expect(
        finalRollingGlyphs,
        _textPainterGlyphsLeftToRight(
          text: toText,
          style: style,
          textDirection: direction,
        ),
      );

      await tester.pumpAndSettle();

      final settledFrame = _visibleReelGlyphPositionsLeftToRight(
        tester,
        find.byKey(reelKey),
      );

      for (final glyph in ['E', 'T', 'A', '1', '2']) {
        expect(
          _leftOfGlyph(finalRollingFrame, glyph),
          closeTo(_leftOfGlyph(settledFrame, glyph), 0.01),
        );
      }
    },
  );

  testWidgets('settled layout clamps to bounded width without flex overflow', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bounded_settled');
    const boxWidth = 136.0;
    const text = 'SHOWCASE';
    const style = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.2,
    );

    final painter = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(painter.size.width, greaterThan(boxWidth));

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: boxWidth,
            child: ReelText(text, key: reelKey, style: style),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(reelKey)).width, boxWidth);
    final settledSurface = tester.renderObject(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    ) as dynamic;
    expect(
      settledSurface.debugNaturalRowWidth as double,
      greaterThan(boxWidth),
    );
  });

  testWidgets('settled WidgetSpan layout clamps to bounded width', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bounded_widget_settled');
    const boxWidth = 88.0;
    const widgetKey = ValueKey('reel_bounded_widget_child');
    const style = TextStyle(fontSize: 22, fontWeight: FontWeight.w900);
    const span = TextSpan(
      children: [
        TextSpan(text: 'READY '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 96, height: 18),
        ),
      ],
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: boxWidth,
            child: ReelText.rich(span, key: reelKey, style: style),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(reelKey)).width, boxWidth);
    expect(tester.getSize(find.byKey(widgetKey)).width, 96);
    final settledSurface = tester.renderObject(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    ) as dynamic;
    expect(
      settledSurface.debugNaturalRowWidth as double,
      greaterThan(boxWidth),
    );
  });

  testWidgets('WidgetSpan uses its natural height in the first layout pass', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_tall_widget_settled');
    const widgetKey = ValueKey('reel_tall_widget_child');
    const span = TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 32, height: 64),
        ),
      ],
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText.rich(
            span,
            key: reelKey,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(widgetKey)).height, 64);
    expect(
        tester.getSize(find.byKey(reelKey)).height, greaterThanOrEqualTo(64));
  });

  testWidgets('rolling WidgetSpan layout clamps to bounded width', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_bounded_widget_rolling');
    const boxWidth = 88.0;
    const widgetKey = ValueKey('reel_bounded_rolling_widget_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    TextSpan spanFor(String text, {bool widgetSpan = false}) {
      return TextSpan(
        children: [
          TextSpan(text: text),
          if (widgetSpan)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(key: widgetKey, width: 96, height: 18),
            ),
        ],
      );
    }

    Widget frame(InlineSpan span) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: boxWidth,
            child: ReelText.rich(span, key: reelKey, options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(spanFor('READY ')));
    await tester.pumpWidget(frame(spanFor('READY ', widgetSpan: true)));
    await tester.pump(const Duration(milliseconds: 20));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(tester.getSize(find.byKey(reelKey)).width, boxWidth);
    expect(tester.getSize(find.byKey(widgetKey)).width, 96);
  });

  testWidgets('rolling layout width interpolates before matching target Text', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_exact_size');
    const textKey = ValueKey('text_exact_size');
    const style = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String reelText, String textText) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(reelText, key: reelKey, style: style, options: options),
              Text(textText, key: textKey, style: style),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('AI', 'AI writes ✨'));
    final initialWidth = tester.getSize(find.byKey(reelKey)).width;

    await tester.pumpWidget(frame('AI writes ✨', 'AI writes ✨'));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    final rollingWidth = tester.getSize(find.byKey(reelKey)).width;
    final targetSize = tester.getSize(find.byKey(textKey));

    expect(rollingWidth, greaterThan(initialWidth));
    expect(rollingWidth, lessThan(targetSize.width));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(reelKey)), targetSize);
  });

  testWidgets('rolling LTR text slots paint without slot builders', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    TextSpan spanFor(String middle) {
      return TextSpan(
        children: [
          TextSpan(text: 'a', style: _textStyle(11)),
          TextSpan(text: middle, style: _textStyle(17)),
          TextSpan(text: 'c', style: _textStyle(13)),
        ],
      );
    }

    Widget frame(String middle) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.rich(spanFor(middle), options: options),
      );
    }

    await tester.pumpWidget(frame('b'));
    await tester.pumpWidget(frame('x'));

    final rolling = find.byKey(const ValueKey('reel_text_rolling'));

    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(
      find.descendant(
        of: rolling,
        matching: find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: rolling, matching: find.byType(Text)),
        findsNothing);
  });

  testWidgets('rolling RTL text slots paint without slot builders', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ReelText(text, options: options),
      );
    }

    await tester.pumpWidget(frame('אבג'));
    await tester.pumpWidget(frame('אבד'));

    final rolling = find.byKey(const ValueKey('reel_text_rolling'));

    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(
      find.descendant(
        of: rolling,
        matching: find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('rolling text slot reuses prepared face layouts while painting', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText(text, options: options, style: _textStyle(32)),
      );
    }

    await tester.pumpWidget(frame('a'));
    await tester.pumpWidget(frame('b'));
    await tester.pump();

    final slot = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );
    final preparedLayouts = _debugPreparedFaceLayoutCount(slot);

    expect(preparedLayouts, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 60));
    expect(_debugPreparedFaceLayoutCount(slot), preparedLayouts);

    await tester.pump(const Duration(milliseconds: 60));
    expect(_debugPreparedFaceLayoutCount(slot), preparedLayouts);
  });

  testWidgets('RTL prepared text face tracks animated slot width', (
    tester,
  ) async {
    const options = ReelTextOptions(
      direction: ReelTextDirection.down,
      duration: Duration(milliseconds: 240),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      skipUnchanged: false,
    );
    const style = TextStyle(
      fontFamily: 'Ahem',
      fontSize: 48,
      height: 1,
      color: Colors.black,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 180,
          height: 120,
          child: Align(
            alignment: Alignment.topLeft,
            child: ReelText(text, options: options, style: style),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(''));
    await tester.pumpWidget(frame('A'));
    await tester.pump(const Duration(milliseconds: 100));

    final slot = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );
    final firstWidth = slot.size.width;
    final firstPaintDx = (slot as dynamic).debugPreparedToFaceDx as double;
    final firstCurrentDx = (slot as dynamic).debugCurrentToFaceDx as double;

    expect(firstPaintDx, closeTo(firstCurrentDx, 0.01));

    await tester.pump(const Duration(milliseconds: 60));

    final secondPaintDx = (slot as dynamic).debugPreparedToFaceDx as double;
    final secondCurrentDx = (slot as dynamic).debugCurrentToFaceDx as double;

    expect(slot.size.width, greaterThan(firstWidth + 1));
    expect((secondCurrentDx - firstCurrentDx).abs(), greaterThan(1));
    expect(
      secondPaintDx,
      closeTo(secondCurrentDx, 0.01),
    );
  });

  testWidgets('inserted glyph widths expand during a roll', (tester) async {
    const reelKey = ValueKey('reel_interpolated_width');
    const style = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.2,
    );
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 200),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      skipUnchanged: false,
    );

    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return painter.size.width;
    }

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    final fromWidth = textWidth('i');
    final toWidth = textWidth('iii');

    await tester.pumpWidget(frame('i'));
    await tester.pumpWidget(frame('iii'));
    await tester.pump(const Duration(milliseconds: 100));

    final rollingWidth =
        tester.getSize(find.byKey(const ValueKey('reel_text_rolling'))).width;

    expect(tester.getSize(find.byKey(reelKey)).width, rollingWidth);
    expect(rollingWidth, greaterThan(fromWidth));
    expect(rollingWidth, lessThan(toWidth));
  });

  testWidgets('painted rolling slots report intrinsic size during a roll', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_intrinsic_width_roll');
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 200),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      skipUnchanged: false,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IntrinsicWidth(
            child: ReelText(
              text,
              key: reelKey,
              style: style,
              options: options,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(''));
    await tester.pumpWidget(frame('A'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    final slotSize = tester.getSize(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );
    final reelSize = tester.getSize(find.byKey(reelKey));

    expect(slotSize.width, greaterThan(0));
    expect(reelSize.width, closeTo(slotSize.width, 0.01));
    expect(reelSize.height, closeTo(slotSize.height, 0.01));
  });

  testWidgets('colored rolling slots cache faces until their color fade', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 160),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      color: Colors.blue,
      skipUnchanged: false,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText(text, options: options, style: _textStyle(32)),
      );
    }

    await tester.pumpWidget(frame('A'));
    await tester.pumpWidget(frame('B'));
    await tester.pump();

    final slot = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );

    expect(_debugPreparedFaceLayoutCount(slot), greaterThan(0));
    expect(
      (slot as dynamic).debugDisposedTransientFaceLayoutCount as int,
      0,
    );

    await tester.pump(const Duration(milliseconds: 240));

    expect(
      (slot as dynamic).debugDisposedTransientFaceLayoutCount as int,
      greaterThan(0),
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      (slot as dynamic).debugDisposedPreparedFaceLayoutCount as int,
      greaterThan(0),
    );
  });

  testWidgets('glyph faces get paint bleed without reserving width', (
    tester,
  ) async {
    const reelKey = ValueKey('paint_bleed_reel');
    const style = TextStyle(fontSize: 112, fontWeight: FontWeight.w900);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 240),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      skipUnchanged: false,
    );

    final painter = TextPainter(
      text: const TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame(''));
    await tester.pumpWidget(frame('0'));
    await tester.pump(const Duration(milliseconds: 80));

    final rollingWidth = tester.getSize(find.byKey(reelKey)).width;
    final rollingSlot = find.byKey(
      const ValueKey('reel_text_rolling_text_slot'),
    );
    final rollingSlotRender = tester.renderObject(rollingSlot) as dynamic;

    expect(rollingWidth, greaterThan(0));
    expect(rollingWidth, lessThan(painter.size.width));
    expect(tester.getSize(rollingSlot).width, closeTo(rollingWidth, 0.01));
    expect(rollingSlotRender.debugHorizontalBleed, greaterThan(3));

    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(reelKey)).width,
      closeTo(painter.size.width, 0.01),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reel_text_settled_glyphs')))
          .width,
      closeTo(painter.size.width, 0.01),
    );
    final settledSurface = tester.renderObject(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    ) as dynamic;
    expect(settledSurface.debugHorizontalBleed as double, greaterThan(3));
  });

  testWidgets('internal glyph text ignores inherited textAlign', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 112, fontWeight: FontWeight.w900);

    await tester.pumpWidget(
      const DefaultTextStyle(
        style: TextStyle(),
        textAlign: TextAlign.end,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: ReelText('0', style: style)),
        ),
      ),
    );

    expect(
      find.descendant(of: find.byType(ReelText), matching: find.byType(Text)),
      findsNothing,
    );
    final positions = _visibleReelGlyphPositionsLeftToRight(
      tester,
      find.byType(ReelText),
    );
    expect(positions.single.text, '0');
  });

  testWidgets('complex emoji clusters match Text size and roll safely', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_emoji_size');
    const textKey = ValueKey('text_emoji_size');
    const text = 'Launch 👨‍👩‍👧‍👦 🧑🏽‍💻 👍🏽 🚀 ✨';
    const style = TextStyle(fontSize: 30, fontWeight: FontWeight.w700);

    Widget frame(String reelText) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(
                reelText,
                key: reelKey,
                style: style,
                options: const ReelTextOptions(
                  duration: Duration(milliseconds: 100),
                  stagger: Duration.zero,
                  exitOffset: Duration.zero,
                ),
              ),
              const ExcludeSemantics(
                child: Text(text, key: textKey, style: style),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('Launch 🚀'));
    await tester.pumpWidget(frame(text));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(text), findsOneWidget);
    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );
  });

  testWidgets('dense emoji clusters keep Text size after a large edit', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_many_emoji_size');
    const textKey = ValueKey('text_many_emoji_size');
    const text = 'Ready 👨‍👩‍👧‍👦 🧑🏽‍💻 👩‍🔬 🧪 🚀 ✨ ✅ ⚠️ 👍🏽';
    const style = TextStyle(fontSize: 26, fontWeight: FontWeight.w800);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 80),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget frame(String reelText) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelText(reelText, key: reelKey, style: style, options: options),
              const ExcludeSemantics(
                child: Text(text, key: textKey, style: style),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('Draft 👍🏽'));
    await tester.pumpWidget(frame(text));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );
  });

  testWidgets('SelectionArea lets an interactive WidgetSpan receive taps', (
    tester,
  ) async {
    const widgetKey = ValueKey('interactive_widget_span');
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          child: Center(
            child: ReelText.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Tap '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      key: widgetKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox(width: 48, height: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(widgetKey));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('selection surface strips foreground and background paints', (
    tester,
  ) async {
    final paintedStyle = TextStyle(
      foreground: Paint()..color = const Color(0x999f7aea),
      background: Paint()..color = const Color(0x5538b2ac),
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 3)),
      ],
      decoration: TextDecoration.underline,
      decorationColor: Colors.red,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          child: ReelText.rich(TextSpan(text: 'Paint', style: paintedStyle)),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    final root = paragraph.text as TextSpan;
    final transparentSpan = root.children!.single as TextSpan;
    final style = transparentSpan.style!;
    expect(style.foreground, isNull);
    expect(style.background, isNull);
    expect(style.color, Colors.transparent);
    expect(style.backgroundColor, Colors.transparent);
    expect(style.shadows, isEmpty);
    expect(style.decoration, TextDecoration.none);
  });

  testWidgets('exposes one full selectable text surface inside SelectionArea', (
    tester,
  ) async {
    const text = 'Select ReelText 👋';
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectionArea(
          child: Center(child: ReelText(text, style: style)),
        ),
      ),
    );

    final selectionSurface = find.byKey(
      const ValueKey('reel_text_selection_surface'),
    );

    expect(selectionSurface, findsOneWidget);
    expect(
      tester.getSize(selectionSurface),
      tester.getSize(find.byType(ReelText)),
    );

    final paragraph = tester.renderObject<RenderParagraph>(selectionSurface);
    expect(paragraph.text.toPlainText(), text);
    expect(paragraph.registrar, isNotNull);
  });

  testWidgets('selection surface preserves bounded textAlign constraints', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_selection_alignment_box');
    const text = 'Go 👍🏽';
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectionArea(
          child: Center(
            child: SizedBox(
              key: boxKey,
              width: 260,
              child: ReelText(text, textAlign: TextAlign.end, style: style),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byKey(boxKey));
    final glyphRow = tester.getRect(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    );
    final visualGlyphRight = _rightOfGlyph(
      _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
      '👍🏽',
    );

    expect(glyphRow.right, closeTo(box.right, 0.01));
    expect(visualGlyphRight, greaterThanOrEqualTo(box.right));
  });

  testWidgets('rich text keeps styled spans selectable as one text run', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_size');
    const textKey = ValueKey('text_rich_size');
    const plainText = 'Draft -> Evidence-backed rewrite';
    const span = TextSpan(
      children: [
        TextSpan(
          text: 'Draft',
          style: TextStyle(color: Colors.redAccent),
        ),
        TextSpan(text: ' -> '),
        TextSpan(
          text: 'Evidence-backed rewrite',
          style: TextStyle(
            color: Colors.lightGreenAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    const style = TextStyle(fontSize: 24, height: 1.25);

    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ReelText.rich(span, key: reelKey, style: style),
                ExcludeSemantics(
                  child: RichText(
                    key: textKey,
                    text: const TextSpan(style: style, children: [span]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(plainText), findsOneWidget);
    expect(
      tester.getSize(find.byKey(reelKey)),
      tester.getSize(find.byKey(textKey)),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    expect(paragraph.text.toPlainText(), plainText);
    expect(paragraph.registrar, isNotNull);
  });

  testWidgets('rich text renders WidgetSpan inside reel slots', (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_widget_span_child');
    const span = TextSpan(
      children: [
        TextSpan(text: 'Sync '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 18, height: 18),
        ),
        TextSpan(text: ' done'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectionArea(
          child: Center(
            child: ReelText.rich(span),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(widgetKey), findsOneWidget);
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    expect(find.byKey(const ValueKey('reel_text_widget_span')), findsNothing);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    final plainText = paragraph.text.toPlainText(includePlaceholders: false);
    expect(plainText, 'Sync  done');
    expect(paragraph.registrar, isNotNull);
  });

  testWidgets('rich text with WidgetSpan still rolls text updates', (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_widget_span_child');
    TextSpan spanFor(String text) {
      return TextSpan(
        children: [
          TextSpan(text: '$text '),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 18, height: 18),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(child: ReelText.rich(spanFor('Sync'))),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(child: ReelText.rich(spanFor('Done'))),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(find.byKey(const ValueKey('reel_text_widget_span')), findsNothing);
    expect(find.byKey(widgetKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    expect(paragraph.text.toPlainText(includePlaceholders: false), 'Done ');
  });

  testWidgets('rich text keeps pending WidgetSpan when interrupt is disabled', (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_pending_widget_span_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      interrupt: false,
    );

    TextSpan spanFor(String text) {
      return TextSpan(
        children: [
          TextSpan(text: '$text '),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 18, height: 18),
          ),
        ],
      );
    }

    Widget frame(String text) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(spanFor(text), options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('Sync'));
    await tester.pumpWidget(frame('Done'));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(frame('Ship'));
    await tester.pumpAndSettle();

    expect(find.byKey(widgetKey), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    expect(paragraph.text.toPlainText(includePlaceholders: false), 'Ship ');
  });

  testWidgets('rich text queues same-plain pending WidgetSpan update', (
    tester,
  ) async {
    const oldWidgetKey = ValueKey('reel_rich_pending_old_widget_child');
    const newWidgetKey = ValueKey('reel_rich_pending_new_widget_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      interrupt: false,
    );

    TextSpan spanFor(String text, Key widgetKey) {
      return TextSpan(
        children: [
          TextSpan(text: '$text '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 18, height: 18),
          ),
        ],
      );
    }

    Widget frame(String text, Key widgetKey) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(
              spanFor(text, widgetKey),
              options: options,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('Sync', oldWidgetKey));
    await tester.pumpWidget(frame('Done', oldWidgetKey));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(frame('Done', newWidgetKey));
    await tester.pumpAndSettle();

    expect(find.byKey(oldWidgetKey), findsNothing);
    expect(find.byKey(newWidgetKey), findsOneWidget);
  });

  testWidgets('rich text keeps WidgetSpan anchored when prefix length changes',
      (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_widget_anchor_child');
    TextSpan spanFor({
      required String prefix,
      required String badge,
      required String suffix,
    }) {
      return TextSpan(
        children: [
          TextSpan(text: '$prefix '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              key: widgetKey,
              width: badge.length * 8,
              height: 18,
            ),
          ),
          TextSpan(text: ' $suffix'),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(
              spanFor(prefix: 'Queued', badge: 'AI', suffix: 'check'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(
              spanFor(prefix: 'Reviewed', badge: 'QA', suffix: 'done'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(find.byKey(widgetKey), findsOneWidget);

    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    expect(
      paragraph.text.toPlainText(includePlaceholders: false),
      'Reviewed  done',
    );
  });

  testWidgets('rich text keeps colorBuilder totals valid for moved WidgetSpan',
      (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_color_total_widget');
    final colorCalls = <String>[];
    final options = ReelTextOptions(
      colorBuilder: (index, total) {
        if (index < 0 || index >= total) {
          throw StateError('colorBuilder received $index/$total');
        }
        colorCalls.add('$index/$total');
        return const Color(0xff38bdf8);
      },
    );

    TextSpan spanFor({required bool widgetAtEnd}) {
      const widget = WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(key: widgetKey, width: 18, height: 18),
      );
      return TextSpan(
        children: widgetAtEnd
            ? [
                const TextSpan(text: 'A'),
                const TextSpan(text: 'B'),
                widget,
              ]
            : [
                const TextSpan(text: 'A'),
                widget,
                const TextSpan(text: 'B'),
              ],
      );
    }

    Widget frame(InlineSpan span) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(span, options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(spanFor(widgetAtEnd: false)));
    await tester.pumpWidget(frame(spanFor(widgetAtEnd: true)));

    expect(tester.takeException(), isNull);
    expect(colorCalls, contains('3/4'));
  });

  testWidgets('rich text treats reordered keyed WidgetSpans as changed slots', (
    tester,
  ) async {
    const redKey = ValueKey('reel_rich_reorder_red_child');
    const blueKey = ValueKey('reel_rich_reorder_blue_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    WidgetSpan badge(Key key, double width) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(key: key, width: width, height: 18),
      );
    }

    TextSpan spanFor(List<WidgetSpan> badges) {
      return TextSpan(
        children: [
          const TextSpan(text: 'Status '),
          badges[0],
          const TextSpan(text: ' '),
          badges[1],
        ],
      );
    }

    Widget frame(List<WidgetSpan> badges) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(spanFor(badges), options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame([
      badge(redKey, 18),
      badge(blueKey, 28),
    ]));

    await tester.pumpWidget(frame([
      badge(blueKey, 28),
      badge(redKey, 18),
    ]));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(blueKey)).left,
      lessThan(tester.getRect(find.byKey(redKey)).left),
    );
  });

  testWidgets('rich text reorders GlobalKey WidgetSpans without duplicates', (
    tester,
  ) async {
    final redKey = GlobalKey();
    final blueKey = GlobalKey();
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    WidgetSpan badge(GlobalKey key, double width) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(key: key, width: width, height: 18),
      );
    }

    TextSpan spanFor(List<WidgetSpan> badges) {
      return TextSpan(
        children: [
          const TextSpan(text: 'Status '),
          badges[0],
          const TextSpan(text: ' '),
          badges[1],
        ],
      );
    }

    Widget frame(List<WidgetSpan> badges) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(spanFor(badges), options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame([
      badge(redKey, 18),
      badge(blueKey, 28),
    ]));

    await tester.pumpWidget(frame([
      badge(blueKey, 28),
      badge(redKey, 18),
    ]));
    await tester.pump(const Duration(milliseconds: 20));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich text keeps WidgetSpan RTL glyph order while rolling', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_widget_span_rtl_order');
    const widgetKey = ValueKey('reel_rich_widget_span_rtl_child');
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 34, fontWeight: FontWeight.w700);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    TextSpan spanFor(String text) {
      return TextSpan(
        children: [
          TextSpan(text: text),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 18, height: 18),
          ),
        ],
      );
    }

    Widget frame(String text) {
      return Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText.rich(
            spanFor(text),
            key: reelKey,
            style: style,
            options: options,
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('אבגד'));
    final sourceOrder = _visibleReelGlyphsLeftToRight(
      tester,
      find.byKey(reelKey),
    );

    await tester.pumpWidget(frame('אבג'));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(find.byKey(widgetKey), findsOneWidget);
    expect(
      _visibleReelGlyphsLeftToRight(tester, find.byKey(reelKey)),
      sourceOrder,
    );
  });

  testWidgets('rich text keeps WidgetSpan RTL placeholder position', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_widget_span_rtl_placeholder');
    const widgetKey = ValueKey('reel_rich_widget_span_rtl_placeholder_child');
    const direction = TextDirection.rtl;
    const style = TextStyle(fontSize: 34, fontWeight: FontWeight.w700);
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    TextSpan spanFor(String text) {
      return TextSpan(
        children: [
          TextSpan(text: text),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 18, height: 18),
          ),
        ],
      );
    }

    Widget frame(String text) {
      return Directionality(
        textDirection: direction,
        child: Center(
          child: ReelText.rich(
            spanFor(text),
            key: reelKey,
            style: style,
            options: options,
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('אבגד'));
    final sourceLeft = tester.getRect(find.byKey(widgetKey)).left;

    await tester.pumpWidget(frame('אבג'));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(widgetKey)).left,
      closeTo(sourceLeft, 0.01),
    );
  });

  testWidgets('rich text rolls text when WidgetSpan is removed', (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_removed_widget_span_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );
    const fromSpan = TextSpan(
      children: [
        TextSpan(text: 'Sync '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 18, height: 18),
        ),
        TextSpan(text: ' done'),
      ],
    );
    const toSpan = TextSpan(text: 'Done');

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(fromSpan, options: options),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionArea(
            child: ReelText.rich(toSpan, options: options),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    expect(find.byKey(widgetKey), findsNothing);
  });

  testWidgets('text replacement removes the old WidgetSpan on the roll frame', (
    tester,
  ) async {
    const widgetKey = ValueKey('reel_rich_replaced_widget_span_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 140),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );
    const fromSpan = TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 18, height: 18),
        ),
      ],
    );
    const toSpan = TextSpan(text: 'A');

    Widget frame(InlineSpan span) {
      return MaterialApp(
        home: Center(
          child: ReelText.rich(span, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame(fromSpan));
    expect(find.byKey(widgetKey), findsOneWidget);

    await tester.pumpWidget(frame(toSpan));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(find.byKey(widgetKey), findsNothing);
  });

  testWidgets('rolling width includes WidgetSpan in the first layout pass', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_late_widget_size');
    const widgetKey = ValueKey('reel_rich_late_widget_size_child');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 180),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

    const fromSpan = TextSpan(text: 'ETA ');
    const toSpan = TextSpan(
      children: [
        TextSpan(text: 'ETA '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: widgetKey, width: 84, height: 18),
        ),
      ],
    );

    Widget frame(InlineSpan span) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(
              span,
              key: reelKey,
              options: options,
              style: style,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(fromSpan));
    await tester.pumpWidget(frame(toSpan));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    final rollingWidth = tester.getSize(find.byKey(reelKey)).width;

    await tester.pumpAndSettle();
    final settledWidth = tester.getSize(find.byKey(reelKey)).width;

    expect(rollingWidth, closeTo(settledWidth, 1.0));
  });

  testWidgets('rich text remeasures changed WidgetSpan at same token index', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_remeasure_widget');
    const narrowKey = ValueKey('reel_rich_remeasure_narrow_child');
    const wideKey = ValueKey('reel_rich_remeasure_wide_child');
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

    TextSpan spanFor(Key key, double width) {
      return TextSpan(
        children: [
          const TextSpan(text: 'ETA '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: key, width: width, height: 18),
          ),
        ],
      );
    }

    Widget frame(InlineSpan span) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(span, key: reelKey, style: style),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(spanFor(narrowKey, 20)));
    expect(tester.getSize(find.byKey(narrowKey)).width, 20);

    await tester.pumpWidget(frame(spanFor(wideKey, 84)));

    expect(find.byKey(narrowKey), findsNothing);
    expect(tester.getSize(find.byKey(wideKey)).width, 84);
  });

  testWidgets('rich text remeasures growing child inside same WidgetSpan', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_growing_widget');
    const widgetKey = ValueKey('reel_rich_growing_widget_child');
    final width = ValueNotifier<double>(20);
    final span = TextSpan(
      children: [
        const TextSpan(text: 'ETA '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) {
              return SizedBox(key: widgetKey, width: value, height: 18);
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(
              span,
              key: reelKey,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(widgetKey)).width, 20);

    width.value = 84;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(widgetKey)).width, 84);
  });

  testWidgets('rich text refreshes size for recreated equivalent WidgetSpan', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_rich_recreated_widget');
    const widgetKey = ValueKey('reel_rich_recreated_widget_child');

    TextSpan spanFor() {
      return const TextSpan(
        children: [
          TextSpan(text: 'ETA '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: widgetKey, width: 48, height: 18),
          ),
          TextSpan(text: ' ok'),
        ],
      );
    }

    Widget frame() {
      return MaterialApp(
        home: SelectionArea(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: ReelText.rich(
                spanFor(),
                key: reelKey,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }

    double selectionRight() {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('reel_text_selection_surface')),
      );
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: spanFor().toPlainText(includePlaceholders: true).length,
        ),
      );
      return boxes.map((box) => box.right).reduce(math.max);
    }

    await tester.pumpWidget(frame());
    final initialSelectionRight = selectionRight();

    await tester.pumpWidget(frame());
    expect(selectionRight(), closeTo(initialSelectionRight, 1.0));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(widgetKey)).width, 48);
    expect(selectionRight(), closeTo(initialSelectionRight, 1.0));
    expect(selectionRight(),
        closeTo(tester.getSize(find.byKey(reelKey)).width, 1.0));
  });

  testWidgets('rich text records WidgetSpan shrink to zero', (tester) async {
    const reelKey = ValueKey('reel_rich_zero_widget');
    const widgetKey = ValueKey('reel_rich_zero_widget_child');
    final width = ValueNotifier<double>(48);
    final span = TextSpan(
      children: [
        const TextSpan(text: 'ETA '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) {
              if (value == 0) {
                return const SizedBox.shrink(key: widgetKey);
              }
              return SizedBox(key: widgetKey, width: value, height: 18);
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText.rich(
              span,
              key: reelKey,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    final expandedWidth = tester.getSize(find.byKey(reelKey)).width;

    width.value = 0;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(widgetKey)).width, 0);
    expect(tester.getSize(find.byKey(reelKey)).width,
        lessThan(expandedWidth - 40));
  });

  testWidgets('rich text honors WidgetSpan child baseline', (tester) async {
    const richTextKey = ValueKey('reel_rich_baseline_reference');
    const reelKey = ValueKey('reel_rich_baseline_reel');
    const richChildKey = ValueKey('reel_rich_baseline_reference_child');
    const reelChildKey = ValueKey('reel_rich_baseline_reel_child');
    const lineStyle = TextStyle(fontSize: 38, fontWeight: FontWeight.w700);
    const childStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);

    TextSpan spanFor(Key childKey) {
      return TextSpan(
        style: lineStyle,
        children: [
          const TextSpan(text: 'A'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text('xy', key: childKey, style: childStyle),
          ),
          const TextSpan(text: 'B'),
        ],
      );
    }

    TextBox placeholderBox(Finder paragraphFinder) {
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(boxes, hasLength(1));
      return boxes.single;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(key: richTextKey, text: spanFor(richChildKey)),
                const SizedBox(height: 24),
                SelectionArea(
                  child: ReelText.rich(spanFor(reelChildKey), key: reelKey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final richChildTop = tester.getRect(find.byKey(richChildKey)).top -
        tester.getRect(find.byKey(richTextKey)).top;
    final reelChildTop = tester.getRect(find.byKey(reelChildKey)).top -
        tester.getRect(find.byKey(reelKey)).top;
    final richBox = placeholderBox(find.byKey(richTextKey));
    final reelBox = placeholderBox(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );

    expect(tester.takeException(), isNull);
    expect(reelChildTop, closeTo(richChildTop, 1.0));
    expect(reelBox.top, closeTo(richBox.top, 1.0));
    expect(reelBox.bottom, closeTo(richBox.bottom, 1.0));
  });

  testWidgets('rich text recomputes WidgetSpan metrics when metadata changes', (
    tester,
  ) async {
    const richTextKey = ValueKey('reel_rich_metadata_reference');
    const reelKey = ValueKey('reel_rich_metadata_reel');
    const richChildKey = ValueKey('reel_rich_metadata_reference_child');
    const reelChildKey = ValueKey('reel_rich_metadata_reel_child');
    const lineStyle = TextStyle(fontSize: 38, fontWeight: FontWeight.w700);
    const childStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);

    TextSpan spanFor(Key childKey, PlaceholderAlignment alignment) {
      return TextSpan(
        style: lineStyle,
        children: [
          const TextSpan(text: 'A'),
          WidgetSpan(
            alignment: alignment,
            baseline: alignment == PlaceholderAlignment.baseline
                ? TextBaseline.alphabetic
                : null,
            child: Text('xy', key: childKey, style: childStyle),
          ),
          const TextSpan(text: 'B'),
        ],
      );
    }

    TextBox placeholderBox(Finder paragraphFinder) {
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(boxes, hasLength(1));
      return boxes.single;
    }

    Widget frame(PlaceholderAlignment alignment) {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  key: richTextKey,
                  text: spanFor(richChildKey, alignment),
                ),
                const SizedBox(height: 24),
                SelectionArea(
                  child: ReelText.rich(
                    spanFor(reelChildKey, alignment),
                    key: reelKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(PlaceholderAlignment.middle));
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(frame(PlaceholderAlignment.baseline));
    await tester.pump();
    await tester.pump();

    final richBox = placeholderBox(find.byKey(richTextKey));
    final reelBox = placeholderBox(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );

    expect(tester.takeException(), isNull);
    expect(reelBox.top, closeTo(richBox.top, 1.0));
    expect(reelBox.bottom, closeTo(richBox.bottom, 1.0));
  });

  testWidgets('rich text honors non-baseline WidgetSpan alignment', (
    tester,
  ) async {
    const lineStyle = TextStyle(fontSize: 38, fontWeight: FontWeight.w700);

    TextSpan spanFor(Key childKey, PlaceholderAlignment alignment) {
      final baseline = switch (alignment) {
        PlaceholderAlignment.aboveBaseline ||
        PlaceholderAlignment.belowBaseline ||
        PlaceholderAlignment.baseline =>
          TextBaseline.alphabetic,
        PlaceholderAlignment.top ||
        PlaceholderAlignment.middle ||
        PlaceholderAlignment.bottom =>
          null,
      };
      return TextSpan(
        style: lineStyle,
        children: [
          const TextSpan(text: 'A'),
          WidgetSpan(
            alignment: alignment,
            baseline: baseline,
            child: SizedBox(key: childKey, width: 18, height: 12),
          ),
          const TextSpan(text: 'B'),
        ],
      );
    }

    TextBox placeholderBox(Finder paragraphFinder) {
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(boxes, hasLength(1));
      return boxes.single;
    }

    for (final alignment in [
      PlaceholderAlignment.top,
      PlaceholderAlignment.bottom,
      PlaceholderAlignment.aboveBaseline,
      PlaceholderAlignment.belowBaseline,
    ]) {
      final richTextKey = ValueKey('reel_rich_${alignment.name}_reference');
      final reelKey = ValueKey('reel_rich_${alignment.name}_reel');
      final richChildKey =
          ValueKey('reel_rich_${alignment.name}_reference_child');
      final reelChildKey = ValueKey('reel_rich_${alignment.name}_reel_child');

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    key: richTextKey,
                    text: spanFor(richChildKey, alignment),
                  ),
                  const SizedBox(height: 24),
                  SelectionArea(
                    child: ReelText.rich(
                      spanFor(reelChildKey, alignment),
                      key: reelKey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final richChildTop = tester.getRect(find.byKey(richChildKey)).top -
          tester.getRect(find.byKey(richTextKey)).top;
      final reelChildTop = tester.getRect(find.byKey(reelChildKey)).top -
          tester.getRect(find.byKey(reelKey)).top;
      final richBox = placeholderBox(find.byKey(richTextKey));
      final reelBox = placeholderBox(
        find.byKey(const ValueKey('reel_text_selection_surface')),
      );

      expect(tester.takeException(), isNull);
      expect(reelChildTop, closeTo(richChildTop, 1.0));
      expect(reelBox.top, closeTo(richBox.top, 1.0));
      expect(reelBox.bottom, closeTo(richBox.bottom, 1.0));
    }
  });

  testWidgets('rich text scales WidgetSpan children with text scaler', (
    tester,
  ) async {
    const richTextKey = ValueKey('reel_rich_scaled_widget_reference');
    const reelKey = ValueKey('reel_rich_scaled_widget_reel');
    const richChildKey = ValueKey('reel_rich_scaled_widget_reference_child');
    const reelChildKey = ValueKey('reel_rich_scaled_widget_reel_child');
    const lineStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
    const textScaler = TextScaler.linear(2);

    TextSpan spanFor(Key childKey) {
      return TextSpan(
        style: lineStyle,
        children: [
          const TextSpan(text: 'A'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: childKey, width: 18, height: 12),
          ),
          const TextSpan(text: 'B'),
        ],
      );
    }

    TextBox placeholderBox(Finder paragraphFinder) {
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(boxes, hasLength(1));
      return boxes.single;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: textScaler),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    key: richTextKey,
                    text: spanFor(richChildKey),
                    textScaler: textScaler,
                  ),
                  const SizedBox(height: 24),
                  SelectionArea(
                    child: ReelText.rich(spanFor(reelChildKey), key: reelKey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final richBox = placeholderBox(find.byKey(richTextKey));
    final reelBox = placeholderBox(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );

    expect(tester.takeException(), isNull);
    expect((richBox.right - richBox.left).abs(), closeTo(36, 1.0));
    expect((richBox.bottom - richBox.top).abs(), closeTo(24, 1.0));
    expect(
      (reelBox.right - reelBox.left).abs(),
      closeTo((richBox.right - richBox.left).abs(), 1.0),
    );
    expect(
      (reelBox.bottom - reelBox.top).abs(),
      closeTo((richBox.bottom - richBox.top).abs(), 1.0),
    );
  });

  testWidgets('rich text selection includes WidgetSpan width', (tester) async {
    const span = TextSpan(
      children: [
        TextSpan(text: 'Reviewed '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: 40, height: 18),
        ),
        TextSpan(text: ' done'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectionArea(
          child: Center(
            child: ReelText.rich(
              span,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reel_text_selection_surface')),
    );
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: span.toPlainText(includePlaceholders: true).length,
      ),
    );
    final selectionRight = boxes.map((box) => box.right).reduce(math.max);
    final visualWidth = tester.getSize(find.byType(ReelText)).width;

    expect(selectionRight, closeTo(visualWidth, 1.0));
  });

  testWidgets('rich text uses TextSpan semantics labels', (tester) async {
    const visibleText = 'ETA';
    const semanticsText = 'estimated arrival';
    const span = TextSpan(text: visibleText, semanticsLabel: semanticsText);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.rich(span),
      ),
    );

    expect(find.bySemanticsLabel(semanticsText), findsOneWidget);
    expect(find.bySemanticsLabel(visibleText), findsNothing);
  });

  testWidgets('rich text preserves WidgetSpan child semantics', (
    tester,
  ) async {
    final span = TextSpan(
      children: [
        const TextSpan(text: 'ETA '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            label: 'priority badge',
            child: const SizedBox(width: 12, height: 12),
          ),
        ),
        const TextSpan(text: ' ready'),
      ],
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.rich(span),
      ),
    );

    expect(find.bySemanticsLabel(RegExp(r'\bETA\s+ready\b')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'\bpriority badge\b')),
      findsOneWidget,
    );
  });

  testWidgets('explicit semanticsLabel overrides rich text semantics', (
    tester,
  ) async {
    final span = TextSpan(
      children: [
        const TextSpan(text: 'ETA', semanticsLabel: 'estimated arrival'),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            label: 'priority badge',
            child: const SizedBox(width: 12, height: 12),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.rich(span, semanticsLabel: 'delivery estimate'),
      ),
    );

    expect(find.bySemanticsLabel('delivery estimate'), findsOneWidget);
    expect(find.bySemanticsLabel('estimated arrival'), findsNothing);
    expect(find.bySemanticsLabel('priority badge'), findsNothing);
  });

  testWidgets('editing controller renders replacements inside EditableText', (
    tester,
  ) async {
    final controller = ReelTextEditingController(
      text: 'Please recieve teh adress.',
    );
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 18),
            cursorColor: Colors.green,
            backgroundCursorColor: Colors.black,
          ),
        ),
      ),
    );

    controller.beginReplacements([
      const ReelTextEditReplacement(
        range: TextRange(start: 7, end: 14),
        replacement: 'receive',
        key: ValueKey('inline_recieve'),
        options: ReelTextOptions(
          duration: Duration(milliseconds: 240),
          stagger: Duration(milliseconds: 16),
        ),
      ),
      const ReelTextEditReplacement(
        range: TextRange(start: 15, end: 18),
        replacement: 'the',
        key: ValueKey('inline_teh'),
        options: ReelTextOptions(
          duration: Duration(milliseconds: 240),
          stagger: Duration(milliseconds: 16),
        ),
      ),
    ]);
    await tester.pump();

    final inlineCorrection = find.descendant(
      of: find.byType(EditableText),
      matching: find.byKey(const ValueKey('inline_recieve')),
    );
    expect(inlineCorrection, findsOneWidget);
    expect(controller.text, 'Please recieve teh adress.');

    controller.animateReplacements();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final animatedCorrection = tester.widget<ReelText>(inlineCorrection);
    expect(animatedCorrection.controller!.value, 'receive');
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsWidgets);
    expect(controller.replacementText(), 'Please receive the adress.');
  });

  testWidgets('editing controller animates replacements and auto commits', (
    tester,
  ) async {
    final controller = ReelTextEditingController(text: 'Fix teh typo.');
    addTearDown(controller.dispose);

    controller.animateReplacements(
      replacements: [
        const ReelTextEditReplacement(
          range: TextRange(start: 4, end: 7),
          replacement: 'the',
          options: ReelTextOptions(
            duration: Duration(milliseconds: 20),
            stagger: Duration.zero,
          ),
        ),
      ],
      commitAfter: const Duration(milliseconds: 40),
    );

    expect(controller.hasActiveReplacements, isTrue);
    expect(controller.replacementText(), 'Fix the typo.');

    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.text, 'Fix the typo.');
    expect(controller.hasActiveReplacements, isFalse);
  });

  testWidgets(
    'editing controller rolls newly provided replacements after mounting',
    (tester) async {
      final controller = ReelTextEditingController(text: 'Fix teh typo.');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 18),
            cursorColor: Colors.green,
            backgroundCursorColor: Colors.black,
          ),
        ),
      );

      controller.animateReplacements(
        replacements: [
          const ReelTextEditReplacement(
            range: TextRange(start: 4, end: 7),
            replacement: 'the',
            key: ValueKey('inline_teh_delayed'),
            options: ReelTextOptions(
              duration: Duration(milliseconds: 160),
              stagger: Duration.zero,
            ),
          ),
        ],
      );

      await tester.pump();
      final inlineCorrection = find.descendant(
        of: find.byType(EditableText),
        matching: find.byKey(const ValueKey('inline_teh_delayed')),
      );
      expect(inlineCorrection, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 16));

      expect(
        find.descendant(
          of: inlineCorrection,
          matching: find.byKey(const ValueKey('reel_text_rolling')),
        ),
        findsOneWidget,
      );
      expect(controller.text, 'Fix teh typo.');
      expect(controller.replacementText(), 'Fix the typo.');
    },
  );

  testWidgets(
      'editing controller preserves EditableText strut for replacements', (
    tester,
  ) async {
    const inlineKey = ValueKey('inline_strut_replacement');
    const strut = StrutStyle(fontSize: 13, height: 1, forceStrutHeight: true);
    final controller = ReelTextEditingController(text: 'Invite copied');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EditableText(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13, height: 1),
          strutStyle: strut,
          cursorColor: Colors.green,
          backgroundCursorColor: Colors.black,
        ),
      ),
    );

    controller.beginReplacements([
      const ReelTextEditReplacement(
        range: TextRange(start: 0, end: 13),
        replacement: 'Export ready',
        key: inlineKey,
      ),
    ]);
    await tester.pump();

    final inlineReplacement = tester.widget<ReelText>(find.byKey(inlineKey));
    expect(inlineReplacement.strutStyle?.fontSize, strut.fontSize);
    expect(inlineReplacement.strutStyle?.height, strut.height);
    expect(inlineReplacement.strutStyle?.forceStrutHeight, isTrue);
  });

  testWidgets('editing controller spanBuilder customizes resting text', (
    tester,
  ) async {
    final controller = ReelTextEditingController(
      text: 'warn',
      spanBuilder: (context, text, style, withComposing) {
        return TextSpan(
          style: style,
          children: [
            TextSpan(
              text: text,
              style: style.copyWith(decoration: TextDecoration.underline),
            ),
          ],
        );
      },
    );
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EditableText(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 18),
          cursorColor: Colors.green,
          backgroundCursorColor: Colors.black,
        ),
      ),
    );

    final editableFinder = find.byType(EditableText);
    final editable = tester.widget<EditableText>(editableFinder);
    final span = editable.controller.buildTextSpan(
      context: tester.element(editableFinder),
      style: editable.style,
      withComposing: false,
    );
    final child = span.children!.single as TextSpan;

    expect(child.text, 'warn');
    expect(child.style?.decoration, TextDecoration.underline);
  });

  testWidgets('textAlign end aligns settled glyphs inside bounded width', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_alignment_box');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: boxKey,
            width: 240,
            child: ReelText(
              'Go',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byKey(boxKey));
    final glyphRow = tester.getRect(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    );
    final lastGlyphRight = _rightOfGlyph(
      _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
      'o',
    );

    expect(glyphRow.right, closeTo(box.right, 0.01));
    expect(lastGlyphRight, greaterThanOrEqualTo(box.right));
  });

  testWidgets('textAlign start and end respect RTL direction', (tester) async {
    const boxKey = ValueKey('reel_text_rtl_alignment_box');
    const style = TextStyle(fontSize: 32);

    Future<void> pump(TextAlign align) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              key: boxKey,
              width: 240,
              child: ReelText('تم', textAlign: align, style: style),
            ),
          ),
        ),
      );
    }

    await pump(TextAlign.start);
    var box = tester.getRect(find.byKey(boxKey));
    var glyphRow = tester.getRect(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    );
    expect(glyphRow.right, closeTo(box.right, 0.01));

    await pump(TextAlign.end);
    box = tester.getRect(find.byKey(boxKey));
    glyphRow = tester.getRect(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    );
    expect(glyphRow.left, closeTo(box.left, 0.01));
  });

  testWidgets(
    'textAlign start keeps RTL stable glyph anchored during shrinking roll',
    (tester) async {
      const options = ReelTextOptions(
        duration: Duration(milliseconds: 120),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      );

      Widget wrap(String text) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 240,
              child: ReelText(
                text,
                textAlign: TextAlign.start,
                options: options,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(wrap('אבגד'));
      await tester.pumpWidget(wrap('אבג'));
      await tester.pump(const Duration(milliseconds: 60));

      final duringRight = _rightOfGlyph(
        _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
        'א',
      );

      await tester.pumpAndSettle();

      final settledRight = _rightOfGlyph(
        _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
        'א',
      );
      expect(duringRight, closeTo(settledRight, 0.01));
    },
  );

  testWidgets('inherits DefaultTextStyle textAlign for public layout', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_inherited_alignment_box');

    await tester.pumpWidget(
      const DefaultTextStyle(
        style: TextStyle(fontSize: 32),
        textAlign: TextAlign.end,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(key: boxKey, width: 240, child: ReelText('Go')),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byKey(boxKey));
    final glyphRow = tester.getRect(
      find.byKey(const ValueKey('reel_text_settled_glyphs')),
    );

    expect(glyphRow.right, closeTo(box.right, 0.01));
  });

  testWidgets('textAlign end keeps Text-like size under loose constraints', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_loose_alignment_box');
    const reelKey = ValueKey('reel_text_loose_alignment_reel');
    const constraints = BoxConstraints(maxWidth: 240);
    const style = TextStyle(fontSize: 32);
    final painter = TextPainter(
      text: const TextSpan(text: 'Go', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: boxKey,
            width: 240,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: constraints,
                child: const ReelText(
                  'Go',
                  key: reelKey,
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byKey(boxKey));
    final reel = tester.getRect(find.byKey(reelKey));
    final lastGlyphRight = _rightOfGlyph(
      _visibleReelGlyphPositionsLeftToRight(tester, find.byKey(reelKey)),
      'o',
    );

    expect(reel.width, closeTo(painter.size.width, 0.01));
    expect(lastGlyphRight, lessThan(box.right));
  });

  testWidgets(
    'textAlign end keeps stable glyphs anchored during shrinking roll',
    (tester) async {
      const boxKey = ValueKey('reel_text_alignment_box');
      const options = ReelTextOptions(
        duration: Duration(milliseconds: 120),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      );

      Widget wrap(String text) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              key: boxKey,
              width: 240,
              child: ReelText(
                text,
                textAlign: TextAlign.end,
                options: options,
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(wrap('Saved'));
      await tester.pumpWidget(wrap('Save'));
      await tester.pump(const Duration(milliseconds: 60));

      final duringLeft = _leftOfGlyph(
        _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
        'S',
      );

      await tester.pumpAndSettle();

      final settledLeft = _leftOfGlyph(
        _visibleReelGlyphPositionsLeftToRight(tester, find.byType(ReelText)),
        'S',
      );
      expect(duringLeft, closeTo(settledLeft, 0.01));
    },
  );

  testWidgets('textAlign center aligns rolling glyphs inside bounded width', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_alignment_box');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 80),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );

    Widget wrap(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: boxKey,
            width: 240,
            child: ReelText(
              text,
              textAlign: TextAlign.center,
              options: options,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(wrap('Go'));
    await tester.pumpWidget(wrap('Gone'));
    await tester.pump(const Duration(milliseconds: 40));

    final box = tester.getRect(find.byKey(boxKey));
    final rolling = tester.getRect(
      find.byKey(const ValueKey('reel_text_rolling')),
    );

    expect(rolling.center.dx, closeTo(box.center.dx, 0.01));
  });

  testWidgets('active roll remeasures when inherited text style changes', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_active_style_change');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 800),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
    );

    Widget frame(String text, double fontSize) {
      return DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Ahem',
          fontSize: fontSize,
          height: 1,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText(text, key: reelKey, options: options),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('AA', 20));
    await tester.pumpWidget(frame('WW', 20));
    await tester.pump(const Duration(milliseconds: 80));
    final state = tester.state(find.byKey(reelKey));
    final smallHeight = tester.getSize(find.byKey(reelKey)).height;
    final initialMeasurements =
        (state as dynamic).debugFrameMeasureCount as int;

    await tester.pumpWidget(frame('WW', 48));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    expect(
        tester.getSize(find.byKey(reelKey)).height, greaterThan(smallHeight));
    expect(
      (state as dynamic).debugFrameMeasureCount as int,
      greaterThan(initialMeasurements),
    );
  });

  testWidgets('active roll refreshes every layout measurement input', (
    tester,
  ) async {
    const reelKey = ValueKey('reel_active_layout_change');
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 1200),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
    );

    Widget frame(
      String text, {
      TextDirection direction = TextDirection.ltr,
      Locale locale = const Locale('en'),
      StrutStyle? strutStyle,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: direction,
            child: Center(
              child: ReelText(
                text,
                key: reelKey,
                options: options,
                strutStyle: strutStyle,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame('AA'));
    await tester.pumpWidget(frame('WW'));
    await tester.pump(const Duration(milliseconds: 40));
    final state = tester.state(find.byKey(reelKey));
    var measurements = (state as dynamic).debugFrameMeasureCount as int;

    Future<void> expectRemeasured(Widget nextFrame) async {
      await tester.pumpWidget(nextFrame);
      final nextMeasurements = (state as dynamic).debugFrameMeasureCount as int;
      expect(nextMeasurements, greaterThan(measurements));
      measurements = nextMeasurements;
      expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    }

    await expectRemeasured(frame('WW', direction: TextDirection.rtl));
    await expectRemeasured(
      frame('WW', direction: TextDirection.rtl, locale: const Locale('ja')),
    );
    await expectRemeasured(
      frame(
        'WW',
        direction: TextDirection.rtl,
        locale: const Locale('ja'),
        strutStyle: const StrutStyle(fontSize: 30, height: 1.4),
      ),
    );
    await expectRemeasured(
      frame(
        'WW',
        direction: TextDirection.rtl,
        locale: const Locale('ja'),
        strutStyle: const StrutStyle(fontSize: 30, height: 1.4),
        textScaler: const TextScaler.linear(1.5),
      ),
    );
  });

  testWidgets('declarative text changes roll then settle', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText('Copy'),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText(
          'Copied',
          options: ReelTextOptions(
            duration: Duration(milliseconds: 80),
            stagger: Duration(milliseconds: 5),
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });

  testWidgets('wide glyph changes keep faces unconstrained during roll', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      skipUnchanged: false,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(
            'WWW',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(
            'iii',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(
            'WAVY',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('WAVY'), findsOneWidget);
  });

  testWidgets('rolling slot clip keeps vertical bleed for glyph overhang', (
    tester,
  ) async {
    const reelKey = ValueKey('bleed_reel');
    const style = TextStyle(
      color: Colors.black,
      fontSize: 72,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 0.92,
    );
    const options = ReelTextOptions(
      direction: ReelTextDirection.up,
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      curve: Curves.linear,
      bounce: 0,
      skipUnchanged: false,
    );

    Widget frame(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(text, key: reelKey, style: style, options: options),
        ),
      );
    }

    await tester.pumpWidget(frame('ffff'));
    final settledSize = tester.getSize(find.byKey(reelKey));

    await tester.pumpWidget(frame('gggg'));
    await tester.pump(const Duration(milliseconds: 105));

    expect(tester.getSize(find.byKey(reelKey)), settledSize);
    final rollingSurface = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );
    final rect = (rollingSurface as dynamic).debugVerticalClipRect as Rect;

    expect(rect.top, lessThan(0));
    expect(rect.bottom, greaterThan(settledSize.height));

    expect(
      rollingSurface,
      paints
        ..something((methodName, arguments) {
          if (methodName != #saveLayer) {
            return false;
          }
          final bounds = arguments.first as Rect?;
          // Layer bounds are expressed in the enclosing layer's coordinates,
          // so the bleed shows up as extra height beyond the row.
          return bounds != null &&
              bounds.height > rollingSurface.size.height;
        }),
    );
  });

  testWidgets(
    'inserted glyph starts outside the expanded clip on first frame',
    (tester) async {
      const reelKey = ValueKey('first_frame_reel');
      const style = TextStyle(fontSize: 60, fontWeight: FontWeight.w900);
      const options = ReelTextOptions(
        direction: ReelTextDirection.up,
        duration: Duration(milliseconds: 120),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      );

      Widget frame(String text) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ReelText(text, key: reelKey, style: style, options: options),
          ),
        );
      }

      await tester.pumpWidget(frame(''));
      await tester.pumpWidget(frame('f'));

      final rollingSlotRender = tester.renderObject(
        find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      ) as dynamic;
      final clipRect = rollingSlotRender.debugVerticalClipRect as Rect;

      expect(rollingSlotRender.debugIncomingY, greaterThan(clipRect.bottom));
    },
  );

  testWidgets('descenders do not break the outgoing glyph handoff', (
    tester,
  ) async {
    const options = ReelTextOptions(
      direction: ReelTextDirection.up,
      duration: Duration(milliseconds: 160),
      stagger: Duration.zero,
      exitOffset: Duration(milliseconds: 20),
      skipUnchanged: false,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(
            'gyp',
            options: options,
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText(
            'ACE',
            options: options,
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('ACE'), findsOneWidget);
  });

  testWidgets('slot height stays stable before and during a roll', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 160),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );
    const textStyle = TextStyle(fontSize: 64, fontWeight: FontWeight.w900);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText('Copy', options: options, style: textStyle),
        ),
      ),
    );
    final settledHeight = tester.getSize(find.byType(ReelText)).height;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText('Copied', options: options, style: textStyle),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    final rollingHeight = tester.getSize(find.byType(ReelText)).height;

    await tester.pumpAndSettle();
    final finalHeight = tester.getSize(find.byType(ReelText)).height;

    expect(rollingHeight, closeTo(settledHeight, 0.01));
    expect(finalHeight, closeTo(settledHeight, 0.01));
  });

  testWidgets('settled width matches final per-glyph animation width', (
    tester,
  ) async {
    const options = ReelTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      skipUnchanged: false,
      bounce: 0,
    );
    const textStyle = TextStyle(
      fontSize: 40,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w900,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText('fit lit', options: options, style: textStyle),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText('WAVY WWW', options: options, style: textStyle),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 180));
    final lastRollingWidth = tester.getSize(find.byType(ReelText)).width;

    await tester.pumpAndSettle();
    final settledWidth = tester.getSize(find.byType(ReelText)).width;

    expect(settledWidth, closeTo(lastRollingWidth, 0.01));
  });

  testWidgets('supports empty text and rolls back from empty targets', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: '');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ReelText.controller(
            controller: controller,
            options: const ReelTextOptions(
              duration: Duration(milliseconds: 20),
              stagger: Duration.zero,
              exitOffset: Duration.zero,
            ),
          ),
        ),
      ),
    );

    expect(controller.value, '');
    expect(tester.getSize(find.byType(ReelText)).width, 0);
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);

    controller.set('Ready');
    await tester.pumpAndSettle();

    expect(controller.value, 'Ready');
    expect(tester.getSize(find.byType(ReelText)).width, greaterThan(0));
    expect(find.bySemanticsLabel('Ready'), findsOneWidget);

    controller.set('');
    await tester.pumpAndSettle();

    expect(controller.value, '');
    expect(tester.getSize(find.byType(ReelText)).width, 0);
    expect(find.text('Ready'), findsNothing);
  });

  testWidgets('rapid controller set calls land on the latest value', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: 'one');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.controller(
          controller: controller,
          options: const ReelTextOptions(
            duration: Duration(milliseconds: 40),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    controller.set('two');
    controller.set('three');
    controller.set('four');

    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.value, 'four');
    expect(find.bySemanticsLabel('four'), findsOneWidget);
    expect(find.bySemanticsLabel('one'), findsNothing);
    expect(find.bySemanticsLabel('two'), findsNothing);
    expect(find.bySemanticsLabel('three'), findsNothing);
  });

  testWidgets('switching controllers discards the previous pending target', (
    tester,
  ) async {
    final first = ReelTextController(initialText: 'first');
    final second = ReelTextController(initialText: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var active = first;
    late StateSetter rebuild;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ReelText.controller(controller: active);
          },
        ),
      ),
    );

    const queuedOptions = ReelTextOptions(
      duration: Duration(milliseconds: 80),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      interrupt: false,
    );
    first.set('first-active', options: queuedOptions);
    first.set('first-stale', options: queuedOptions);

    rebuild(() => active = second);
    await tester.pump();
    second.set(
      'second-final',
      options: const ReelTextOptions(
        duration: Duration(milliseconds: 20),
        stagger: Duration.zero,
        exitOffset: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('second-final'), findsOneWidget);
    expect(find.bySemanticsLabel('first-stale'), findsNothing);
  });

  testWidgets('controller set cancels a pending flash revert', (tester) async {
    final controller = ReelTextController(initialText: 'Copy');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.controller(
          controller: controller,
          options: const ReelTextOptions(
            duration: Duration(milliseconds: 40),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    controller.flash(
      'Copied',
      options: const ReelTextFlashOptions(
        revertAfter: Duration(milliseconds: 200),
        enter: ReelTextOptions(duration: Duration(milliseconds: 40)),
        exit: ReelTextOptions(duration: Duration(milliseconds: 40)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    controller.set('Saved');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(controller.value, 'Saved');
    expect(find.bySemanticsLabel('Saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Copy'), findsNothing);
  });

  testWidgets('flash reverts to the original resting text after last flash', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: 'Copy');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.controller(
          controller: controller,
          options: const ReelTextOptions(
            duration: Duration(milliseconds: 30),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    controller.flash(
      'Copied',
      options: const ReelTextFlashOptions(
        revertAfter: Duration(milliseconds: 100),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    controller.flash(
      'Copied again',
      options: const ReelTextFlashOptions(
        revertAfter: Duration(milliseconds: 100),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(controller.value, 'Copied again');

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(controller.value, 'Copy');
    expect(find.bySemanticsLabel('Copy'), findsOneWidget);
  });

  testWidgets('progress keeps rolling until completed', (tester) async {
    final controller = ReelTextController(initialText: 'Export');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.controller(
          controller: controller,
          options: const ReelTextOptions(
            duration: Duration(milliseconds: 20),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    final progress = controller.startProgress(
      'Exporter',
      frames: const ['Exported'],
      interval: const Duration(milliseconds: 70),
      options: const ReelTextOptions(duration: Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(progress.isActive, isTrue);
    expect(controller.value, 'Exporter');
    expect(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.value, 'Exported');

    progress.complete(
      'Exported',
      options: const ReelTextOptions(color: Color(0xff38bdf8)),
    );
    await tester.pumpAndSettle();

    expect(progress.isActive, isFalse);
    expect(controller.value, 'Exported');
    expect(find.bySemanticsLabel('Exported'), findsOneWidget);
  });

  testWidgets('set cancels an active progress loop', (tester) async {
    final controller = ReelTextController(initialText: 'Export');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ReelText.controller(
          controller: controller,
          options: const ReelTextOptions(
            duration: Duration(milliseconds: 20),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    final progress = controller.startProgress(
      'Exporter',
      interval: const Duration(milliseconds: 60),
      options: const ReelTextOptions(duration: Duration(milliseconds: 20)),
    );
    await tester.pump();

    controller.set('Idle');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(progress.isActive, isFalse);
    expect(controller.value, 'Idle');
    expect(find.bySemanticsLabel('Idle'), findsOneWidget);
  });

  test('runWhile emits waiting then success and returns the result', () async {
    final controller = ReelTextController(initialText: 'Export');
    addTearDown(controller.dispose);
    final completer = Completer<int>();

    final result = controller.runWhile(
      () => completer.future,
      waiting: 'Exporting',
      success: 'Exported',
      failure: 'Failed',
    );

    expect(controller.value, 'Exporting');

    completer.complete(42);
    expect(await result, 42);
    expect(controller.value, 'Exported');
  });

  test('runWhile emits failure and rethrows operation errors', () async {
    final controller = ReelTextController(initialText: 'Export');
    addTearDown(controller.dispose);
    final error = StateError('network');

    final result = controller.runWhile<int>(
      () async => throw error,
      waiting: 'Exporting',
      success: 'Exported',
      failure: 'Failed',
    );

    expect(controller.value, 'Exporting');
    await expectLater(result, throwsA(same(error)));
    expect(controller.value, 'Failed');
  });

  testWidgets('startWaiting ellipsis cycles trailing dots', (tester) async {
    final controller = ReelTextController(initialText: 'Load');
    addTearDown(controller.dispose);
    final seen = <String>[];
    controller.addListener(() => seen.add(controller.value));

    final handle = controller.startWaiting(
      'Load',
      waiting: const ReelWaiting.ellipsis(step: Duration(milliseconds: 100)),
    );

    await tester.pump(const Duration(milliseconds: 450));
    expect(seen, ['Load', 'Load.', 'Load..', 'Load...', 'Load']);
    expect(handle.isActive, isTrue);

    handle.complete('Done');
    expect(handle.isActive, isFalse);
    expect(controller.value, 'Done');

    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.value, 'Done');
  });

  testWidgets('startWaiting wave periodically re-rolls the same label', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: 'Sync');
    addTearDown(controller.dispose);
    var emits = 0;
    controller.addListener(() => emits++);

    final handle = controller.startWaiting(
      'Sync',
      waiting: const ReelWaiting.wave(rest: Duration(milliseconds: 200)),
      options: const ReelTextOptions(
        duration: Duration(milliseconds: 100),
        stagger: Duration(milliseconds: 10),
        exitOffset: Duration.zero,
        bounce: 0,
      ),
    );

    expect(emits, 1);
    expect(controller.value, 'Sync');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(emits, greaterThanOrEqualTo(3));
    expect(controller.value, 'Sync');

    handle.cancel();
    expect(handle.isActive, isFalse);
  });

  testWidgets('startWaiting builder generates one frame per tick', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: 'Go');
    addTearDown(controller.dispose);
    final seen = <String>[];
    controller.addListener(() => seen.add(controller.value));

    final handle = controller.startWaiting(
      'Go',
      waiting: ReelWaiting.builder(
        (text, tick) => '$text$tick',
        step: const Duration(milliseconds: 50),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(seen, ['Go0', 'Go1', 'Go2']);

    handle.cancel(text: 'Go');
    expect(controller.value, 'Go');

    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.value, 'Go');
  });

  testWidgets(
    'startWaiting scramble mutates suffix and holds readable frames',
    (tester) async {
      final controller = ReelTextController(initialText: 'Sync');
      addTearDown(controller.dispose);
      final seen = <String>[];
      controller.addListener(() => seen.add(controller.value));

      final handle = controller.startWaiting(
        'Sync',
        waiting: const ReelWaiting.scramble(
          alphabet: 'ab',
          changedGlyphs: 1,
          protectedPrefix: 3,
          holdEvery: 2,
          step: Duration(milliseconds: 50),
        ),
      );

      await tester.pump(const Duration(milliseconds: 120));

      expect(seen, hasLength(3));
      expect(seen[0], 'Sync');
      expect(seen[1], startsWith('Syn'));
      expect(seen[1], isNot('Sync'));
      expect(seen[2], 'Sync');

      handle.cancel();
    },
  );

  testWidgets('invalid custom waiting options preserve the active loop', (
    tester,
  ) async {
    final controller = ReelTextController(initialText: 'Sync');
    addTearDown(controller.dispose);
    final active = controller.startWaiting(
      'Sync',
      waiting: const ReelWaiting.ellipsis(
        step: Duration(milliseconds: 50),
      ),
    );
    const invalidOptions = ReelTextOptions(
      duration: Duration(microseconds: -1),
    );

    expect(
      () => controller.startWaiting(
        'Build',
        waiting: ReelWaiting.builder(
          (text, tick) => '$text$tick',
          step: const Duration(milliseconds: 50),
        ),
        options: invalidOptions,
      ),
      throwsArgumentError,
    );
    expect(active.isActive, isTrue);
    expect(controller.value, 'Sync');

    expect(
      () => controller.startWaiting(
        'Scramble',
        waiting: const ReelWaiting.scramble(
          step: Duration(milliseconds: 50),
        ),
        options: invalidOptions,
      ),
      throwsArgumentError,
    );
    expect(active.isActive, isTrue);
    expect(controller.value, 'Sync');

    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, 'Sync.');
    active.cancel();
  });

  testWidgets('snaps without rolling when animations are disabled', (
    tester,
  ) async {
    Widget wrap(String text) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ReelText(text),
        ),
      );
    }

    await tester.pumpWidget(wrap('Copy'));
    await tester.pumpWidget(wrap('Copied'));
    await tester.pump();

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsNothing);
    expect(find.byKey(const ValueKey('reel_text_settled')), findsOneWidget);
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });

  testWidgets('respectDisableAnimations can opt out of reduced motion', (
    tester,
  ) async {
    Widget wrap(String text) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ReelText(
            text,
            respectDisableAnimations: false,
            options: const ReelTextOptions(
              duration: Duration(milliseconds: 60),
              stagger: Duration.zero,
              exitOffset: Duration.zero,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(wrap('Copy'));
    await tester.pumpWidget(wrap('Copied'));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });

  group('unified surface keeps Text-compatible behavior', () {
    const reelKey = ValueKey('surface_reel');
    const boundaryKey = ValueKey('surface_boundary');

    Widget host(
      Widget child, {
      TextStyle style = const TextStyle(fontSize: 24, color: Colors.black),
      MediaQueryData media = const MediaQueryData(),
    }) {
      return MediaQuery(
        data: media,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: style,
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(color: Colors.white, child: child),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('settled and rolling glyphs are hit-testable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(host(GestureDetector(
        onTap: () => taps++,
        child: const ReelText('Tap me', key: reelKey),
      )));
      await tester.tap(find.byKey(reelKey));
      expect(taps, 1);

      final box = tester.renderObject<RenderBox>(find.byKey(reelKey));
      expect(
        box.hitTest(
          BoxHitTestResult(),
          position: box.size.center(Offset.zero),
        ),
        isTrue,
      );

      await tester.pumpWidget(host(GestureDetector(
        onTap: () => taps++,
        child: const ReelText('Tap ok', key: reelKey),
      )));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(reelKey));
      expect(taps, 2);
      await tester.pumpAndSettle();

      var enters = 0;
      await tester.pumpWidget(host(MouseRegion(
        onEnter: (_) => enters++,
        child: const ReelText('Hover me', key: reelKey),
      )));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(reelKey)));
      await tester.pump();
      expect(enters, 1);
    });

    testWidgets('baseline rows inside SelectionArea lay out cleanly', (
      tester,
    ) async {
      Widget frame({required bool intrinsic}) {
        const row = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Label', style: TextStyle(fontSize: 14)),
            ReelText('42', key: reelKey, style: TextStyle(fontSize: 30)),
          ],
        );
        return MaterialApp(
          home: SelectionArea(
            child: Center(
              child: intrinsic ? const IntrinsicHeight(child: row) : row,
            ),
          ),
        );
      }

      await tester.pumpWidget(frame(intrinsic: false));
      expect(tester.takeException(), isNull);
      final settledBaseline = _dryBaselineOf(
        tester.renderObject<RenderBox>(find.byKey(reelKey)),
      );
      expect(tester.takeException(), isNull);
      if (settledBaseline == null) {
        // Flutter before 3.24 has no dry-baseline API, and its Row cannot
        // compute intrinsics for baseline alignment at all, so the
        // IntrinsicHeight scenario below does not exist there.
        return;
      }

      await tester.pumpWidget(frame(intrinsic: true));
      expect(tester.takeException(), isNull);
      final label = tester.renderObject<RenderBox>(find.text('Label'));
      final reel = tester.renderObject<RenderBox>(find.byKey(reelKey));
      final labelBaseline = _dryBaselineOf(label)!;
      final reelBaseline = _dryBaselineOf(reel)!;
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(reelKey)).dy + reelBaseline,
        closeTo(tester.getTopLeft(find.text('Label')).dy + labelBaseline, 0.01),
      );
    });

    testWidgets('baseline WidgetSpan without a baseline survives intrinsics', (
      tester,
    ) async {
      const span = TextSpan(children: [
        TextSpan(text: 'A'),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: 20, height: 20),
        ),
        TextSpan(text: 'B'),
      ]);
      await tester.pumpWidget(host(const IntrinsicWidth(
        child: ReelText.rich(span, key: reelKey),
      )));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(reelKey)).width, 68);
    });

    testWidgets('foreground shaders span the row like Text', (tester) async {
      final style = TextStyle(
        fontSize: 24,
        foreground: Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(150, 0),
            const [Colors.red, Colors.blue],
          ),
      );
      await tester.pumpWidget(host(ReelText('GRADIENT', style: style)));
      final reel = await _rasterize(tester, boundaryKey);
      await tester.pumpWidget(host(Text('GRADIENT', style: style)));
      final text = await _rasterize(tester, boundaryKey);

      expect(_samePixels(reel, text), isTrue);
    });

    testWidgets('bold text accessibility setting matches Text', (
      tester,
    ) async {
      const media = MediaQueryData(boldText: true);
      await tester.pumpWidget(host(const ReelText('BOLD 42'), media: media));
      final bold = await _rasterize(tester, boundaryKey);
      await tester.pumpWidget(host(const Text('BOLD 42'), media: media));
      final text = await _rasterize(tester, boundaryKey);
      await tester.pumpWidget(host(const ReelText('BOLD 42')));
      final regular = await _rasterize(tester, boundaryKey);

      expect(_samePixels(bold, text), isTrue);
      expect(_samePixels(bold, regular), isFalse);
    });

    testWidgets('incoming faces without a colour use the ambient colour', (
      tester,
    ) async {
      const red = TextStyle(fontSize: 24, color: Colors.red);
      TextSpan span(String text) => TextSpan(
            text: text,
            style: const TextStyle(inherit: false, fontSize: 24),
          );
      await tester.pumpWidget(host(
        ReelText.rich(span('A'), key: reelKey),
        style: red,
      ));
      await tester.pumpWidget(host(
        ReelText.rich(span('B'), key: reelKey),
        style: red,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      final pixels = await _rasterize(tester, boundaryKey);
      await tester.pumpAndSettle();

      expect(_countPixels(pixels, _isReddish), greaterThan(0));
      expect(_countPixels(pixels, _isDark), 0);
    });

    testWidgets('rolling slot clips are hard-edged', (tester) async {
      await tester.pumpWidget(host(const ReelText('Ab', key: reelKey)));
      await tester.pumpWidget(host(const ReelText('Cd', key: reelKey)));
      await tester.pump(const Duration(milliseconds: 100));

      final surface = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('reel_text_rolling_text_slot')),
      );
      final canvas = TestRecordingCanvas();
      surface.paint(TestRecordingPaintingContext(canvas), Offset.zero);
      final clips = canvas.invocations
          .where((entry) => entry.invocation.memberName == #clipRect)
          .toList();
      await tester.pumpAndSettle();

      expect(clips, isNotEmpty);
      for (final clip in clips) {
        expect(clip.invocation.namedArguments[#doAntiAlias], isFalse);
      }
    });

    testWidgets('text change while reduced motion turns off still rolls', (
      tester,
    ) async {
      const reducedMotion = MediaQueryData(disableAnimations: true);
      await tester.pumpWidget(host(
        const ReelText('AA', key: reelKey),
        media: reducedMotion,
      ));
      await tester.pumpWidget(host(const ReelText('BB', key: reelKey)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('reel_text_rolling_text_slot')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reel_text_rolling_text_slot')),
        findsNothing,
      );
    });
  });
}

double? _dryBaselineFor(
  RenderBox box,
  BoxConstraints constraints,
  TextBaseline baseline,
) {
  try {
    return (box as dynamic).getDryBaseline(constraints, baseline) as double?;
  } on NoSuchMethodError {
    return null;
  }
}

List<String> _visibleReelGlyphsLeftToRight(WidgetTester tester, Finder scope) {
  final entries = _visibleReelGlyphPositionsLeftToRight(tester, scope);
  entries.sort(_compareGlyphPositions);
  return [for (final entry in entries) entry.text];
}

List<_GlyphPosition> _visibleReelGlyphPositionsLeftToRight(
  WidgetTester tester,
  Finder scope,
) {
  final entries = <_GlyphPosition>[];
  final scopeRect = tester.getRect(scope);
  final textFinder = find.descendant(of: scope, matching: find.byType(Text));

  for (final element in textFinder.evaluate()) {
    final widget = element.widget as Text;
    final text = widget.data;
    if (text == null || text.trim().isEmpty) {
      continue;
    }
    if (!_isEffectivelyOpaque(element)) {
      continue;
    }
    final rect = tester.getRect(find.byWidget(widget));
    if (rect.bottom <= scopeRect.top || rect.top >= scopeRect.bottom) {
      continue;
    }
    entries.add(_GlyphPosition(text, rect.left, rect.right, entries.length));
  }
  final paintedSlotFinder = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey('reel_text_rolling_text_slot') ||
          widget.key == const ValueKey('reel_text_settled_glyphs'),
    ),
  );
  for (final element in paintedSlotFinder.evaluate()) {
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      continue;
    }
    final slotTopLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = (renderObject as dynamic).debugVisibleGlyphBounds as List;
    for (final rawBound in bounds) {
      final bound = rawBound as Map;
      final text = bound['text'] as String;
      if (text.trim().isEmpty) {
        continue;
      }
      final top = slotTopLeft.dy + (bound['top'] as double);
      final bottom = slotTopLeft.dy + (bound['bottom'] as double);
      if (bottom <= scopeRect.top || top >= scopeRect.bottom) {
        continue;
      }
      final left = slotTopLeft.dx + (bound['left'] as double);
      final right = slotTopLeft.dx + (bound['right'] as double);
      entries.add(_GlyphPosition(text, left, right, entries.length));
    }
  }

  entries.sort(_compareGlyphPositions);
  return entries;
}

bool _isEffectivelyOpaque(Element element) {
  var opaque = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Opacity && widget.opacity <= 0.01) {
      opaque = false;
      return false;
    }
    return true;
  });
  return opaque;
}

int _debugPreparedFaceLayoutCount(RenderBox renderObject) {
  try {
    return (renderObject as dynamic).debugPreparedFaceLayoutCount as int;
  } on Object {
    return -1;
  }
}

double _leftOfGlyph(List<_GlyphPosition> entries, String glyph) {
  return entries.singleWhere((entry) => entry.text == glyph).left;
}

double _rightOfGlyph(List<_GlyphPosition> entries, String glyph) {
  return entries.singleWhere((entry) => entry.text == glyph).right;
}

List<String> _textPainterGlyphsLeftToRight({
  required String text,
  required TextStyle style,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    maxLines: 1,
  )..layout();
  final entries = <_GlyphPosition>[];
  var offset = 0;
  var index = 0;

  for (final rune in text.runes) {
    final glyph = String.fromCharCode(rune);
    final start = offset;
    offset += glyph.length;
    if (glyph.trim().isEmpty) {
      index++;
      continue;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: offset),
    );
    final left = boxes.isEmpty
        ? math.min(
            painter
                .getOffsetForCaret(TextPosition(offset: start), Rect.zero)
                .dx,
            painter
                .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
                .dx,
          )
        : boxes.fold<double>(
            double.infinity,
            (value, box) => math.min(value, math.min(box.left, box.right)),
          );
    entries.add(_GlyphPosition(glyph, left, left, index));
    index++;
  }

  entries.sort(_compareGlyphPositions);
  return [for (final entry in entries) entry.text];
}

int _compareGlyphPositions(_GlyphPosition a, _GlyphPosition b) {
  final byLeft = a.left.compareTo(b.left);
  if (byLeft != 0) {
    return byLeft;
  }
  return a.sourceOrder.compareTo(b.sourceOrder);
}

class _GlyphPosition {
  const _GlyphPosition(this.text, this.left, this.right, this.sourceOrder);

  final String text;
  final double left;
  final double right;
  final int sourceOrder;
}

TextStyle _textStyle(double fontSize) {
  return TextStyle(fontSize: fontSize);
}

class _CountingTextScaler extends TextScaler {
  final scaledFontSizes = <double>[];

  int get calls => scaledFontSizes.length;

  @override
  double scale(double fontSize) {
    scaledFontSizes.add(fontSize);
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

double? _dryBaselineOf(RenderBox box) {
  try {
    return (box as dynamic).getDryBaseline(
      BoxConstraints.loose(box.size),
      TextBaseline.alphabetic,
    ) as double?;
  } on NoSuchMethodError {
    return null;
  }
}

Future<Uint8List> _rasterize(WidgetTester tester, Key boundaryKey) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  late final Uint8List pixels;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    pixels = data!.buffer.asUint8List();
    image.dispose();
  });
  return pixels;
}

bool _samePixels(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

int _countPixels(Uint8List rgba, bool Function(int r, int g, int b) test) {
  var count = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (test(rgba[i], rgba[i + 1], rgba[i + 2])) {
      count++;
    }
  }
  return count;
}

bool _isReddish(int r, int g, int b) => r > 150 && g < 80 && b < 80;

bool _isDark(int r, int g, int b) => r < 40 && g < 40 && b < 40;
