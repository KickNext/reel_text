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

Key? _widgetAnchorKey(WidgetSpan span) => _WidgetSpanIdentity.of(span).key;

bool _sameWidgetAnchorSignature(InlineSpan? a, InlineSpan? b) {
  final aKeys = _widgetAnchorSignature(a);
  final bKeys = _widgetAnchorSignature(b);
  if (aKeys.length != bKeys.length) {
    return false;
  }
  for (var i = 0; i < aKeys.length; i++) {
    if (aKeys[i] != bKeys[i]) {
      return false;
    }
  }
  return true;
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
