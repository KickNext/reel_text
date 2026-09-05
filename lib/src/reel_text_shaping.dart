part of 'reel_text.dart';

// Arabic letters need their neighbours for contextual forms and ligatures.
// Keep consecutive Arabic graphemes (including join controls and marks) in a
// single paint/motion unit. Flutter still performs shaping; we do not replace
// characters with presentation forms. Numbers, spaces and WidgetSpans remain
// separate units. This also preserves joining across rich-text style runs.
// Joining controls: https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-23/
final _arabicLetter = RegExp(
  r'[\u0620-\u064a\u066e-\u066f\u0671-\u06d3\u06d5\u06e5-\u06e6'
  r'\u06ee-\u06ef\u06fa-\u06fc\u06ff\u0750-\u077f\u0870-\u088f'
  r'\u08a0-\u08c9\ufb50-\ufdff\ufe70-\ufefc]',
);
final _arabicContinuation = RegExp(
  r'^[\u0300-\u036f\u0610-\u061a\u064b-\u065f\u0670'
  r'\u06d6-\u06ed\u08ca-\u08ff\u200c\u200d]+$',
);

List<_ReelTextToken> _joinArabicTokens(
  List<_ReelTextToken> tokens,
  String text,
) {
  // The overwhelmingly common Latin/counter path keeps its original list.
  if (!_arabicLetter.hasMatch(text)) {
    return tokens;
  }
  final result = <_ReelTextToken>[];
  var index = 0;
  while (index < tokens.length) {
    final first = tokens[index];
    final leadingControl = _arabicContinuation.hasMatch(first.text) &&
        index + 1 < tokens.length &&
        _arabicLetter.hasMatch(tokens[index + 1].text);
    if (first.isWidget ||
        (!_arabicLetter.hasMatch(first.text) && !leadingControl)) {
      result.add(first);
      index++;
      continue;
    }
    final start = index++;
    while (index < tokens.length &&
        !tokens[index].isWidget &&
        (_arabicLetter.hasMatch(tokens[index].text) ||
            _arabicContinuation.hasMatch(tokens[index].text))) {
      index++;
    }
    if (index == start + 1) {
      result.add(first);
      continue;
    }
    final parts = tokens.sublist(start, index);
    result.add(_ReelTextToken.text(
      text: parts.map((part) => part.text).join(),
      style: first.style,
      shapedParts: parts,
    ));
  }
  return result;
}

TextSpan _paintSpanForToken(
  _ReelTextToken token, {
  Color? tint,
  double tintProgress = 0,
  Color defaultColor = Colors.black,
}) {
  TextStyle effectiveStyle(TextStyle style) => tint == null
      ? style
      : style.copyWith(
          color: Color.lerp(tint, style.color ?? defaultColor, tintProgress),
        );
  final parts = token.shapedParts;
  if (parts == null) {
    return TextSpan(text: token.text, style: effectiveStyle(token.style));
  }
  // Merge equal adjacent styles so a plain word shapes exactly like Text.
  final spans = <TextSpan>[];
  for (final part in parts) {
    final style = effectiveStyle(part.style);
    if (spans.isNotEmpty && spans.last.style == style) {
      final previous = spans.removeLast();
      spans.add(TextSpan(text: '${previous.text}${part.text}', style: style));
    } else {
      spans.add(TextSpan(text: part.text, style: style));
    }
  }
  return TextSpan(style: token.style, children: spans);
}
