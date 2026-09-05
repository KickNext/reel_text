import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';

const _boundary = ValueKey('visual_boundary');
const _reel = ValueKey('visual_reel');
const _style = TextStyle(
  fontFamily: 'NotoNaskhArabic',
  fontFamilyFallback: ['NotoSans'],
  fontSize: 44,
  color: Color(0xff172033),
);
const _options = ReelTextOptions(
  duration: Duration(milliseconds: 400),
  stagger: Duration.zero,
  exitOffset: Duration.zero,
  curve: Curves.linear,
  bounce: 0,
);

Widget _host(Widget child, {bool selection = false}) => MaterialApp(
      home: Material(
        child: RepaintBoundary(
          key: _boundary,
          child: ColoredBox(
            color: const Color(0xffe8edf5),
            child: DefaultTextStyle(
              style: _style,
              child: Center(
                child: selection ? SelectionArea(child: child) : child,
              ),
            ),
          ),
        ),
      ),
    );

Future<ui.Image> _image(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  return (await tester.runAsync(() => boundary.toImage()))!;
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final image = await _image(tester);
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  setUpAll(() async {
    for (final family in ['NotoNaskhArabic', 'NotoSans']) {
      final bytes = File('test/fonts/$family-Regular.ttf').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  for (final word in [
    'مرحبا',
    'العربية',
    'السَّلام',
    'لا',
    'می\u200cروم',
    'ب\u200dب',
    '\u200dب',
  ]) {
    testWidgets('Arabic shaping matches Text: $word', (tester) async {
      await tester.pumpWidget(_host(
          ReelText(word, style: _style, textDirection: TextDirection.rtl)));
      final actual = await _pixels(tester);
      await tester.pumpWidget(
          _host(Text(word, style: _style, textDirection: TextDirection.rtl)));
      expect(actual, orderedEquals(await _pixels(tester)));
    });
  }

  testWidgets('Arabic joins across rich styles and preserves selection paint',
      (tester) async {
    const span = TextSpan(children: [
      TextSpan(text: 'مر', style: TextStyle(color: Colors.red)),
      TextSpan(text: 'حبا', style: TextStyle(color: Colors.blue)),
    ]);
    const reel =
        ReelText.rich(span, style: _style, textDirection: TextDirection.rtl);
    await tester.pumpWidget(_host(reel));
    final actual = await _pixels(tester);
    await tester.pumpWidget(_host(reel, selection: true));
    expect(await _pixels(tester), orderedEquals(actual));
    await tester.pumpWidget(_host(const Text.rich(span,
        style: _style, textDirection: TextDirection.rtl)));
    expect(actual, orderedEquals(await _pixels(tester)));
  });

  testWidgets('Arabic is one moving unit and retains its connected glyphs',
      (tester) async {
    Widget frame(String value) => _host(ReelText(value,
        key: _reel,
        style: _style,
        options: _options,
        textDirection: TextDirection.rtl));
    await tester.pumpWidget(frame('مرحبا'));
    await tester.pumpWidget(frame('العربية'));
    await tester.pump(const Duration(milliseconds: 200));
    final surface = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('reel_text_rolling_text_slot')),
    );
    final bounds =
        (surface as dynamic).debugVisibleGlyphBounds as List<dynamic>;
    expect(bounds.map((dynamic item) => item['text']),
        unorderedEquals(['مرحبا', 'العربية']));
    await tester.pumpAndSettle();
    final actual = await _pixels(tester);
    await tester.pumpWidget(_host(const Text('العربية',
        style: _style, textDirection: TextDirection.rtl)));
    expect(actual, orderedEquals(await _pixels(tester)));
  });

  testWidgets('Arabic rich colors return after tint and survive interruption',
      (tester) async {
    TextSpan span(bool target) => TextSpan(children: [
          TextSpan(
              text: target ? 'العر' : 'مر',
              style: const TextStyle(color: Colors.red)),
          TextSpan(
              text: target ? 'بية' : 'حبا',
              style: const TextStyle(color: Colors.blue)),
        ]);
    Widget frame(bool target) => _host(ReelText.rich(span(target),
        key: _reel,
        style: _style,
        textDirection: TextDirection.rtl,
        options: _options.copyWith(color: Colors.green)));
    await tester.pumpWidget(frame(false));
    await tester.pumpWidget(frame(true));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(frame(false));
    await tester.pumpAndSettle();
    final actual = await _pixels(tester);
    await tester.pumpWidget(_host(Text.rich(span(false),
        style: _style, textDirection: TextDirection.rtl)));
    expect(actual, orderedEquals(await _pixels(tester)));
  });

  testWidgets('Arabic units preserve WidgetSpan and mixed bidi layout',
      (tester) async {
    TextSpan span(String word) => TextSpan(children: [
          TextSpan(text: '$word '),
          const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                  width: 30,
                  height: 24,
                  child: ColoredBox(color: Colors.orange))),
          const TextSpan(text: ' 123'),
        ]);
    Widget frame(String word) => _host(
        ReelText.rich(span(word),
            key: _reel,
            style: _style,
            textDirection: TextDirection.rtl,
            options: _options),
        selection: true);
    await tester.pumpWidget(frame('مرحبا'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(frame('العربية'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    expect(
        find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == Colors.orange),
        findsOneWidget);
    await tester.pumpAndSettle();
    final actual = await _pixels(tester);
    await tester.pumpWidget(_host(Text.rich(span('العربية'),
        style: _style, textDirection: TextDirection.rtl)));
    final expected = await _pixels(tester);
    var maxDelta = 0;
    var changed = 0;
    for (var i = 0; i < actual.length; i++) {
      final delta = (actual[i] - expected[i]).abs();
      if (delta > maxDelta) maxDelta = delta;
      if (delta > 0) changed++;
    }
    // Independent inline paint origins can round antialiasing differently
    // from one paragraph. Allow sparse, low-amplitude edge differences only.
    expect(maxDelta, lessThanOrEqualTo(16));
    expect(changed / actual.length, lessThan(0.001));
  });

  testWidgets('fixed-frame rendering goldens', (tester) async {
    // The pinned SDK job owns the stored raster baseline. Other SDKs still
    // run the Text-reference comparisons above.
    tester.view.physicalSize = const Size(640, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget frame(bool target) => _host(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReelText(target ? 'العربية 456' : 'مرحبا 123',
                key: _reel,
                options: _options,
                style: _style,
                textDirection: TextDirection.rtl),
            ReelText(target ? '2048' : '1999',
                options: _options.copyWith(color: Colors.red),
                style: const TextStyle(fontFamily: 'NotoSans', fontSize: 40)),
          ],
        ));
    await tester.pumpWidget(frame(false));
    await tester.pumpAndSettle();
    await expectLater(
        find.byKey(_boundary), matchesGoldenFile('goldens/settled.png'));
    await tester.pumpWidget(frame(true));
    await tester.pump();
    for (final ms in [100, 200, 300, 400, 500, 600]) {
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
          find.byKey(_boundary), matchesGoldenFile('goldens/roll_${ms}ms.png'));
    }
    await tester.pumpAndSettle();
    await expectLater(
        find.byKey(_boundary), matchesGoldenFile('goldens/target.png'));
  }, skip: !const bool.fromEnvironment('REEL_GOLDENS'));
}
