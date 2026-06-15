import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:reel_text/reel_text.dart';
import 'package:url_launcher/url_launcher.dart';

import 'editor_page.dart';
import 'home_page.dart';
import 'recipes_page.dart';
import 'studio.dart';

const double _kShellMaxWidth = 1280;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.instrumentSans(fontWeight: FontWeight.w700);
  GoogleFonts.instrumentSans(fontWeight: FontWeight.w800);
  GoogleFonts.jetBrainsMono();
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600);
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700);
  await GoogleFonts.pendingFonts();

  runApp(const ReelTextExampleApp());
}

class ReelTextExampleApp extends StatefulWidget {
  const ReelTextExampleApp({
    super.key,
    this.useGoogleFonts = true,
    this.autoPlayHero = true,
  });

  /// Set to false in widget tests to avoid runtime font fetching.
  final bool useGoogleFonts;

  /// Set to false in widget tests so the hero stage does not auto-advance.
  final bool autoPlayHero;

  @override
  State<ReelTextExampleApp> createState() => _ReelTextExampleAppState();
}

class _ReelTextExampleAppState extends State<ReelTextExampleApp>
    with WidgetsBindingObserver {
  Brightness? _brightnessOverride;

  Brightness get _brightness =>
      _brightnessOverride ??
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_brightnessOverride == null && mounted) {
      setState(() {});
    }
  }

  void _setBrightness(Brightness brightness) {
    setState(() => _brightnessOverride = brightness);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness;
    Studio.fontsEnabled = widget.useGoogleFonts;
    Studio.brightness = brightness;
    final scheme = Studio.scheme;
    return MaterialApp(
      title: 'reel_text studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Studio.background,
        sliderTheme: SliderThemeData(
          activeTrackColor: Studio.focus,
          thumbColor: Studio.focus,
          inactiveTrackColor: Studio.border,
          overlayColor: Studio.focus.withValues(alpha: 0.10),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStatePropertyAll(Studio.onAccent(Studio.primary)),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Studio.primary
                : Studio.border,
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            side: WidgetStatePropertyAll(BorderSide(color: Studio.border)),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Studio.onAccent(Studio.primary)
                  : Studio.muted,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Studio.primary
                  : Studio.transparent,
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: Studio.muted),
        ),
      ),
      home: StudioShell(
        autoPlayHero: widget.autoPlayHero,
        loadLiveMetadata: widget.useGoogleFonts,
        brightness: brightness,
        onBrightnessChanged: _setBrightness,
      ),
    );
  }
}

class StudioShell extends StatefulWidget {
  const StudioShell({
    super.key,
    this.autoPlayHero = true,
    this.loadLiveMetadata = true,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final bool autoPlayHero;
  final bool loadLiveMetadata;
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TickerMode(
        enabled: _page == 0,
        child: HomePage(autoPlay: widget.autoPlayHero, active: _page == 0),
      ),
      TickerMode(enabled: _page == 1, child: const RecipesPage()),
      TickerMode(enabled: _page == 2, child: const EditorPage()),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              onPageChanged: (p) => setState(() => _page = p),
              loadLiveMetadata: widget.loadLiveMetadata,
              brightness: widget.brightness,
              onBrightnessChanged: widget.onBrightnessChanged,
            ),
            Divider(height: 1, color: Studio.border),
            Expanded(
              child: SizedBox.expand(
                key: const ValueKey('shell_body_frame'),
                child: KeyedSubtree(
                  key: ValueKey('shell_theme_body_${widget.brightness.name}'),
                  child: IndexedStack(index: _page, children: pages),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.page,
    required this.onPageChanged,
    required this.loadLiveMetadata,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final int page;
  final ValueChanged<int> onPageChanged;
  final bool loadLiveMetadata;
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late Future<_PackageStats> _stats;
  Timer? _statsRefreshTimer;

  static const _pageNames = ['HOME', 'RECIPES', 'EDITOR'];
  static const _statsRefreshInterval = Duration(seconds: 125);

  static final _pubDevUri = Uri.parse('https://pub.dev/packages/reel_text');
  static final _githubUri = Uri.parse('https://github.com/KickNext/reel_text');
  static final _pubDevScoreUri = Uri.parse(
    'https://pub.dev/api/packages/reel_text/score',
  );
  static final _githubApiUri = Uri.parse(
    'https://api.github.com/repos/KickNext/reel_text',
  );

  @override
  void initState() {
    super.initState();
    _configureStatsLoader();
  }

  @override
  void didUpdateWidget(covariant _TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLiveMetadata != widget.loadLiveMetadata) {
      _configureStatsLoader();
    }
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    super.dispose();
  }

  void _configureStatsLoader() {
    _statsRefreshTimer?.cancel();
    if (!widget.loadLiveMetadata) {
      _stats = Future.value(const _PackageStats(githubStars: 0, pubLikes: 0));
      return;
    }

    _stats = _loadPackageStats();
    _statsRefreshTimer = Timer.periodic(
      _statsRefreshInterval,
      (_) => _refreshStats(),
    );
  }

  void _refreshStats() {
    if (!mounted || !widget.loadLiveMetadata) {
      return;
    }
    setState(() {
      _stats = _loadPackageStats();
    });
  }

  static Future<_PackageStats> _loadPackageStats() async {
    final values = await Future.wait([
      _loadGithubStars(),
      _loadPubLikes(),
    ]).timeout(const Duration(seconds: 6));
    return _PackageStats(githubStars: values[0], pubLikes: values[1]);
  }

  static Future<int?> _loadGithubStars() async {
    try {
      final response = await http.get(
        _githubApiUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'reel_text_example',
        },
      );
      if (response.statusCode != 200) {
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return json['stargazers_count'] as int?;
    } on Object {
      return null;
    }
  }

  static Future<int?> _loadPubLikes() async {
    try {
      final response = await http.get(_pubDevScoreUri);
      if (response.statusCode != 200) {
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return json['likeCount'] as int?;
    } on Object {
      return null;
    }
  }

  static Future<void> _open(Uri uri) async {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final brand = Text(
          'reel_text',
          key: const ValueKey('app_bar_title'),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Studio.mono(
            size: compact ? 16 : 18,
            color: Studio.text,
            weight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        );
        final tabs = _PageTabs(
          pageNames: _pageNames,
          selected: widget.page,
          onPageChanged: widget.onPageChanged,
          compact: compact,
        );
        final links = FutureBuilder<_PackageStats>(
          future: _stats,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            return _MetadataLinks(
              compact: compact,
              githubStars: stats?.githubStars,
              pubLikes: stats?.pubLikes,
              onOpenPubDev: () => _open(_pubDevUri),
              onOpenGitHub: () => _open(_githubUri),
            );
          },
        );
        final toggle = _ThemeToggleButton(
          brightness: widget.brightness,
          onChanged: widget.onBrightnessChanged,
          compact: compact,
        );
        final actions = Row(
          key: const ValueKey('app_bar_actions'),
          mainAxisSize: MainAxisSize.min,
          children: [
            toggle,
            SizedBox(width: compact ? 6 : 8),
            links,
          ],
        );
        return Center(
          child: ConstrainedBox(
            key: const ValueKey('shell_top_bar_frame'),
            constraints: const BoxConstraints(maxWidth: _kShellMaxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20,
                vertical: compact ? 10 : 14,
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: brand,
                              ),
                            ),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        ),
                        const SizedBox(height: 10),
                        tabs,
                      ],
                    )
                  : SizedBox(
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: brand),
                          Center(child: tabs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({
    required this.brightness,
    required this.onChanged,
    required this.compact,
  });

  final Brightness brightness;
  final ValueChanged<Brightness> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLight = brightness == Brightness.light;
    return Tooltip(
      message: isLight ? 'Switch to dark theme' : 'Switch to light theme',
      child: Material(
        color: Studio.inset,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const ValueKey('theme_toggle_button'),
          onTap: () => onChanged(isLight ? Brightness.dark : Brightness.light),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: compact ? 36 : 38,
            width: compact ? 38 : 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Studio.borderBright.withValues(alpha: 0.56),
              ),
            ),
            child: Icon(
              isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: compact ? 16 : 17,
              color: Studio.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageStats {
  const _PackageStats({required this.githubStars, required this.pubLikes});

  final int? githubStars;
  final int? pubLikes;
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({
    required this.pageNames,
    required this.selected,
    required this.onPageChanged,
    required this.compact,
  });

  final List<String> pageNames;
  final int selected;
  final ValueChanged<int> onPageChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.inset.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Studio.borderBright.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < pageNames.length; i++)
              if (compact)
                Expanded(
                  child: _PageTab(
                    key: ValueKey('page_tab_${pageNames[i].toLowerCase()}'),
                    label: pageNames[i],
                    selected: i == selected,
                    onTap: () => onPageChanged(i),
                  ),
                )
              else
                _PageTab(
                  key: ValueKey('page_tab_${pageNames[i].toLowerCase()}'),
                  label: pageNames[i],
                  selected: i == selected,
                  onTap: () => onPageChanged(i),
                ),
          ],
        ),
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab({
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? Studio.text.withValues(alpha: 0.94)
                : Studio.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Studio.white.withValues(alpha: 0.18)
                  : Studio.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Studio.mono(
                size: 10.5,
                color: selected ? Studio.onAccent(Studio.text) : Studio.muted,
                weight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataLinks extends StatelessWidget {
  const _MetadataLinks({
    required this.compact,
    required this.githubStars,
    required this.pubLikes,
    required this.onOpenPubDev,
    required this.onOpenGitHub,
  });

  final bool compact;
  final int? githubStars;
  final int? pubLikes;
  final VoidCallback onOpenPubDev;
  final VoidCallback onOpenGitHub;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('app_bar_metadata_links'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricLinkButton(
          buttonKey: const ValueKey('pubdev_link_button'),
          iconKey: const ValueKey('pubdev_svg_icon'),
          metricKey: const ValueKey('pubdev_like_count'),
          tooltip: 'Open pub.dev',
          assetName: 'assets/icons/pubdev.svg',
          value: pubLikes,
          label: 'likes',
          compact: compact,
          colorize: false,
          onPressed: onOpenPubDev,
        ),
        const SizedBox(width: 8),
        _MetricLinkButton(
          buttonKey: const ValueKey('github_link_button'),
          iconKey: const ValueKey('github_svg_icon'),
          metricKey: const ValueKey('github_star_count'),
          tooltip: 'Open GitHub',
          assetName: 'assets/icons/github.svg',
          value: githubStars,
          label: 'stars',
          compact: compact,
          onPressed: onOpenGitHub,
        ),
      ],
    );
  }
}

class _MetricLinkButton extends StatelessWidget {
  const _MetricLinkButton({
    required this.buttonKey,
    required this.iconKey,
    required this.metricKey,
    required this.tooltip,
    required this.assetName,
    required this.onPressed,
    required this.value,
    required this.label,
    required this.compact,
    this.colorize = true,
  });

  final Key buttonKey;
  final Key iconKey;
  final Key metricKey;
  final String tooltip;
  final String assetName;
  final VoidCallback onPressed;
  final int? value;
  final String label;
  final bool compact;
  final bool colorize;

  @override
  Widget build(BuildContext context) {
    final count = _formatCount(value);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: '$tooltip, $count $label',
        child: Material(
          color: Studio.inset,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            key: buttonKey,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              padding: EdgeInsets.only(left: 11, right: compact ? 11 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Studio.borderBright.withValues(alpha: 0.56),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    assetName,
                    key: iconKey,
                    width: 17,
                    height: 17,
                    colorFilter: colorize
                        ? ColorFilter.mode(Studio.text, BlendMode.srcIn)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  ReelText(
                    count,
                    key: metricKey,
                    options: ReelTextOptions(
                      direction: ReelTextDirection.up,
                      duration: const Duration(milliseconds: 260),
                      stagger: const Duration(milliseconds: 18),
                      color: Studio.primary,
                    ),
                    style: Studio.mono(
                      size: 11,
                      color: Studio.text,
                      weight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: Studio.mono(
                        size: 10,
                        color: Studio.faint,
                        weight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCount(int? value) {
  if (value == null) {
    return '...';
  }
  if (value < 1000) {
    return '$value';
  }
  if (value < 1000000) {
    final scaled = value / 1000;
    return scaled < 10 ? '${scaled.toStringAsFixed(1)}k' : '${scaled.round()}k';
  }
  final scaled = value / 1000000;
  return scaled < 10 ? '${scaled.toStringAsFixed(1)}m' : '${scaled.round()}m';
}
