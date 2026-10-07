import 'dart:async';
import 'package:flutter/material.dart';
import '../core/backend.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Matchmaking → synchronised countdown → 5 questions → result.
/// Every score and the winner come from DemoBackend, never from this widget.
class MatchFlow extends StatefulWidget {
  const MatchFlow({super.key, required this.entry});
  final int entry;

  @override
  State<MatchFlow> createState() => _MatchFlowState();
}

enum _Stage { searching, found, countdown, playing, settling, result }

class _MatchFlowState extends State<MatchFlow> {
  final be = DemoBackend.instance;

  _Stage _stage = _Stage.searching;
  String _gameId = '';
  String _oppName = '';
  String _oppAvatar = '';
  int _countdown = 3;

  late List<Question> _questions;
  int _qIndex = 0;
  int _myScore = 0;
  int _oppScore = 0;
  int? _picked;
  bool _locked = false;
  final List<AnswerRecord> _answers = [];

  Timer? _ticker;
  double _remaining = DemoBackend.timerSeconds.toDouble();
  DateTime _qStart = DateTime.now();

  GameResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // If the player leaves mid-match the entry is refunded — the spec's
    // automatic recovery rule.
    if (_stage == _Stage.playing || _stage == _Stage.countdown) {
      be.abandonGame(_gameId, widget.entry);
    }
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      _gameId = be.startGame(widget.entry);
    } on InsufficientBalance {
      setState(() => _error = 'Not enough demo coins for this entry.');
      return;
    } on StateError {
      setState(() => _error = 'You already have a match in progress.');
      return;
    }

    _questions = be.drawQuestions();
    final (n, a) = be.drawOpponent();

    await Future.delayed(Duration(milliseconds: 1400 + (widget.entry % 7) * 110));
    if (!mounted) return;
    setState(() { _oppName = n; _oppAvatar = a; _stage = _Stage.found; });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _stage = _Stage.countdown);

    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(milliseconds: 750));
    }
    if (!mounted) return;
    setState(() { _countdown = 0; _stage = _Stage.playing; });
    _startQuestion();
  }

  void _startQuestion() {
    _picked = null;
    _locked = false;
    _remaining = DemoBackend.timerSeconds.toDouble();
    _qStart = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() => _remaining -= .1);
      if (_remaining <= 0) {
        t.cancel();
        _commit(-1); // timed out
      }
    });
  }

  void _choose(int i) {
    if (_locked) return;
    setState(() { _picked = i; _locked = true; });
    _ticker?.cancel();
    _commit(i);
  }

  Future<void> _commit(int chosen) async {
    final q = _questions[_qIndex];
    final ms = DateTime.now().difference(_qStart).inMilliseconds
        .clamp(0, DemoBackend.timerSeconds * 1000);

    // Scoring happens in the backend service, not here.
    final pts = be.scoreAnswer(correct: chosen == q.correctIndex, msTaken: ms);
    _answers.add(AnswerRecord(
      questionId: q.id,
      chosenIndex: chosen,
      correctIndex: q.correctIndex,
      msTaken: ms,
      points: pts,
    ));
    final oppPts = be.simulateOpponentAnswer();

    setState(() {
      _locked = true;
      _picked = chosen;
      _myScore += pts;
      _oppScore += oppPts;
    });

    await Future.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;

    if (_qIndex < _questions.length - 1) {
      setState(() => _qIndex++);
      _startQuestion();
    } else {
      setState(() => _stage = _Stage.settling);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final r = be.settleGame(
        gameId: _gameId,
        entry: widget.entry,
        yourScore: _myScore,
        opponentScore: _oppScore,
        opponentName: _oppName,
        opponentAvatar: _oppAvatar,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() { _result = r; _stage = _Stage.result; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _errorView();
    return PopScope(
      canPop: _stage == _Stage.result || _stage == _Stage.searching,
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: switch (_stage) {
            _Stage.searching => _searching(),
            _Stage.found => _found(),
            _Stage.countdown => _countdownView(),
            _Stage.playing => _playing(),
            _Stage.settling => _settling(),
            _Stage.result => _resultView(),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------- states ---
  Widget _errorView() => Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('😕', style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 14),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: PrimaryButton(label: 'Go back', onTap: () => Navigator.pop(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _searching() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 86, height: 86,
              child: CircularProgressIndicator(strokeWidth: 3, color: C.primary),
            ),
            const SizedBox(height: 26),
            const Text('Searching for opponent…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Entry ${fmtCoins(widget.entry)} demo coins',
                style: const TextStyle(color: C.muted, fontSize: 13.5)),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () {
                be.abandonGame(_gameId, widget.entry);
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: C.muted)),
            ),
          ],
        ),
      );

  Widget _found() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Opponent found',
                style: TextStyle(fontSize: 15, color: C.accent, fontWeight: FontWeight.w800, letterSpacing: .4)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _avatarBubble(be.user.avatar, 'You'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text('VS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.muted)),
                ),
                _avatarBubble(_oppAvatar, _oppName),
              ],
            ),
          ],
        ),
      );

  Widget _avatarBubble(String emoji, String name) => Column(
        children: [
          Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              gradient: C.cardGrad,
              shape: BoxShape.circle,
              border: Border.all(color: C.primary, width: 2),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 34))),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 100,
            child: Text(name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      );

  Widget _countdownView() => Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_countdown),
          tween: Tween(begin: .6, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Text(
            _countdown == 0 ? 'START' : '$_countdown',
            style: const TextStyle(fontSize: 78, fontWeight: FontWeight.w900, color: C.accent),
          ),
        ),
      );

  Widget _settling() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.6, color: C.accent),
            SizedBox(height: 18),
            Text('Settling match…', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Validating result and updating your wallet',
                style: TextStyle(color: C.muted, fontSize: 12.5)),
          ],
        ),
      );

  // ------------------------------------------------------------ playing ---
  Widget _playing() {
    final q = _questions[_qIndex];
    final frac = (_remaining / DemoBackend.timerSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              _scorePill(be.user.avatar, 'You', _myScore, C.accent),
              const Spacer(),
              Column(
                children: [
                  Text('Q${_qIndex + 1}/${_questions.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(q.category, style: const TextStyle(color: C.muted, fontSize: 11)),
                ],
              ),
              const Spacer(),
              _scorePill(_oppAvatar, _oppName.split(' ').first, _oppScore, C.danger),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: C.surface2,
              valueColor: AlwaysStoppedAnimation(
                  frac > .5 ? C.accent : (frac > .25 ? C.gold : C.danger)),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_remaining.clamp(0, 99).toStringAsFixed(1)}s',
              style: TextStyle(
                  color: frac > .25 ? C.muted : C.danger,
                  fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 18),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            child: SizedBox(
              width: double.infinity,
              child: Text(q.text, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w700, height: 1.35)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: q.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _option(q, i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scorePill(String emoji, String name, int score, Color colour) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Text(name, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
              ),
              Text('$score',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colour)),
            ],
          ),
        ],
      );

  Widget _option(Question q, int i) {
    Color bg = C.surface2;
    Color border = C.line;
    if (_locked) {
      if (i == q.correctIndex) {
        bg = C.accent.withValues(alpha: .16);
        border = C.accent;
      } else if (i == _picked) {
        bg = C.danger.withValues(alpha: .16);
        border = C.danger;
      }
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _locked ? null : () => _choose(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: border == C.line ? 1 : 1.8),
          ),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.line),
                ),
                child: Center(
                  child: Text(String.fromCharCode(65 + i),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.muted)),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(q.options[i],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (_locked && i == q.correctIndex)
                const Icon(Icons.check_circle, color: C.accent, size: 20),
              if (_locked && i == _picked && i != q.correctIndex)
                const Icon(Icons.cancel, color: C.danger, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- result ---
  Widget _resultView() {
    final r = _result!;
    final (title, emoji, colour) = switch (r.outcome) {
      GameOutcome.win => ('You won!', '🏆', C.accent),
      GameOutcome.loss => ('You lost', '😤', C.danger),
      GameOutcome.draw => ('It\'s a draw', '🤝', C.gold),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colour)),
          const SizedBox(height: 22),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _finalScore(be.user.avatar, 'You', r.yourScore, C.accent)),
                    Container(width: 1, height: 54, color: C.line),
                    Expanded(child: _finalScore(r.opponentAvatar, r.opponentName, r.opponentScore, C.danger)),
                  ],
                ),
                const Divider(color: C.line, height: 28),
                _kv('Demo entry', '-${fmtCoins(r.entry)}'),
                const SizedBox(height: 8),
                _kv('Demo reward', r.reward > 0 ? '+${fmtCoins(r.reward)}' : '0',
                    highlight: r.reward > 0),
                const SizedBox(height: 8),
                _kv('Net', '${r.reward - r.entry >= 0 ? '+' : ''}${fmtCoins(r.reward - r.entry)}'),
                const SizedBox(height: 14),
                const DemoBadge(center: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Question audit',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Scored on the server — correct answers plus a speed bonus.',
                    style: TextStyle(color: C.muted, fontSize: 11.5)),
                const SizedBox(height: 12),
                for (var i = 0; i < r.answers.length; i++) _auditRow(i, r.answers[i]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Play again',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MatchFlow(entry: r.entry)),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Go home',
            gradient: const LinearGradient(colors: [C.surface2, C.surface2]),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _finalScore(String emoji, String name, int score, Color colour) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(name, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$score', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colour)),
        ],
      );

  Widget _kv(String k, String v, {bool highlight = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: C.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
          Text(v,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: highlight ? C.accent : C.text)),
        ],
      );

  Widget _auditRow(int i, AnswerRecord a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: a.correct ? C.accent.withValues(alpha: .18) : C.danger.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Icon(a.correct ? Icons.check : Icons.close,
                  size: 13, color: a.correct ? C.accent : C.danger),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Q${i + 1} · ${a.chosenIndex == -1 ? 'no answer' : '${(a.msTaken / 1000).toStringAsFixed(1)}s'}',
              style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          Text('+${a.points}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: a.points > 0 ? C.accent : C.muted)),
        ],
      ),
    );
  }
}
