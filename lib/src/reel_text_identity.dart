part of 'reel_text.dart';

class _WidgetSpanIdentity {
  const _WidgetSpanIdentity(this.key);

  final Key? key;

  bool get isKeyed => key != null;

  static _WidgetSpanIdentity of(WidgetSpan span) {
    return _WidgetSpanIdentity(span.child.key);
  }
}

bool _widgetSpansEquivalentForUnchanged(WidgetSpan from, WidgetSpan to) {
  final fromIdentity = _WidgetSpanIdentity.of(from);
  final toIdentity = _WidgetSpanIdentity.of(to);
  if (fromIdentity.isKeyed || toIdentity.isKeyed) {
    return fromIdentity.key == toIdentity.key;
  }
  return true;
}

bool _widgetSpansEquivalentForMetrics(WidgetSpan from, WidgetSpan to) {
  return _widgetSpansEquivalentForUnchanged(from, to) &&
      from.alignment == to.alignment &&
      from.baseline == to.baseline &&
      from.style == to.style;
}

Key? _widgetAnchorKey(WidgetSpan span) => _WidgetSpanIdentity.of(span).key;

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
