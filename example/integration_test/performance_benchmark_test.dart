import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reel_text/reel_text.dart';

const _columns = 12;
const _rows = 16;
const _rollDuration = Duration(milliseconds: 560);
const _rollInterval = Duration(milliseconds: 650);
const _measuredRolls = 6;
const _scenarios = <_BenchmarkScenario>[
  (reportKey: 'plain_24', tileCount: 24, chromatic: false),
  (reportKey: 'plain_96', tileCount: 96, chromatic: false),
  (reportKey: 'chromatic_96', tileCount: 96, chromatic: true),
  (reportKey: 'plain_192', tileCount: 192, chromatic: false),
  (reportKey: 'chromatic_192', tileCount: 192, chromatic: true),
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
