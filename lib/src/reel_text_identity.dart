part of 'reel_text.dart';

bool _widgetSpansEquivalentForUnchanged(WidgetSpan from, WidgetSpan to) {
  return _widgetAnchorKey(from) == _widgetAnchorKey(to);
}

bool _widgetSpansEquivalentForMetrics(WidgetSpan from, WidgetSpan to) {
  return _widgetSpansEquivalentForUnchanged(from, to) &&
      from.alignment == to.alignment &&
      from.baseline == to.baseline &&
      from.style == to.style;
}

Key? _widgetAnchorKey(WidgetSpan span) => span.child.key;

GlobalKey? _globalWidgetAnchorKey(WidgetSpan span) {
  final key = _widgetAnchorKey(span);
  return key is GlobalKey ? key : null;
}

bool _sameWidgetAnchorSignature(InlineSpan? a, InlineSpan? b) {
  return listEquals(_widgetAnchorSignature(a), _widgetAnchorSignature(b));
}

List<Key?> _widgetAnchorSignature(InlineSpan? span) {
  final keys = <Key?>[];
  void collect(InlineSpan current) {
    if (current is WidgetSpan) {
      keys.add(_widgetAnchorKey(current));
      return;
    }
    if (current is TextSpan) {
      current.visitDirectChildren((child) {
        collect(child);
        return true;
      });
    }
  }

  if (span != null) {
    collect(span);
  }
  return keys;
}
