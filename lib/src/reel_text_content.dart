part of 'reel_text.dart';

class _ReelTextContent {
  const _ReelTextContent({
    required this.span,
    required this.plainText,
    required this.tokens,
  });

  final InlineSpan span;
  final String plainText;
  final List<_ReelTextToken> tokens;

  bool get hasWidgets => tokens.any((token) => token.isWidget);

  factory _ReelTextContent.plain(String text, TextStyle style) {
    final tokens = <_ReelTextToken>[];
    for (final glyph in text.characters) {
      tokens.add(_ReelTextToken.text(
        text: glyph,
        style: style,
      ));
    }
    return _ReelTextContent(
      span: TextSpan(text: text, style: style),
      plainText: text,
      tokens: tokens,
    );
  }

  factory _ReelTextContent.rich(InlineSpan span, TextStyle style) {
    final tokens = <_ReelTextToken>[];
    _collectTokens(span, style, tokens);
    return _ReelTextContent(
      span: TextSpan(style: style, children: [span]),
      plainText: _rollingTextFor(span),
      tokens: tokens,
    );
  }

  int get length => tokens.length;

  _ReelTextToken? tokenAt(int index) {
    if (index < 0 || index >= tokens.length) {
      return null;
    }
    return tokens[index];
  }

  Iterable<int> get widgetTokenIndexes sync* {
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].isWidget) {
        yield i;
      }
    }
  }

  Iterable<_ReelTextWidgetToken> get widgetTokens sync* {
    for (final index in widgetTokenIndexes) {
      yield _ReelTextWidgetToken(index, tokens[index].widgetSpan!);
    }
  }
}

class _ReelTextToken {
  const _ReelTextToken.text({
    required this.text,
    required this.style,
  }) : widgetSpan = null;

  const _ReelTextToken.widget({
    required WidgetSpan this.widgetSpan,
    required this.style,
  }) : text = _placeholderGlyph;

  final String text;
  final TextStyle style;
  final WidgetSpan? widgetSpan;

  bool get isWidget => widgetSpan != null;
}

class _ReelTextWidgetToken {
  const _ReelTextWidgetToken(this.index, this.span);

  final int index;
  final WidgetSpan span;
}

const _placeholderGlyph = '\uFFFC';

String _rollingTextFor(InlineSpan span) {
  return span.toPlainText(
    includeSemanticsLabels: false,
    includePlaceholders: true,
  );
}

void _collectTokens(
  InlineSpan span,
  TextStyle inherited,
  List<_ReelTextToken> tokens,
) {
  if (span is WidgetSpan) {
    tokens.add(_ReelTextToken.widget(
      widgetSpan: span,
      style: inherited.merge(span.style),
    ));
    return;
  }

  if (span is! TextSpan) {
    throw FlutterError(
      'ReelText.rich supports TextSpan trees and WidgetSpan leaves only.',
    );
  }

  final style = inherited.merge(span.style);
  final text = span.text;
  if (text != null && text.isNotEmpty) {
    for (final glyph in text.characters) {
      tokens.add(_ReelTextToken.text(
        text: glyph,
        style: style,
      ));
    }
  }

  final children = span.children;
  if (children == null) {
    return;
  }
  for (final child in children) {
    _collectTokens(child, style, tokens);
  }
}
