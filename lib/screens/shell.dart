import 'package:flutter/material.dart';
import '../core/backend.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'match.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final be = DemoBackend.instance;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(onChanged: _refresh),
      GamesTab(onChanged: _refresh),
      const LeaderboardTab(),
      WalletTab(onChanged: _refresh),
      const ProfileTab(),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: C.primary.withValues(alpha: .18),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            child: NavigationBar(
              height: 64,
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Games'),
                NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Leaderboard'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const kEntries = [10, 20, 50, 100, 200, 500];

Future<void> openMatch(BuildContext context, int entry, VoidCallback after) async {
  final be = DemoBackend.instance;
  if (entry > be.demoBalance) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: C.danger,
        content: Text('Not enough demo coins — you need ${fmtCoins(entry)}.'),
      ),
    );
    return;
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => MatchFlow(entry: entry)));
  after();
}

/* ============================== HOME ================================== */
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final be = DemoBackend.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: C.cardGrad, shape: BoxShape.circle,
                border: Border.all(color: C.line),
              ),
              child: Center(child: Text(be.user.avatar, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back', style: TextStyle(color: C.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  Text(be.user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ],
              ),
            ),
            _bell(context, be),
          ],
        ),
        const SizedBox(height: 18),
        Panel(
          gradient: const LinearGradient(
            colors: [Color(0xFF241C52), Color(0xFF14233F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Demo balance', style: TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Text(fmtCoins(be.demoBalance),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1)),
                ],
              ),
              const SizedBox(height: 10),
              const DemoBadge(),
            ],
          ),
        ),
        if (be.canClaimDaily) ...[
          const SizedBox(height: 12),
          Panel(
            border: C.gold.withValues(alpha: .45),
            gradient: LinearGradient(colors: [C.gold.withValues(alpha: .13), C.surface]),
            onTap: () {
              final amt = be.claimDaily();
              onChanged();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: C.accent,
                content: Text('Daily reward claimed — +${fmtCoins(amt)} demo coins'),
              ));
            },
            child: Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${be.dailyStreak + 1} reward ready',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text('Tap to claim ${fmtCoins(be.nextDailyReward)} demo coins',
                          style: const TextStyle(color: C.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: C.gold),
              ],
            ),
          ),
        ],
        const SectionTitle('Play now'),
        const Text('Pick an entry. We match you with another player on the same entry.',
            style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: .97,
          children: [
            for (final e in kEntries) _entryCard(context, e, onChanged),
          ],
        ),
        const SectionTitle('Recent games'),
        if (be.history.isEmpty)
          const EmptyState(icon: '🎮', title: 'No games yet', body: 'Your matches will appear here.')
        else
          ...be.history.take(3).map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GameRow(g: g),
              )),
        const SectionTitle('Game rules'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Rule('5 questions, 10 seconds each.'),
              _Rule('Correct answers score points — faster answers score more.'),
              _Rule('Highest score wins both entries.'),
              _Rule('A draw returns both entries in full.'),
              _Rule('Scores and the winner are decided on the server.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bell(BuildContext context, DemoBackend be) => GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: C.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          builder: (_) => const NotificationsSheet(),
        ).then((_) => onChanged()),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: C.surface2, borderRadius: BorderRadius.circular(13),
                border: Border.all(color: C.line),
              ),
              child: const Icon(Icons.notifications_none, size: 21),
            ),
            if (be.unreadCount > 0)
              Positioned(
                right: -3, top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: C.danger, borderRadius: BorderRadius.circular(20)),
                  child: Text('${be.unreadCount}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      );

  Widget _entryCard(BuildContext context, int e, VoidCallback after) {
    final be = DemoBackend.instance;
    final afford = be.demoBalance >= e;
    return Opacity(
      opacity: afford ? 1 : .45,
      child: Panel(
        padding: const EdgeInsets.all(11),
        border: afford ? C.primary.withValues(alpha: .35) : C.line,
        onTap: () => openMatch(context, e, after),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 21)),
            const SizedBox(height: 6),
            Text(fmtCoins(e),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 2),
            const Text('DEMO', style: TextStyle(fontSize: 8.5, color: C.muted, fontWeight: FontWeight.w800, letterSpacing: .5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: afford ? C.playGrad : null,
                color: afford ? null : C.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('PLAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5, right: 9),
              child: Icon(Icons.circle, size: 5, color: C.accent),
            ),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.4))),
          ],
        ),
      );
}

/* ============================== GAMES ================================= */
class GamesTab extends StatelessWidget {
  const GamesTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final be = DemoBackend.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Games', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Panel(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1E5C), Color(0xFF14233F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Quiz Duel', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        Text('1 v 1 · 5 questions · 10s each',
                            style: TextStyle(color: C.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: C.accent, letterSpacing: .6)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Choose your entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9, runSpacing: 9,
                children: [
                  for (final e in kEntries)
                    GestureDetector(
                      onTap: () => openMatch(context, e, onChanged),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: be.demoBalance >= e ? C.surface2 : C.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: be.demoBalance >= e ? C.primary.withValues(alpha: .5) : C.line),
                        ),
                        child: Text('🪙 ${fmtCoins(e)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Coming soon'),
        for (final g in const [
          ('🧠', 'Memory Match', 'Pattern recall duel'),
          ('🔢', 'Number Rush', 'Fast mental maths'),
          ('🔤', 'Word Sprint', 'Build words against the clock'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(g.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        Text(g.$3, style: const TextStyle(color: C.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(100)),
                    child: const Text('SOON',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: C.muted, letterSpacing: .5)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/* =========================== LEADERBOARD ============================== */
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});
  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  String _period = 'Daily';

  @override
  Widget build(BuildContext context) {
    final rows = DemoBackend.instance.leaderboard(_period);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Leaderboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Ranked on points scored, calculated from match data.',
            style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(13)),
          child: Row(
            children: [
              for (final p in ['Daily', 'Weekly', 'All-Time'])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _period = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _period == p ? C.playGrad : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(p,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: _period == p ? Colors.white : C.muted)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              border: r.isYou ? C.accent.withValues(alpha: .6) : C.line,
              gradient: r.isYou
                  ? LinearGradient(colors: [C.accent.withValues(alpha: .12), C.surface])
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      r.rank <= 3 ? ['🥇', '🥈', '🥉'][r.rank - 1] : '${r.rank}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: r.rank <= 3 ? 17 : 14,
                          color: C.muted),
                    ),
                  ),
                  Text(r.avatar, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.isYou ? '${r.name} (you)' : r.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: r.isYou ? C.accent : C.text)),
                        Text('${r.played} played · ${r.wins} wins · ${r.winRate}%',
                            style: const TextStyle(color: C.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Text(fmtCoins(r.points),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/* ============================== WALLET ================================ */
class WalletTab extends StatefulWidget {
  const WalletTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  String _filter = 'All';
  static const _filters = ['All', 'Game entry', 'Winning', 'Bonus', 'Refund'];

  bool _match(WalletTx t) => switch (_filter) {
        'Game entry' => t.type == TxType.gameEntry,
        'Winning' => t.type == TxType.gameWin,
        'Bonus' => t.type == TxType.bonus || t.type == TxType.demoCredit,
        'Refund' => t.type == TxType.refund,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final be = DemoBackend.instance;
    final rows = be.ledger.where(_match).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Panel(
          gradient: const LinearGradient(
            colors: [Color(0xFF241C52), Color(0xFF14233F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          child: Column(
            children: [
              const Text('Total demo balance',
                  style: TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('🪙 ${fmtCoins(be.demoBalance)}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 12),
              const DemoBadge(center: true),
              const Divider(color: C.line, height: 26),
              Row(
                children: [
                  Expanded(child: _bal('Demo', be.demoBalance, C.gold)),
                  Container(width: 1, height: 34, color: C.line),
                  Expanded(child: _bal('Reward', be.rewardBalance, C.accent)),
                  Container(width: 1, height: 34, color: C.line),
                  Expanded(child: _bal('Bonus', be.bonusBalance, C.primary)),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Transaction history'),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final on = f == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: on ? C.playGrad : null,
                    color: on ? null : C.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: on ? Colors.transparent : C.line),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : C.muted)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyState(icon: '🧾', title: 'Nothing here', body: 'No transactions match this filter.')
        else
          ...rows.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _txRow(t),
              )),
      ],
    );
  }

  Widget _bal(String label, int v, Color c) => Column(
        children: [
          Text(label, style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(fmtCoins(v), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c)),
        ],
      );

  Widget _txRow(WalletTx t) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: (t.isCredit ? C.accent : C.danger).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    t.isCredit ? Icons.south_west : Icons.north_east,
                    size: 17,
                    color: t.isCredit ? C.accent : C.danger,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.type.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text(t.description,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: C.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                Text(
                  '${t.amount >= 0 ? '+' : ''}${fmtCoins(t.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      color: t.amount > 0 ? C.accent : (t.amount < 0 ? C.danger : C.muted)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(9)),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${t.id} · ${_ago(t.at)}',
                        style: const TextStyle(fontSize: 10.5, color: C.muted, fontWeight: FontWeight.w600)),
                  ),
                  Text('${fmtCoins(t.balanceBefore)} → ${fmtCoins(t.balanceAfter)}',
                      style: const TextStyle(fontSize: 10.5, color: C.muted, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
}

/* ============================== PROFILE =============================== */
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final be = DemoBackend.instance;
    final wins = be.history.where((g) => g.outcome == GameOutcome.win).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: C.playGrad, shape: BoxShape.circle,
                ),
                child: Center(child: Text(be.user.avatar, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(height: 11),
              Text(be.user.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('ACTIVE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: C.accent, letterSpacing: .5)),
                  ),
                  const SizedBox(width: 6),
                  if (be.user.verified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: C.primary.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text('VERIFIED',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: C.primary, letterSpacing: .5)),
                    ),
                ],
              ),
              const Divider(color: C.line, height: 26),
              Row(
                children: [
                  Expanded(child: _stat('${be.history.length}', 'Played')),
                  Container(width: 1, height: 32, color: C.line),
                  Expanded(child: _stat('$wins', 'Wins')),
                  Container(width: 1, height: 32, color: C.line),
                  Expanded(child: _stat(
                      be.history.isEmpty ? '0%' : '${(wins / be.history.length * 100).round()}%', 'Win rate')),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Account'),
        Panel(
          child: Column(
            children: [
              _row('User ID', be.user.id),
              _row('Mobile', '+91 ${be.user.mobile}'),
              _row('Email', be.user.email),
              _row('Date of birth', be.user.dob),
              _row('Joined', _date(be.user.joinedAt)),
              _row('Last login', _ago(be.user.lastLogin), last: true),
            ],
          ),
        ),
        const SectionTitle('Refer & earn'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your referral code',
                  style: TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.primary.withValues(alpha: .4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(be.user.referralCode,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.4)),
                    ),
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: C.accent, content: Text('Referral code copied')),
                      ),
                      child: const Icon(Icons.copy_rounded, size: 19, color: C.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: _stat('${be.referredUsers}', 'Invited')),
                  Container(width: 1, height: 30, color: C.line),
                  Expanded(child: _stat('${be.successfulReferrals}', 'Joined')),
                  Container(width: 1, height: 30, color: C.line),
                  Expanded(child: _stat(fmtCoins(be.referralEarnings), 'Earned')),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Game history'),
        if (be.history.isEmpty)
          const EmptyState(icon: '🎮', title: 'No games yet', body: 'Play a match to build your history.')
        else
          ...be.history.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GameRow(g: g),
              )),
        const SizedBox(height: 18),
        Panel(
          border: C.danger.withValues(alpha: .35),
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Center(
            child: Text('Sign out',
                style: TextStyle(color: C.danger, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          Text(l, style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _row(String k, String v, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            Flexible(
              child: Text(v, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
}

/* ============================== SHARED ================================ */
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.g});
  final GameResult g;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (g.outcome) {
      GameOutcome.win => ('WON', C.accent),
      GameOutcome.loss => ('LOST', C.danger),
      GameOutcome.draw => ('DRAW', C.gold),
    };
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: C.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (_) => _GameDetail(g: g),
      ),
      child: Row(
        children: [
          Text(g.opponentAvatar, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs ${g.opponentName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text('${g.yourScore}–${g.opponentScore} · ${_ago(g.playedAt)}',
                    style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(label,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: colour, letterSpacing: .5)),
              ),
              const SizedBox(height: 3),
              Text(
                g.reward > 0 ? '+${fmtCoins(g.reward - g.entry)}' : '-${fmtCoins(g.entry)}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: g.reward > g.entry ? C.accent : (g.reward == g.entry ? C.muted : C.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameDetail extends StatelessWidget {
  const _GameDetail({required this.g});
  final GameResult g;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),
          Text('Game ${g.gameId}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 3),
          Text(_date(g.playedAt), style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 16),
          _d('Opponent', '${g.opponentAvatar}  ${g.opponentName}'),
          _d('Final score', '${g.yourScore} – ${g.opponentScore}'),
          _d('Entry', '${fmtCoins(g.entry)} demo coins'),
          _d('Reward', g.reward > 0 ? '+${fmtCoins(g.reward)}' : '0'),
          _d('Result', switch (g.outcome) {
            GameOutcome.win => 'Won',
            GameOutcome.loss => 'Lost',
            GameOutcome.draw => 'Draw — entry refunded',
          }),
          if (g.answers.isNotEmpty) ...[
            const Divider(color: C.line, height: 26),
            const Text('Question audit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 10),
            for (var i = 0; i < g.answers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(g.answers[i].correct ? Icons.check_circle : Icons.cancel,
                        size: 15, color: g.answers[i].correct ? C.accent : C.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Q${i + 1} · ${(g.answers[i].msTaken / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ),
                    Text('+${g.answers[i].points}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _d(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: C.muted, fontSize: 13)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});
  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  @override
  Widget build(BuildContext context) {
    final be = DemoBackend.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  for (final n in be.notifications) {
                    n.read = true;
                  }
                }),
                child: const Text('Mark all read',
                    style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final n in be.notifications)
                  GestureDetector(
                    onTap: () => setState(() => n.read = true),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: n.read ? C.surface2 : C.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: n.read ? C.line : C.primary.withValues(alpha: .4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.icon, style: const TextStyle(fontSize: 19)),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text(n.body, style: const TextStyle(color: C.muted, fontSize: 12, height: 1.35)),
                                const SizedBox(height: 4),
                                Text(_ago(n.at), style: const TextStyle(color: C.muted, fontSize: 10.5)),
                              ],
                            ),
                          ),
                          if (!n.read)
                            Container(width: 7, height: 7,
                                decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime d) {
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return 'just now';
  if (s < 3600) return '${s ~/ 60}m ago';
  if (s < 86400) return '${s ~/ 3600}h ago';
  final days = s ~/ 86400;
  if (days == 1) return 'yesterday';
  if (days < 30) return '${days}d ago';
  return _date(d);
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
