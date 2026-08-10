# Basic example

`ReelText` animates automatically whenever its text changes:

```dart
import 'package:flutter/material.dart';
import 'package:reel_text/reel_text.dart';

void main() => runApp(const ReelTextExample());

class ReelTextExample extends StatefulWidget {
  const ReelTextExample({super.key});

  @override
  State<ReelTextExample> createState() => _ReelTextExampleState();
}

class _ReelTextExampleState extends State<ReelTextExample> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('reel_text example')),
        body: Center(
          child: ReelText(
            '$_count',
            options: const ReelTextOptions(
              direction: ReelTextDirection.up,
            ),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _count++),
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

See the [interactive showcase](https://kicknext.github.io/reel_text/) for more
patterns, including async labels, button feedback, sequences, rich text, and
editable replacements.
