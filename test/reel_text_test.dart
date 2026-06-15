import 'dart:async';

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
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reel_text_settled_glyphs')))
          .width,
      greaterThan(boxWidth),
    );
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

    final rollingWidth = tester
        .getSize(find.byKey(const ValueKey('reel_text_rolling')))
        .width;

    expect(tester.getSize(find.byKey(reelKey)).width, rollingWidth);
    expect(rollingWidth, greaterThan(fromWidth));
    expect(rollingWidth, lessThan(toWidth));
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
    final finiteFaceWidths = tester
        .widgetList<OverflowBox>(find.byType(OverflowBox))
        .map((box) => box.maxWidth)
        .whereType<double>()
        .where((width) => width.isFinite)
        .toList();

    expect(rollingWidth, greaterThan(0));
    expect(rollingWidth, lessThan(painter.size.width));
    expect(finiteFaceWidths, contains(greaterThan(painter.size.width + 3)));

    await tester.pumpAndSettle();

    final settledFaceWidths = tester
        .widgetList<OverflowBox>(find.byType(OverflowBox))
        .map((box) => box.maxWidth)
        .whereType<double>()
        .where((width) => width.isFinite)
        .toList();

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
    expect(settledFaceWidths, contains(greaterThan(painter.size.width + 3)));
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
              ExcludeSemantics(
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
              ExcludeSemantics(
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
    final visualGlyph = tester.getRect(find.text('👍🏽'));

    expect(glyphRow.right, closeTo(box.right, 0.01));
    expect(visualGlyph.right, greaterThanOrEqualTo(box.right));
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
    final lastGlyph = tester.getRect(find.text('o'));

    expect(glyphRow.right, closeTo(box.right, 0.01));
    expect(lastGlyph.right, greaterThanOrEqualTo(box.right));
  });

  testWidgets('textAlign end keeps Text-like size under loose constraints', (
    tester,
  ) async {
    const boxKey = ValueKey('reel_text_loose_alignment_box');
    const reelKey = ValueKey('reel_text_loose_alignment_reel');
    final constraints = BoxConstraints(maxWidth: 240);
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
    final lastGlyph = tester.getRect(find.text('o'));

    expect(reel.width, closeTo(painter.size.width, 0.01));
    expect(lastGlyph.right, lessThan(box.right));
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

      final duringLeft = tester.getRect(find.text('S')).left;

      await tester.pumpAndSettle();

      final settledLeft = tester.getRect(find.text('S')).left;
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
      bounce: 0.8,
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
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getSize(find.byKey(reelKey)), settledSize);
    final clip = tester.widget<ClipRect>(find.byType(ClipRect).first);
    final rect = clip.clipper!.getClip(settledSize);

    expect(rect.top, lessThan(0));
    expect(rect.bottom, greaterThan(settledSize.height));
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

      final clipFinder = find.byType(ClipRect).first;
      final clip = tester.widget<ClipRect>(clipFinder);
      final clipRect = clip.clipper!.getClip(tester.getSize(clipFinder));
      final translations = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((widget) => widget.transform.getTranslation().y)
          .where((dy) => dy.abs() > 0.01)
          .toList();

      expect(translations, hasLength(1));
      expect(translations.single, greaterThan(clipRect.bottom));
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
    expect(find.byType(ClipRect), findsNWidgets(2));

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
}
