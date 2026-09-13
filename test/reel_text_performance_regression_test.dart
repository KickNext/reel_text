import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';

const _surfaceKey = ValueKey('performance_reel');
const _options = ReelTextOptions(
  duration: Duration(milliseconds: 120),
  stagger: Duration.zero,
  exitOffset: Duration.zero,
  curve: Curves.linear,
  bounce: 0,
  skipUnchanged: false,
);

void main() {
  testWidgets(
    'one render surface is reused across settled and rolling states',
    (tester) async {
      await tester.pumpWidget(_frame('0000'));

      final state = tester.state(find.byKey(_surfaceKey));
      final surface = _settledSurface(tester);
      expect(_frameMeasureCount(state), 1);
      expect(_preparedFaceCount(surface), 1);

      await tester.pumpWidget(_frame('1111'));
      await tester.pump();

      expect(_rollingSurface(tester), same(surface));
      expect(_frameMeasureCount(state), 2);
      expect(_preparedFaceCount(surface), 2);
      expect(_disposedPreparedFaceCount(surface), 0);

      await tester.pumpAndSettle();

      expect(_settledSurface(tester), same(surface));
      expect(_frameMeasureCount(state), 2);
      expect(_preparedFaceCount(surface), 3);
      expect(_disposedPreparedFaceCount(surface), 0);
    },
  );

  testWidgets('prepared glyphs allocate no new layouts during animation', (
    tester,
  ) async {
    await tester.pumpWidget(_frame('0000'));
    await tester.pumpWidget(_frame('1111'));
    await tester.pump();

    final surface = _rollingSurface(tester);
    final preparedFaces = _preparedFaceCount(surface);
    final disposedFaces = _disposedPreparedFaceCount(surface);

    expect(preparedFaces, 2);
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_preparedFaceCount(surface), preparedFaces);
      expect(_disposedPreparedFaceCount(surface), disposedFaces);
    }
  });

  testWidgets('recurring rolls reuse measured frames and prepared glyphs', (
    tester,
  ) async {
    await tester.pumpWidget(_frame('0000'));
    final state = tester.state(find.byKey(_surfaceKey));
    final surface = _settledSurface(tester);

    await _rollTo(tester, '1111');
    await _rollTo(tester, '0000');
    final warmFrameMeasures = _frameMeasureCount(state);
    final warmPreparedFaces = _preparedFaceCount(surface);
    final warmDisposedFaces = _disposedPreparedFaceCount(surface);

    expect(warmFrameMeasures, 2);
    expect(warmPreparedFaces, 4);
    expect(warmDisposedFaces, 0);

    for (var roll = 0; roll < 8; roll++) {
      await _rollTo(tester, roll.isEven ? '1111' : '0000');
      expect(_settledSurface(tester), same(surface));
      expect(_frameMeasureCount(state), warmFrameMeasures);
      expect(_preparedFaceCount(surface), warmPreparedFaces);
      expect(_disposedPreparedFaceCount(surface), warmDisposedFaces);
    }
  });
}

Widget _frame(String text) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ReelText(
        text,
        key: _surfaceKey,
        options: _options,
        style: const TextStyle(
          fontFamily: 'Ahem',
          fontSize: 32,
          height: 1,
        ),
      ),
    ),
  );
}

Future<void> _rollTo(WidgetTester tester, String text) async {
  await tester.pumpWidget(_frame(text));
  await tester.pump();
  await tester.pumpAndSettle();
}

RenderBox _settledSurface(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('reel_text_settled_glyphs')),
  );
}

RenderBox _rollingSurface(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('reel_text_rolling_text_slot')),
  );
}

int _frameMeasureCount(State<StatefulWidget> state) {
  return (state as dynamic).debugFrameMeasureCount as int;
}

int _preparedFaceCount(RenderBox surface) {
  return (surface as dynamic).debugPreparedFaceLayoutCount as int;
}

int _disposedPreparedFaceCount(RenderBox surface) {
  return (surface as dynamic).debugDisposedPreparedFaceLayoutCount as int;
}
