import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/pou_app_colors.dart';

/// Three-page onboarding shown before login.
///
/// Positions follow the 390×844 reference (full screen, including the status
/// bar). The photo, crop, indicators, title, and description slide together.
/// The two actions stay fixed.
class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _controller = PageController();
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncPage);
  }

  void _syncPage() {
    final next = _controller.page?.round();
    if (next == null || next == _page) return;
    setState(() => _page = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncPage);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final media = MediaQuery.of(context);
            final metrics = _OnboardingMetrics(width, height, media);
            final canvas = _OnboardingCanvas(
              metrics: metrics,
              page: _page,
              controller: _controller,
              onPageChanged: (index) {
                if (index == _page) return;
                setState(() => _page = index);
              },
              onLogin: widget.onLogin,
              onRegister: widget.onRegister,
            );

            if (!metrics.scrolls) return canvas;

            return ColoredBox(
              color: Colors.white,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: width,
                  height: metrics.layoutHeight,
                  child: canvas,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.asset,
    required this.alignment,
    required this.boxBottom,
    required this.edge,
    required this.lead,
    required this.accent,
    required this.body,
    required this.label,
  });

  final String asset;
  final Alignment alignment;

  /// Lowest point of the photo box, as a fraction of the reference height.
  final double boxBottom;

  /// Clip edge in screen fractions (x across the width, y down the height).
  final List<Offset> edge;
  final String lead;
  final String accent;
  final String body;
  final String label;
}

const _slides = <_Slide>[
  _Slide(
    asset: 'assets/images/onboarding-catalog.jpg',
    alignment: Alignment(0, 0.08),
    boxBottom: 0.632,
    edge: [
      Offset(0, 0.552),
      Offset(0.10, 0.572),
      Offset(0.24, 0.594),
      Offset(0.40, 0.612),
      Offset(0.55, 0.620),
      Offset(0.72, 0.610),
      Offset(0.88, 0.596),
      Offset(1, 0.584),
    ],
    lead: 'PRA\nORGANIZAR ',
    accent: 'SEUS PRODUTOS',
    body: 'Monte seu catálogo com fotos, preços e unidades de venda.',
    label: 'Catálogo',
  ),
  _Slide(
    asset: 'assets/images/onboarding-sales.jpg',
    alignment: Alignment(0, 0.12),
    boxBottom: 0.518,
    edge: [Offset(0, 0.498), Offset(0.38, 0.442), Offset(1, 0.358)],
    lead: 'PRA\nREGISTRAR ',
    accent: 'SUAS VENDAS',
    body: 'Registre vendas à vista ou a prazo e combine o vencimento com o cliente.',
    label: 'Vendas',
  ),
  _Slide(
    asset: 'assets/images/onboarding-receipts.jpg',
    alignment: Alignment(0, 0.18),
    boxBottom: 0.592,
    edge: [
      Offset(0, 0.576),
      Offset(0.28, 0.568),
      Offset(0.58, 0.552),
      Offset(0.82, 0.528),
      Offset(1, 0.506),
    ],
    lead: 'PRA\nSABER QUANTO\n',
    accent: 'FALTA RECEBER',
    body: 'Acompanhe pagamentos, vencimentos e atrasos em um só lugar.',
    label: 'Recebimentos',
  ),
];

const _orange = Color(0xFFF05A22);
const _indicatorIdle = Color(0xFFECECEC);
const _bodyGray = Color(0xFFA3A3A3);
const _buttonBorder = Color(0xFFD1D5DB);

class _OnboardingMetrics {
  _OnboardingMetrics(this.width, this.height, MediaQueryData media)
    : topInset = media.padding.top,
      bottomInset = media.padding.bottom,
      textScale = media.textScaler.scale(1);

  static const refWidth = 390.0;
  static const refHeight = 844.0;

  final double width;
  final double height;
  final double topInset;
  final double bottomInset;
  final double textScale;

  double get scale => width / refWidth;

  double get designHeight => refHeight * scale;

  /// Phone-shaped screens use the real height so a capture matches the mockup.
  bool get fillsScreen => (height - designHeight).abs() / designHeight < 0.12;

  bool get scrolls => !fillsScreen || height < designHeight * 0.9;

  double get layoutHeight => scrolls ? designHeight : height;

  double y(double fraction) => fraction * layoutHeight;

  double get contentLeft => 0.057 * width;

  double get buttonLeft => 0.068 * width;

  double get buttonGap => 0.058 * width;

  double get buttonHeight => 0.064 * layoutHeight;

  double get buttonTop {
    final designed = y(0.872);
    final aboveHome = layoutHeight - bottomInset - buttonHeight - 12 * scale;
    return designed < aboveHome ? designed : aboveHome;
  }

  double get titleTop => y(0.666);

  double get indicatorTop => y(0.570);
}

class _OnboardingCanvas extends StatelessWidget {
  const _OnboardingCanvas({
    required this.metrics,
    required this.page,
    required this.controller,
    required this.onPageChanged,
    required this.onLogin,
    required this.onRegister,
  });

  final _OnboardingMetrics metrics;
  final int page;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final titleSize = _titleSize(m);

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: _slides.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Semantics(
                label: slide.label,
                child: Stack(
                  children: [
                    _Photo(slide: slide, metrics: m),
                    Positioned(
                      top: m.titleTop,
                      left: m.contentLeft,
                      right: m.contentLeft,
                      bottom: m.layoutHeight - m.buttonTop + 8 * m.scale,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: _Copy(
                          slide: slide,
                          titleSize: titleSize,
                          scale: m.scale,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: m.indicatorTop,
            left: 0.052 * m.width,
            child: _Indicators(page: page, scale: m.scale),
          ),
          Positioned(
            top: m.buttonTop,
            left: m.buttonLeft,
            right: m.buttonLeft,
            height: m.buttonHeight,
            child: _Actions(
              height: m.buttonHeight,
              gap: m.buttonGap,
              scale: m.scale,
              onLogin: onLogin,
              onRegister: onRegister,
            ),
          ),
        ],
      ),
    );
  }

  double _titleSize(_OnboardingMetrics m) {
    final maxWidth = m.width - m.contentLeft * 2;
    const longest = 'ORGANIZAR SEUS PRODUTOS';
    var size = 40 * m.scale;
    final floor = 16 * m.scale;
    while (size > floor) {
      final painter = TextPainter(
        text: TextSpan(
          text: longest,
          style: TextStyle(
            fontFamily: 'Avenir Next Condensed',
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4 * m.scale,
            height: 1,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width <= maxWidth * 0.96) return size;
      size -= 0.5 * m.scale;
    }
    return floor;
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.slide, required this.metrics});

  final _Slide slide;
  final _OnboardingMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final top = metrics.topInset;
    final bottom = metrics.y(slide.boxBottom);
    final height = (bottom - top).clamp(1.0, metrics.layoutHeight);
    final points = [
      for (final point in slide.edge)
        Offset(
          point.dx,
          ((metrics.y(point.dy) - top) / height).clamp(0.0, 1.0),
        ),
    ];

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: ClipPath(
        clipper: _EdgeClipper(points),
        child: Image.asset(
          slide.asset,
          fit: BoxFit.cover,
          alignment: slide.alignment,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _EdgeClipper extends CustomClipper<Path> {
  const _EdgeClipper(this.points);

  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final pts = [
      for (final point in points)
        Offset(point.dx * size.width, point.dy * size.height),
    ];
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(pts.first.dx, pts.first.dy);

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    path
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _EdgeClipper oldDelegate) =>
      oldDelegate.points != points;
}

class _Indicators extends StatelessWidget {
  const _Indicators({required this.page, required this.scale});

  final int page;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _slides.length; i++) ...[
          if (i > 0) SizedBox(width: 8 * scale),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24 * scale,
            height: 4.5 * scale,
            decoration: BoxDecoration(
              color: i == page ? _orange : _indicatorIdle,
              borderRadius: BorderRadius.circular(3 * scale),
            ),
          ),
        ],
      ],
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({
    required this.slide,
    required this.titleSize,
    required this.scale,
  });

  final _Slide slide;
  final double titleSize;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final title = TextStyle(
      fontFamily: 'Avenir Next Condensed',
      color: Colors.black,
      fontSize: titleSize,
      fontWeight: FontWeight.w900,
      height: 0.96,
      letterSpacing: -0.4 * scale,
    );

    final lines = slide.lead.split('\n');
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Text.rich(
            TextSpan(
              style: title,
              children: [
                if (lines[i].isNotEmpty) TextSpan(text: lines[i]),
                if (i == lines.length - 1)
                  TextSpan(
                    text: slide.accent,
                    style: const TextStyle(color: _orange),
                  ),
              ],
            ),
          ),
      ],
    );
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (enlarged)
          titles
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: titles,
          ),
        SizedBox(height: 16 * scale),
        Text(
          slide.body,
          style: TextStyle(
            color: _bodyGray,
            fontSize: 15.5 * scale,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.height,
    required this.gap,
    required this.scale,
    required this.onLogin,
    required this.onRegister,
  });

  final double height;
  final double gap;
  final double scale;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12 * scale);
    final label = TextStyle(
      fontFamily: 'Avenir Next Condensed',
      fontSize: 15 * scale,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('welcome_order_now'),
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: pouBrand,
              backgroundColor: Colors.white,
              side: const BorderSide(color: _buttonBorder),
              shape: RoundedRectangleBorder(borderRadius: radius),
              minimumSize: Size.fromHeight(height),
              padding: EdgeInsets.zero,
              textStyle: label,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('JÁ TENHO CONTA', style: label),
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: FilledButton(
            key: const Key('onboarding_start'),
            onPressed: onRegister,
            style: FilledButton.styleFrom(
              backgroundColor: pouBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: radius),
              minimumSize: Size.fromHeight(height),
              padding: EdgeInsets.zero,
              textStyle: label,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('COMEÇAR', style: label),
            ),
          ),
        ),
      ],
    );
  }
}
