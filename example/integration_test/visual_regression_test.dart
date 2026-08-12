import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reel_text/reel_text.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures stable ReelText rendering on Android', (tester) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    await tester.pumpWidget(const _VisualMatrixApp());
    await tester.pumpAndSettle();
    await binding.takeScreenshot('visual_matrix_settled');

    tester.state<_VisualMatrixAppState>(find.byType(_VisualMatrixApp)).roll();
    await tester.pump();
    expect(
      tester
          .widget<ReelText>(find.byKey(const ValueKey('visual_animated_reel')))
          .text,
      'PERFORMANCE',
    );
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('visual_matrix_target');

    await tester.pumpWidget(const _SelectionPaintApp(selectionEnabled: false));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('selection_paint_reference');

    await tester.pumpWidget(const _SelectionPaintApp(selectionEnabled: true));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('selection_paint_surface');
  });
}

class _VisualMatrixApp extends StatefulWidget {
  const _VisualMatrixApp();

  @override
  State<_VisualMatrixApp> createState() => _VisualMatrixAppState();
}

class _VisualMatrixAppState extends State<_VisualMatrixApp> {
  var _rolled = false;

  static const _options = ReelTextOptions(
    duration: Duration(milliseconds: 480),
    stagger: Duration(milliseconds: 30),
    exitOffset: Duration(milliseconds: 40),
    bounce: 0.18,
  );

  void roll() => setState(() => _rolled = !_rolled);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff10131a),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SceneCard(
                  label: 'LTR / settled',
                  child: ReelText(
                    'Reel 2048',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w800,
                      color: Color(0xfff4f6ff),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SceneCard(
                  label: 'RTL / mixed bidi',
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ReelText(
                      'ETA 12 שלום',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff7ee7d1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SceneCard(
                  label: 'Rich / WidgetSpan',
                  child: ReelText.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Sync '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            width: 44,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xff6659e8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt, size: 20),
                          ),
                        ),
                        const TextSpan(text: ' done'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffffcf70),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SceneCard(
                  label: 'Declarative target',
                  child: ReelText(
                    _rolled ? 'PERFORMANCE' : 'REEL TEXT',
                    key: const ValueKey('visual_animated_reel'),
                    options: _options,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Color(0xfff995bd),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('visual_roll_toggle'),
                  onPressed: roll,
                  child: const Text('ROLL'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff1a2030),
        border: Border.all(color: const Color(0xff30394d)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xff8790a8))),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectionPaintApp extends StatelessWidget {
  const _SelectionPaintApp({required this.selectionEnabled});

  final bool selectionEnabled;

  @override
  Widget build(BuildContext context) {
    final paintedStyle = TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.w900,
      foreground: Paint()..color = const Color(0x999f7aea),
      background: Paint()..color = const Color(0x5538b2ac),
      shadows: const [
        Shadow(color: Color(0xaa000000), blurRadius: 8, offset: Offset(4, 5)),
      ],
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xaaee6c4d),
      decorationThickness: 3,
    );
    final reel = Center(
      child: ReelText.rich(TextSpan(text: 'Paint', style: paintedStyle)),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xffe8edf5),
        body: selectionEnabled ? SelectionArea(child: reel) : reel,
      ),
    );
  }
}
