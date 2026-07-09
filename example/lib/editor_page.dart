import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reel_text/reel_text.dart';

import 'studio.dart';

enum _MotionDirection { up, down }

enum _MotionTone { primary, sky, violet, rose, amber, chroma }

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static const _targets = [
    'Cart updated',
    'Payment sent',
    'Invite copied',
    'Export ready',
  ];

  late final ReelTextEditingController _target;
  late final ReelTextController _preview;
  String? _selectedTarget = _targets.first;

  _MotionDirection _direction = _MotionDirection.up;
  _MotionTone _tone = _MotionTone.primary;
  var _duration = 340.0;
  var _stagger = 34.0;
  var _exitOffset = 48.0;
  var _bounce = 0.32;
  var _skipUnchanged = true;
  var _interrupt = true;

  @override
  void initState() {
    super.initState();
    _target = ReelTextEditingController(text: _targets.first);
    _target.addListener(_handleTargetChanged);
    _preview = ReelTextController(initialText: 'Ready');
  }

  @override
  void dispose() {
    _target.removeListener(_handleTargetChanged);
    _target.dispose();
    _preview.dispose();
    super.dispose();
  }

  void _handleTargetChanged() {
    if (mounted) {
      if (!_target.hasActiveReplacements) {
        _selectedTarget = _targets.contains(_target.text) ? _target.text : null;
      }
      setState(() {});
    }
  }

  ReelTextOptions get _options {
    final toneColor = _toneColor(_tone);
    return ReelTextOptions(
      direction: _direction == _MotionDirection.up
          ? ReelTextDirection.up
          : ReelTextDirection.down,
      duration: Duration(milliseconds: _duration.round()),
      stagger: Duration(milliseconds: _stagger.round()),
      exitOffset: Duration(milliseconds: _exitOffset.round()),
      bounce: _bounce,
      color: toneColor,
      colorBuilder: _tone == _MotionTone.chroma ? Studio.chromaColor : null,
      skipUnchanged: _skipUnchanged,
      interrupt: _interrupt,
    );
  }

  void _apply([String? text]) {
    final next = (text ?? _targetDraftText).trim();
    if (next.isEmpty) {
      return;
    }
    final options = _options;
    if (_target.hasActiveReplacements) {
      _target.commitReplacements(
        selection: TextSelection.collapsed(offset: next.length),
      );
    } else {
      _selectTarget(next);
    }
    _preview.set(next, options: options);
  }

  void _selectTarget(String text) {
    final next = text.trim();
    if (next.isEmpty || next == _target.text) {
      if (_targets.contains(next)) {
        setState(() => _selectedTarget = next);
      }
      return;
    }
    setState(() {
      _selectedTarget = _targets.contains(next) ? next : null;
    });
    final options = _options;
    _target.animateReplacements(
      replacements: [
        ReelTextEditReplacement(
          range: TextRange(start: 0, end: _target.text.length),
          replacement: next,
          key: const ValueKey('editor_target_replacement'),
          options: options,
          style: Studio.mono(
            size: 13,
            color: Studio.text,
            height: 1,
            weight: FontWeight.w700,
          ),
        ),
      ],
      commitAfter: _replacementCommitDelay(_target.text, next, options),
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Duration _replacementCommitDelay(
    String from,
    String to,
    ReelTextOptions options,
  ) {
    final glyphCount = math.max(from.runes.length, to.runes.length);
    final staggerMs =
        math.max(0, glyphCount - 1) * options.stagger.inMilliseconds;
    final rollMs =
        (options.duration.inMilliseconds * (1 + options.bounce * 0.45)).round();
    final fadeMs = options.color != null || options.colorBuilder != null
        ? options.colorFade.inMilliseconds
        : 0;
    final totalMs =
        staggerMs + options.exitOffset.inMilliseconds + rollMs + fadeMs + 120;
    return Duration(milliseconds: totalMs.clamp(520, 2600).toInt());
  }

  String get _targetDraftText {
    return _target.hasActiveReplacements
        ? _target.replacementText()
        : _target.text;
  }

  void _reset() {
    setState(() {
      _direction = _MotionDirection.up;
      _tone = _MotionTone.primary;
      _duration = 340;
      _stagger = 34;
      _exitOffset = 48;
      _bounce = 0.32;
      _skipUnchanged = true;
      _interrupt = true;
    });
    _apply(_targets.first);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final horizontal = compact ? 16.0 : 40.0;
    final controls = _controlsPanel();
    final preview = _PreviewPanel(
      preview: _preview,
      compact: compact,
      options: _options,
    );

    if (compact) {
      return Padding(
        key: const ValueKey('editor_mobile_shell'),
        padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: const ValueKey('editor_content_frame'),
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EditorHeader(),
                const SizedBox(height: 12),
                preview,
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    key: const ValueKey('editor_controls_scroll'),
                    padding: const EdgeInsets.only(bottom: 14),
                    children: [
                      controls,
                      const SizedBox(height: 20),
                      const StudioFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('editor_page_scroll'),
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 20),
      children: [
        Center(
          child: ConstrainedBox(
            key: const ValueKey('editor_content_frame'),
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EditorHeader(),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 12, child: preview),
                    const SizedBox(width: 16),
                    Expanded(flex: 9, child: controls),
                  ],
                ),
                const SizedBox(height: 28),
                const StudioFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _ControlsPanel _controlsPanel() {
    return _ControlsPanel(
      target: _target,
      selectedTarget: _selectedTarget,
      targets: _targets,
      direction: _direction,
      tone: _tone,
      duration: _duration,
      stagger: _stagger,
      exitOffset: _exitOffset,
      bounce: _bounce,
      skipUnchanged: _skipUnchanged,
      interrupt: _interrupt,
      onApply: _apply,
      onSelectTarget: _selectTarget,
      onReset: _reset,
      onDirectionChanged: (value) => setState(() => _direction = value),
      onToneChanged: (value) => setState(() => _tone = value),
      onDurationChanged: (value) => setState(() => _duration = value),
      onStaggerChanged: (value) => setState(() => _stagger = value),
      onExitOffsetChanged: (value) => setState(() => _exitOffset = value),
      onBounceChanged: (value) => setState(() => _bounce = value),
      onSkipUnchangedChanged: (value) => setState(() => _skipUnchanged = value),
      onInterruptChanged: (value) => setState(() => _interrupt = value),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioCaption('Editor', color: Studio.primary),
        const SizedBox(height: 8),
        Text(
          'Tune the motion.',
          style: Studio.display(size: compact ? 24 : 30, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.preview,
    required this.compact,
    required this.options,
  });

  final ReelTextController preview;
  final bool compact;
  final ReelTextOptions options;

  @override
  Widget build(BuildContext context) {
    final textSize = compact ? 36.0 : 74.0;
    final textSlotHeight = compact ? 58.0 : 112.0;
    return StudioPanel(
      key: const ValueKey('editor_preview_panel'),
      padding: EdgeInsets.all(compact ? 16 : 22),
      child: SizedBox(
        height: compact ? 148 : 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudioCaption('Preview', color: Studio.faint),
                if (!compact) ...[
                  const Spacer(),
                  _Metric(
                    label: 'duration',
                    value: '${options.duration.inMilliseconds}ms',
                  ),
                  const SizedBox(width: 8),
                  _Metric(
                    label: 'stagger',
                    value: '${options.stagger.inMilliseconds}ms',
                  ),
                ],
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  key: const ValueKey('editor_preview_text_slot'),
                  height: textSlotHeight,
                  width: double.infinity,
                  child: ClipRect(
                    child: Center(
                      child: ReelText.controller(
                        key: const ValueKey('editor_preview_text'),
                        controller: preview,
                        style: Studio.display(
                          size: textSize,
                          letterSpacing: 0,
                          height: 1,
                        ),
                        strutStyle: StrutStyle(
                          fontSize: textSize,
                          height: 1,
                          forceStrutHeight: true,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ReelText.controller',
                style: Studio.mono(
                  size: 11,
                  color: Studio.faint,
                  weight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.target,
    required this.selectedTarget,
    required this.targets,
    required this.direction,
    required this.tone,
    required this.duration,
    required this.stagger,
    required this.exitOffset,
    required this.bounce,
    required this.skipUnchanged,
    required this.interrupt,
    required this.onApply,
    required this.onSelectTarget,
    required this.onReset,
    required this.onDirectionChanged,
    required this.onToneChanged,
    required this.onDurationChanged,
    required this.onStaggerChanged,
    required this.onExitOffsetChanged,
    required this.onBounceChanged,
    required this.onSkipUnchangedChanged,
    required this.onInterruptChanged,
  });

  final ReelTextEditingController target;
  final String? selectedTarget;
  final List<String> targets;
  final _MotionDirection direction;
  final _MotionTone tone;
  final double duration;
  final double stagger;
  final double exitOffset;
  final double bounce;
  final bool skipUnchanged;
  final bool interrupt;
  final ValueChanged<String?> onApply;
  final ValueChanged<String> onSelectTarget;
  final VoidCallback onReset;
  final ValueChanged<_MotionDirection> onDirectionChanged;
  final ValueChanged<_MotionTone> onToneChanged;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<double> onStaggerChanged;
  final ValueChanged<double> onExitOffsetChanged;
  final ValueChanged<double> onBounceChanged;
  final ValueChanged<bool> onSkipUnchangedChanged;
  final ValueChanged<bool> onInterruptChanged;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      key: const ValueKey('editor_controls_panel'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioCaption('Motion', color: Studio.faint),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  key: const ValueKey('editor_target_input_frame'),
                  height: 48,
                  child: TextField(
                    key: const ValueKey('editor_target_input'),
                    controller: target,
                    cursorColor: Studio.focus,
                    onSubmitted: onApply,
                    maxLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    strutStyle: const StrutStyle(
                      fontSize: 13,
                      height: 1,
                      forceStrutHeight: true,
                    ),
                    style: Studio.mono(
                      size: 13,
                      color: Studio.text,
                      height: 1,
                      weight: FontWeight.w700,
                    ),
                    decoration: _fieldDecoration('Target'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: Semantics(
                  button: true,
                  label: 'Apply',
                  onTap: () => onApply(null),
                  child: ExcludeSemantics(
                    child: Center(
                      child: SizedBox(
                        height: 42,
                        child: FilledButton(
                          key: const ValueKey('editor_apply_button'),
                          onPressed: () => onApply(null),
                          style: FilledButton.styleFrom(
                            backgroundColor: Studio.primary,
                            foregroundColor: Studio.onAccent(Studio.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Apply',
                            style: Studio.mono(
                              size: 12,
                              color: Studio.onAccent(Studio.primary),
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in targets)
                _TargetChip(
                  key: ValueKey(
                    'editor_target_${value.toLowerCase().replaceAll(' ', '_')}',
                  ),
                  label: value,
                  selected: selectedTarget == value,
                  onTap: () => onSelectTarget(value),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _LabelRow(
            label: 'Direction',
            child: SegmentedButton<_MotionDirection>(
              key: const ValueKey('editor_direction_control'),
              showSelectedIcon: false,
              selected: {direction},
              segments: const [
                ButtonSegment(value: _MotionDirection.up, label: Text('Up')),
                ButtonSegment(
                  value: _MotionDirection.down,
                  label: Text('Down'),
                ),
              ],
              onSelectionChanged: (value) => onDirectionChanged(value.first),
            ),
          ),
          const SizedBox(height: 16),
          _ToneRow(selected: tone, onChanged: onToneChanged),
          const SizedBox(height: 18),
          _MotionSlider(
            label: 'Duration',
            value: duration,
            min: 180,
            max: 720,
            divisions: 18,
            display: '${duration.round()}ms',
            onChanged: onDurationChanged,
          ),
          _MotionSlider(
            label: 'Stagger',
            value: stagger,
            min: 0,
            max: 90,
            divisions: 18,
            display: '${stagger.round()}ms',
            onChanged: onStaggerChanged,
          ),
          _MotionSlider(
            label: 'Exit offset',
            value: exitOffset,
            min: 0,
            max: 140,
            divisions: 14,
            display: '${exitOffset.round()}ms',
            onChanged: onExitOffsetChanged,
          ),
          _MotionSlider(
            label: 'Bounce',
            value: bounce,
            min: 0,
            max: 1,
            divisions: 20,
            display: bounce.toStringAsFixed(2),
            onChanged: onBounceChanged,
          ),
          const SizedBox(height: 8),
          _SwitchRow(
            label: 'Keep matching glyphs',
            value: skipUnchanged,
            onChanged: onSkipUnchangedChanged,
          ),
          _SwitchRow(
            label: 'Interrupt running roll',
            value: interrupt,
            onChanged: onInterruptChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('editor_reset_button'),
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: Studio.muted,
                side: BorderSide(
                  color: Studio.borderBright.withValues(alpha: 0.7),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Reset',
                style: Studio.mono(
                  size: 12,
                  color: Studio.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.inset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Studio.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$label $value',
          style: Studio.mono(
            size: 10,
            color: Studio.faint,
            weight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? Studio.onAccent(Studio.primary)
            : Studio.muted,
        backgroundColor: selected ? Studio.primary : Studio.transparent,
        side: BorderSide(
          color: selected
              ? Studio.primary
              : Studio.borderBright.withValues(alpha: 0.55),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: Studio.mono(
          size: 11,
          color: selected ? Studio.onAccent(Studio.primary) : Studio.muted,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Studio.mono(
              size: 11,
              color: Studio.muted,
              weight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ToneRow extends StatelessWidget {
  const _ToneRow({required this.selected, required this.onChanged});

  final _MotionTone selected;
  final ValueChanged<_MotionTone> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabelRow(
      label: 'Color',
      child: Wrap(
        spacing: 8,
        children: [
          for (final tone in _MotionTone.values)
            _ToneSwatch(
              tone: tone,
              selected: selected == tone,
              onTap: () => onChanged(tone),
            ),
        ],
      ),
    );
  }
}

class _ToneSwatch extends StatelessWidget {
  const _ToneSwatch({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final _MotionTone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone) ?? Studio.primary;
    final chromaStops = Studio.chromaStops;
    return Tooltip(
      message: tone.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          key: ValueKey('editor_tone_${tone.name}'),
          duration: const Duration(milliseconds: 160),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Studio.text : Studio.borderBright,
              width: selected ? 2 : 1,
            ),
            gradient: tone == _MotionTone.chroma
                ? SweepGradient(colors: [...chromaStops, chromaStops.first])
                : null,
            color: tone == _MotionTone.chroma ? null : color,
          ),
        ),
      ),
    );
  }
}

class _MotionSlider extends StatelessWidget {
  const _MotionSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: Studio.mono(
                  size: 11,
                  color: Studio.muted,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                display,
                style: Studio.mono(
                  size: 11,
                  color: Studio.text,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Studio.mono(
                size: 11,
                color: Studio.muted,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    hintText: label,
    hintStyle: Studio.mono(size: 12, color: Studio.faint, height: 1),
    isDense: false,
    filled: true,
    fillColor: Studio.inset,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Studio.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Studio.focus),
    ),
  );
}

Color? _toneColor(_MotionTone tone) {
  return switch (tone) {
    _MotionTone.primary => Studio.primary,
    _MotionTone.sky => Studio.info,
    _MotionTone.violet => Studio.tone(Studio.violet),
    _MotionTone.rose => Studio.danger,
    _MotionTone.amber => Studio.warning,
    _MotionTone.chroma => null,
  };
}
