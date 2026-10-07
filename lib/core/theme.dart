import 'package:flutter/material.dart';

/// Dark premium gaming palette — deliberately not the default Material look.
class C {
  static const bg = Color(0xFF0B0E1A);
  static const surface = Color(0xFF141A2E);
  static const surface2 = Color(0xFF1C2440);
  static const line = Color(0xFF263052);
  static const primary = Color(0xFF6C5CE7);
  static const primaryDim = Color(0xFF4F42B5);
  static const accent = Color(0xFF00D9A6);
  static const gold = Color(0xFFFFC53D);
  static const danger = Color(0xFFFF5A6E);
  static const text = Color(0xFFF2F5FF);
  static const muted = Color(0xFF8A95B8);

  static const coinGrad = LinearGradient(
    colors: [Color(0xFFFFC53D), Color(0xFFFF9A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const playGrad = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00D9A6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const cardGrad = LinearGradient(
    colors: [Color(0xFF1C2440), Color(0xFF151B31)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: C.primary,
      secondary: C.accent,
      surface: C.surface,
      error: C.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: C.text,
      displayColor: C.text,
      fontFamily: 'Roboto',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Rounded card used everywhere — subtle gradient and a 1px border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.border,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? border;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? C.cardGrad,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? C.line),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// The coin pill. "Demo" is always on screen so the coins can never be
/// mistaken for money.
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.amount, this.compact = false});
  final int amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 9),
      decoration: BoxDecoration(
        color: C.gold.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: C.gold.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            _fmt(amount),
            style: TextStyle(
              color: C.gold,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 13 : 15,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            const Text('DEMO',
                style: TextStyle(color: C.muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
          ],
        ],
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String fmtCoins(int n) => _fmt(n);

/// The legally important label, shown wherever a balance is prominent.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.center = false});
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: const [
        Icon(Icons.info_outline, size: 12, color: C.muted),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Demo Coins — No Real Monetary Value',
            style: TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gradient,
    this.height = 54,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: gradient ?? C.playGrad,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [BoxShadow(color: C.primary.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final String icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13.5)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
