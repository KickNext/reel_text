import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reel_text/reel_text.dart';

const _columns = 16;
const _rows = 16;
const _rollDuration = Duration(milliseconds: 560);
const _rollInterval = Duration(milliseconds: 650);
const _measuredRolls = 4;
const _scenarios = <_BenchmarkScenario>[
  (reportKey: 'plain_1', tileCount: 1, chromatic: false),
  (reportKey: 'chromatic_1', tileCount: 1, chromatic: true),
  (reportKey: 'plain_4', tileCount: 4, chromatic: false),
  (reportKey: 'chromatic_4', tileCount: 4, chromatic: true),
  (reportKey: 'plain_8', tileCount: 8, chromatic: false),
  (reportKey: 'chromatic_8', tileCount: 8, chromatic: true),
  (reportKey: 'plain_16', tileCount: 16, chromatic: false),
  (reportKey: 'chromatic_16', tileCount: 16, chromatic: true),
  (reportKey: 'plain_32', tileCount: 32, chromatic: false),
  (reportKey: 'chromatic_32', tileCount: 32, chromatic: true),
  (reportKey: 'plain_64', tileCount: 64, chromatic: false),
  (reportKey: 'chromatic_64', tileCount: 64, chromatic: true),
  (reportKey: 'plain_128', tileCount: 128, chromatic: false),
  (reportKey: 'chromatic_128', tileCount: 128, chromatic: true),
  (reportKey: 'plain_256', tileCount: 256, chromatic: false),
  (reportKey: 'chromatic_256', tileCount: 256, chromatic: true),
];

typedef _BenchmarkScenario = ({
  String reportKey,
  int tileCount,
  bool chromatic,
});

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('profiles independent rolling-label workloads', (tester) async {
    for (final scenario in _scenarios) {
      await tester.pumpWidget(_BenchmarkApp(scenario: scenario));
      await tester.pumpAndSettle();

      expect(find.byType(ReelText), findsNWidgets(scenario.tileCount));

      await _rollGrid(tester, rolls: 2);
      await binding.watchPerformance(
        () => _rollGrid(tester, rolls: _measuredRolls),
        reportKey: scenario.reportKey,
      );
    }
  });
}

Future<void> _rollGrid(WidgetTester tester, {required int rolls}) async {
  for (var roll = 0; roll < rolls; roll++) {
    await tester.tap(find.byKey(const ValueKey('benchmark_toggle')));
    await tester.pump();
    await tester.binding.delayed(_rollInterval);
  }
}

class _BenchmarkApp extends StatelessWidget {
  const _BenchmarkApp({required this.scenario});

  final _BenchmarkScenario scenario;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: _BenchmarkGrid(scenario: scenario));
  }
}

class _BenchmarkGrid extends StatefulWidget {
  const _BenchmarkGrid({required this.scenario});

  final _BenchmarkScenario scenario;

  @override
  State<_BenchmarkGrid> createState() => _BenchmarkGridState();
}

class _BenchmarkGridState extends State<_BenchmarkGrid> {
  var _phase = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          for (var row = 0; row < _rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < _columns; column++)
                    Expanded(child: _buildCell(row * _columns + column)),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('benchmark_toggle'),
        onPressed: () => setState(() => _phase = !_phase),
        child: const Icon(Icons.sync),
      ),
    );
  }

  Widget _buildCell(int index) {
    if (index >= widget.scenario.tileCount) {
      return const SizedBox.shrink();
    }
    final showReel = index.isEven ? _phase : !_phase;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ReelText(
          showReel ? 'reel' : 'text',
          options: ReelTextOptions(
            direction: showReel ? ReelTextDirection.up : ReelTextDirection.down,
            duration: _rollDuration,
            stagger: const Duration(milliseconds: 38),
            bounce: 0.12,
            colorBuilder: widget.scenario.chromatic
                ? chromatic(from: index * 19)
                : null,
          ),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
