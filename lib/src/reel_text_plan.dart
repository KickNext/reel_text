part of 'reel_text.dart';

class _RollPlan {
  const _RollPlan({
    required this.slots,
    required this.totalDuration,
  });

  final List<_SlotPlan> slots;
  final Duration totalDuration;

  bool get hasMotion => slots.any((slot) => slot.changed);

  static _RollPlan create({
    required _MeasuredReelTextRun from,
    required _MeasuredReelTextRun to,
    required ReelTextOptions options,
    bool alignVisualOrderFromEnd = false,
  }) {
    final fromOrder = from.visualOrder;
    final toOrder = to.visualOrder;
    final state = _SlotBuildState(
      totalSlots: math.max(fromOrder.length, toOrder.length),
    );
    final chunks = <_PlanChunk>[];
    final anchors = _matchedWidgetAnchors(from, to);
    var fromStart = 0;
    var toStart = 0;

    for (final anchor in anchors) {
      chunks.add(_PlanSegmentChunk(
        order: chunks.length,
        fromStart: fromStart,
        fromEnd: anchor.fromIndex,
        toStart: toStart,
        toEnd: anchor.toIndex,
      ));
      chunks.add(_PlanAnchorChunk(
        order: chunks.length,
        fromIndex: anchor.fromIndex,
        toIndex: anchor.toIndex,
      ));
      fromStart = anchor.fromIndex + 1;
      toStart = anchor.toIndex + 1;
    }

    chunks.add(_PlanSegmentChunk(
      order: chunks.length,
      fromStart: fromStart,
      fromEnd: from.length,
      toStart: toStart,
      toEnd: to.length,
    ));

    _sortPlanChunks(chunks, fromOrder, toOrder);

    for (final chunk in chunks) {
      if (chunk is _PlanAnchorChunk) {
        _appendSlot(
          state: state,
          options: options,
          from: from.endpointAt(chunk.fromIndex),
          to: to.endpointAt(chunk.toIndex),
          forceUnchanged: true,
        );
        continue;
      }
      final segment = chunk as _PlanSegmentChunk;

      _appendPlanSegment(
        state: state,
        options: options,
        from: from,
        to: to,
        fromVisualOrder: fromOrder,
        toVisualOrder: toOrder,
        alignVisualOrderFromEnd: alignVisualOrderFromEnd,
        fromStart: segment.fromStart,
        fromEnd: segment.fromEnd,
        toStart: segment.toStart,
        toEnd: segment.toEnd,
      );
    }

    return _RollPlan(
      slots: state.slots,
      totalDuration: Duration(milliseconds: state.maxEndMs),
    );
  }
}

void _appendPlanSegment({
  required _SlotBuildState state,
  required ReelTextOptions options,
  required _MeasuredReelTextRun from,
  required _MeasuredReelTextRun to,
  required List<int> fromVisualOrder,
  required List<int> toVisualOrder,
  required bool alignVisualOrderFromEnd,
  required int fromStart,
  required int fromEnd,
  required int toStart,
  required int toEnd,
}) {
  final fromOrder = _visualOrderInRange(
    fromVisualOrder,
    start: fromStart,
    end: fromEnd,
  );
  final toOrder = _visualOrderInRange(
    toVisualOrder,
    start: toStart,
    end: toEnd,
  );
  final maxLen = math.max(fromOrder.length, toOrder.length);
  for (var i = 0; i < maxLen; i++) {
    final fromOrderIndex =
        alignVisualOrderFromEnd ? i - (maxLen - fromOrder.length) : i;
    final toOrderIndex =
        alignVisualOrderFromEnd ? i - (maxLen - toOrder.length) : i;
    final fromIndex = fromOrderIndex >= 0 && fromOrderIndex < fromOrder.length
        ? fromOrder[fromOrderIndex]
        : -1;
    final toIndex = toOrderIndex >= 0 && toOrderIndex < toOrder.length
        ? toOrder[toOrderIndex]
        : -1;
    var fromEndpoint = from.endpointAt(fromIndex);
    final toEndpoint = to.endpointAt(toIndex);
    if (_shouldSuppressMovingGlobalWidgetSource(
      fromEndpoint: fromEndpoint,
      toEndpoint: toEndpoint,
      target: to.content,
    )) {
      fromEndpoint = null;
    }
    if (fromEndpoint == null && toEndpoint == null) {
      continue;
    }
    _appendSlot(
      state: state,
      options: options,
      from: fromEndpoint,
      to: toEndpoint,
    );
  }
}

bool _shouldSuppressMovingGlobalWidgetSource({
  required _SlotEndpoint? fromEndpoint,
  required _SlotEndpoint? toEndpoint,
  required _ReelTextContent target,
}) {
  final fromSpan = fromEndpoint?.token.widgetSpan;
  if (fromSpan == null) {
    return false;
  }
  final fromKey = _globalWidgetAnchorKey(fromSpan);
  if (fromKey == null) {
    return false;
  }

  final toSpan = toEndpoint?.token.widgetSpan;
  if (toSpan != null && _globalWidgetAnchorKey(toSpan) == fromKey) {
    return false;
  }

  return _containsGlobalWidgetKey(target, fromKey);
}

bool _containsGlobalWidgetKey(_ReelTextContent content, GlobalKey key) {
  for (final widget in content.widgetTokens) {
    if (_globalWidgetAnchorKey(widget.span) == key) {
      return true;
    }
  }
  return false;
}

sealed class _PlanChunk {
  const _PlanChunk({required this.order});

  final int order;
}

class _PlanSegmentChunk extends _PlanChunk {
  const _PlanSegmentChunk({
    required super.order,
    required this.fromStart,
    required this.fromEnd,
    required this.toStart,
    required this.toEnd,
  });

  final int fromStart;
  final int fromEnd;
  final int toStart;
  final int toEnd;
}

class _PlanAnchorChunk extends _PlanChunk {
  const _PlanAnchorChunk({
    required super.order,
    required this.fromIndex,
    required this.toIndex,
  });

  final int fromIndex;
  final int toIndex;
}

void _sortPlanChunks(
  List<_PlanChunk> chunks,
  List<int> fromVisualOrder,
  List<int> toVisualOrder,
) {
  final fromRanks = _visualRanks(fromVisualOrder);
  final toRanks = _visualRanks(toVisualOrder);

  chunks.sort((a, b) {
    final byRank = _chunkVisualRank(a, fromRanks, toRanks).compareTo(
      _chunkVisualRank(b, fromRanks, toRanks),
    );
    if (byRank != 0) {
      return byRank;
    }
    return a.order.compareTo(b.order);
  });
}

int _chunkVisualRank(
  _PlanChunk chunk,
  Map<int, int> fromRanks,
  Map<int, int> toRanks,
) {
  if (chunk is _PlanAnchorChunk) {
    return fromRanks[chunk.fromIndex] ??
        toRanks[chunk.toIndex] ??
        chunk.fromIndex;
  }
  final segment = chunk as _PlanSegmentChunk;

  final fromRank = _minRankInRange(
    fromRanks,
    start: segment.fromStart,
    end: segment.fromEnd,
  );
  if (fromRank != null) {
    return fromRank;
  }
  return _minRankInRange(
        toRanks,
        start: segment.toStart,
        end: segment.toEnd,
      ) ??
      chunk.order;
}

List<int> _visualOrderInRange(
  List<int> visualOrder, {
  required int start,
  required int end,
}) {
  if (start >= end) {
    return const [];
  }
  return [
    for (final index in visualOrder)
      if (index >= start && index < end) index,
  ];
}

Map<int, int> _visualRanks(List<int> visualOrder) {
  return {
    for (var i = 0; i < visualOrder.length; i++) visualOrder[i]: i,
  };
}

int? _minRankInRange(
  Map<int, int> ranks, {
  required int start,
  required int end,
}) {
  int? minRank;
  for (var i = start; i < end; i++) {
    final rank = ranks[i];
    if (rank == null) {
      continue;
    }
    minRank = minRank == null ? rank : math.min(minRank, rank);
  }
  return minRank;
}

class _MatchedWidgetAnchor {
  const _MatchedWidgetAnchor({
    required this.fromIndex,
    required this.toIndex,
  });

  final int fromIndex;
  final int toIndex;
}

List<_MatchedWidgetAnchor> _matchedWidgetAnchors(
  _MeasuredReelTextRun from,
  _MeasuredReelTextRun to,
) {
  final candidates = [
    ..._keyedWidgetAnchors(from.content, to.content),
    ..._unkeyedWidgetAnchors(from.content, to.content),
  ]..sort(_compareWidgetAnchors);

  final anchors = <_MatchedWidgetAnchor>[];
  var lastToIndex = -1;
  for (final candidate in candidates) {
    if (candidate.toIndex <= lastToIndex) {
      continue;
    }
    anchors.add(candidate);
    lastToIndex = candidate.toIndex;
  }
  return anchors;
}

List<_MatchedWidgetAnchor> _keyedWidgetAnchors(
  _ReelTextContent from,
  _ReelTextContent to,
) {
  final toByKey = <Key, List<_ReelTextWidgetToken>>{};
  for (final widget in to.widgetTokens) {
    final key = _widgetAnchorKey(widget.span);
    if (key == null) {
      continue;
    }
    (toByKey[key] ??= []).add(widget);
  }

  final anchors = <_MatchedWidgetAnchor>[];
  for (final widget in from.widgetTokens) {
    final key = _widgetAnchorKey(widget.span);
    if (key == null) {
      continue;
    }
    final target = _takeFirst(toByKey[key]);
    if (target == null) {
      continue;
    }
    anchors.add(_MatchedWidgetAnchor(
      fromIndex: widget.index,
      toIndex: target.index,
    ));
  }
  return anchors;
}

List<_MatchedWidgetAnchor> _unkeyedWidgetAnchors(
  _ReelTextContent from,
  _ReelTextContent to,
) {
  final fromWidgets = [
    for (final widget in from.widgetTokens)
      if (_widgetAnchorKey(widget.span) == null) widget,
  ];
  final toWidgets = [
    for (final widget in to.widgetTokens)
      if (_widgetAnchorKey(widget.span) == null) widget,
  ];
  final count = math.min(fromWidgets.length, toWidgets.length);
  return [
    for (var i = 0; i < count; i++)
      _MatchedWidgetAnchor(
        fromIndex: fromWidgets[i].index,
        toIndex: toWidgets[i].index,
      ),
  ];
}

_ReelTextWidgetToken? _takeFirst(List<_ReelTextWidgetToken>? widgets) {
  if (widgets == null || widgets.isEmpty) {
    return null;
  }
  return widgets.removeAt(0);
}

int _compareWidgetAnchors(_MatchedWidgetAnchor a, _MatchedWidgetAnchor b) {
  final byFrom = a.fromIndex.compareTo(b.fromIndex);
  if (byFrom != 0) {
    return byFrom;
  }
  return a.toIndex.compareTo(b.toIndex);
}
