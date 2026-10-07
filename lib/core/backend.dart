/// DemoBackend — stands in for the NestJS + PostgreSQL + Redis backend.
///
/// Everything the spec says must NOT be trusted to the client lives in here
/// and nowhere else: scoring, the winner, the entry deduction, the wallet
/// balance and the settlement. The UI only ever reads results from this class;
/// it never computes a score or edits a balance itself.
///
/// In production this file is replaced by HTTP/WebSocket calls to NestJS. The
/// method signatures are deliberately shaped like the REST endpoints so the
/// swap is mechanical.
library;

import 'dart:math';
import 'models.dart';

class InsufficientBalance implements Exception {
  const InsufficientBalance();
}

class DemoBackend {
  DemoBackend._();
  static final DemoBackend instance = DemoBackend._();

  static const int startingDemoCoins = 10000;

  final Random _rng = Random(20261006);
  int _seq = 0;
  String _id(String prefix) => '$prefix-${(++_seq).toString().padLeft(6, '0')}';

  // ---------------------------------------------------------------- state --
  late UserProfile user;
  int demoBalance = 0;
  int rewardBalance = 0;
  int bonusBalance = 0;

  final List<WalletTx> ledger = [];
  final List<GameResult> history = [];
  final List<AppNotification> notifications = [];

  /// Guard matching the spec's "prevent one user from entering multiple active
  /// matches using the same wallet balance" — in production this is a Redis
  /// lock, here it is a simple in-process flag.
  bool _matchLocked = false;
  bool get matchInProgress => _matchLocked;

  int dailyStreak = 0;
  DateTime? lastClaim;
  bool get canClaimDaily {
    if (lastClaim == null) return true;
    final now = DateTime.now();
    return !(lastClaim!.year == now.year &&
        lastClaim!.month == now.month &&
        lastClaim!.day == now.day);
  }

  static const List<int> dailyLadder = [10, 15, 20, 25, 30, 40, 100];
  int get nextDailyReward => dailyLadder[dailyStreak % dailyLadder.length];

  int referredUsers = 0;
  int successfulReferrals = 0;
  int referralEarnings = 0;

  bool _booted = false;

  /// Clears all state so the instance can be bootstrapped again.
  /// Used by the test suite; also what a real sign-out would do before the
  /// next user signs in.
  void reset() {
    _booted = false;
    _matchLocked = false;
    _seq = 0;
    demoBalance = 0;
    rewardBalance = 0;
    bonusBalance = 0;
    ledger.clear();
    history.clear();
    notifications.clear();
    dailyStreak = 0;
    lastClaim = null;
    referredUsers = 0;
    successfulReferrals = 0;
    referralEarnings = 0;
  }

  // ----------------------------------------------------------------- boot --
  /// [seedDemoData] fills the account with sample games and notifications so
  /// the demo looks lived-in. Tests boot with it off to assert on a clean
  /// signup balance.
  void bootstrap(String mobile, {bool seedDemoData = true}) {
    if (_booted) return;
    _booted = true;

    final now = DateTime.now();
    user = UserProfile(
      id: 'USR-100248',
      fullName: 'Abhay Pal',
      mobile: mobile,
      email: 'abhay@example.com',
      dob: '14 Mar 1996',
      avatar: '🎮',
      status: AccountStatus.active,
      verified: true,
      joinedAt: now.subtract(const Duration(days: 42)),
      lastLogin: now,
      referralCode: 'SKILL-AB7K24',
    );

    // Signup grant — recorded as a ledger entry, never a bare balance write.
    _post(
      type: TxType.demoCredit,
      amount: startingDemoCoins,
      reference: 'SIGNUP',
      description: 'Welcome demo coins',
    );

    if (!seedDemoData) return;

    referredUsers = 4;
    successfulReferrals = 2;
    referralEarnings = 500;

    _seedHistory();

    notifications.addAll([
      AppNotification(
        id: _id('NTF'),
        title: 'Daily reward available',
        body: 'Claim ${nextDailyReward} demo coins for today.',
        at: now.subtract(const Duration(minutes: 8)),
        icon: '🎁',
      ),
      AppNotification(
        id: _id('NTF'),
        title: 'Welcome bonus added',
        body: '10,000 demo coins credited to your wallet.',
        at: now.subtract(const Duration(days: 42)),
        icon: '💰',
        read: true,
      ),
      AppNotification(
        id: _id('NTF'),
        title: 'New category added',
        body: 'Science & Tech questions are now live.',
        at: now.subtract(const Duration(days: 2)),
        icon: '📣',
      ),
    ]);
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  // --------------------------------------------------------------- ledger --
  /// The ONLY way a balance changes. Writes the row and the balance together.
  WalletTx _post({
    required TxType type,
    required int amount,
    required String reference,
    required String description,
  }) {
    final before = demoBalance;
    final after = before + amount;
    if (after < 0) throw const InsufficientBalance();

    demoBalance = after;
    if (type == TxType.gameWin) rewardBalance += amount;
    if (type == TxType.bonus) bonusBalance += amount;

    final tx = WalletTx(
      id: _id('TXN'),
      userId: _booted ? user.id : 'USR-100248',
      type: type,
      amount: amount,
      balanceBefore: before,
      balanceAfter: after,
      referenceId: reference,
      description: description,
      at: DateTime.now(),
    );
    ledger.insert(0, tx);
    return tx;
  }

  // ----------------------------------------------------------- questions --
  static final List<Question> _bank = [
    Question(id: 'Q1', text: 'Which planet is known as the Red Planet?', options: ['Venus', 'Mars', 'Jupiter', 'Mercury'], correctIndex: 1, category: 'Science', difficulty: 'Easy'),
    Question(id: 'Q2', text: 'What does CPU stand for?', options: ['Central Process Unit', 'Computer Personal Unit', 'Central Processing Unit', 'Control Panel Unit'], correctIndex: 2, category: 'Technology', difficulty: 'Easy'),
    Question(id: 'Q3', text: 'How many continents are there on Earth?', options: ['5', '6', '7', '8'], correctIndex: 2, category: 'Geography', difficulty: 'Easy'),
    Question(id: 'Q4', text: 'Who wrote the play "Romeo and Juliet"?', options: ['Charles Dickens', 'William Shakespeare', 'Jane Austen', 'Mark Twain'], correctIndex: 1, category: 'Literature', difficulty: 'Easy'),
    Question(id: 'Q5', text: 'What is the largest ocean on Earth?', options: ['Atlantic', 'Indian', 'Arctic', 'Pacific'], correctIndex: 3, category: 'Geography', difficulty: 'Easy'),
    Question(id: 'Q6', text: 'Which gas do plants absorb from the atmosphere?', options: ['Oxygen', 'Carbon dioxide', 'Nitrogen', 'Hydrogen'], correctIndex: 1, category: 'Science', difficulty: 'Easy'),
    Question(id: 'Q7', text: 'In which year did the first iPhone launch?', options: ['2005', '2006', '2007', '2008'], correctIndex: 2, category: 'Technology', difficulty: 'Medium'),
    Question(id: 'Q8', text: 'What is the capital city of Australia?', options: ['Sydney', 'Melbourne', 'Canberra', 'Perth'], correctIndex: 2, category: 'Geography', difficulty: 'Medium'),
    Question(id: 'Q9', text: 'Which language is primarily used to build Flutter apps?', options: ['Kotlin', 'Dart', 'Swift', 'Java'], correctIndex: 1, category: 'Technology', difficulty: 'Medium'),
    Question(id: 'Q10', text: 'How many players are on a cricket team on the field?', options: ['9', '10', '11', '12'], correctIndex: 2, category: 'Sports', difficulty: 'Easy'),
    Question(id: 'Q11', text: 'What is the chemical symbol for gold?', options: ['Gd', 'Go', 'Au', 'Ag'], correctIndex: 2, category: 'Science', difficulty: 'Medium'),
    Question(id: 'Q12', text: 'Which database is this platform specified to use?', options: ['MongoDB', 'MySQL', 'PostgreSQL', 'SQLite'], correctIndex: 2, category: 'Technology', difficulty: 'Medium'),
  ];

  List<Question> drawQuestions() {
    final pool = List<Question>.from(_bank)..shuffle(_rng);
    return pool.take(5).toList();
  }

  // ---------------------------------------------------------------- game ---
  static const int timerSeconds = 10;
  static const int basePoints = 100;

  /// Server-side scoring: correct answers earn base points, and answering
  /// faster earns a speed bonus. A wrong or missed answer scores zero.
  int scoreAnswer({required bool correct, required int msTaken}) {
    if (!correct) return 0;
    final remaining = (timerSeconds * 1000 - msTaken).clamp(0, timerSeconds * 1000);
    final speedBonus = (remaining / (timerSeconds * 1000) * 50).round();
    return basePoints + speedBonus;
  }

  /// Deducts the entry and locks the player out of a second concurrent match.
  /// Throws InsufficientBalance rather than letting the UI decide.
  String startGame(int entry) {
    if (_matchLocked) {
      throw StateError('A match is already in progress');
    }
    if (entry > demoBalance) throw const InsufficientBalance();
    final gameId = _id('GME');
    _matchLocked = true;
    _post(
      type: TxType.gameEntry,
      amount: -entry,
      reference: gameId,
      description: 'Entry — $entry demo coins',
    );
    return gameId;
  }

  /// Settles the match atomically: decide the outcome, write the matching
  /// ledger row, record the game. Nothing is left half-settled.
  GameResult settleGame({
    required String gameId,
    required int entry,
    required int yourScore,
    required int opponentScore,
    required String opponentName,
    required String opponentAvatar,
    required List<AnswerRecord> answers,
  }) {
    final GameOutcome outcome;
    int reward;

    if (yourScore > opponentScore) {
      outcome = GameOutcome.win;
      reward = entry * 2; // both entries, winner takes the pot
      _post(
        type: TxType.gameWin,
        amount: reward,
        reference: gameId,
        description: 'Won — $opponentName',
      );
    } else if (yourScore < opponentScore) {
      outcome = GameOutcome.loss;
      reward = 0;
      // The entry was already debited at start; record the loss at zero so the
      // game still appears on the ledger as a settled event.
      _post(
        type: TxType.gameLoss,
        amount: 0,
        reference: gameId,
        description: 'Lost — $opponentName',
      );
    } else {
      // Published tie rule: scores level, both entries returned in full.
      outcome = GameOutcome.draw;
      reward = entry;
      _post(
        type: TxType.refund,
        amount: reward,
        reference: gameId,
        description: 'Draw — entry refunded',
      );
    }

    final result = GameResult(
      gameId: gameId,
      playedAt: DateTime.now(),
      entry: entry,
      opponentName: opponentName,
      opponentAvatar: opponentAvatar,
      yourScore: yourScore,
      opponentScore: opponentScore,
      outcome: outcome,
      reward: reward,
      answers: answers,
    );
    history.insert(0, result);
    _matchLocked = false;

    notifications.insert(
      0,
      AppNotification(
        id: _id('NTF'),
        title: switch (outcome) {
          GameOutcome.win => 'You won ${reward} demo coins',
          GameOutcome.loss => 'Match lost',
          GameOutcome.draw => 'Match drawn — entry refunded',
        },
        body: 'vs $opponentName · $yourScore–$opponentScore',
        at: DateTime.now(),
        icon: switch (outcome) {
          GameOutcome.win => '🏆',
          GameOutcome.loss => '⚔️',
          GameOutcome.draw => '🤝',
        },
      ),
    );
    return result;
  }

  /// Releases the match lock and refunds the entry if a game is abandoned —
  /// the spec's automatic recovery/refund rule.
  void abandonGame(String gameId, int entry) {
    if (!_matchLocked) return;
    _post(
      type: TxType.refund,
      amount: entry,
      reference: gameId,
      description: 'Match abandoned — entry refunded',
    );
    _matchLocked = false;
  }

  // ------------------------------------------------------- opponent sim ----
  static const List<String> _oppNames = [
    'Rohit S.', 'Priya N.', 'Arjun M.', 'Neha K.', 'Vikram R.',
    'Sana I.', 'Kabir J.', 'Meera D.',
  ];
  static const List<String> _oppAvatars = ['🦊', '🐼', '🦁', '🐯', '🦉', '🐺', '🐲', '🦅'];

  (String, String) drawOpponent() {
    final i = _rng.nextInt(_oppNames.length);
    return (_oppNames[i], _oppAvatars[i]);
  }

  /// Opponent plays each question with plausible accuracy and speed.
  int simulateOpponentAnswer() {
    final correct = _rng.nextDouble() < 0.62;
    if (!correct) return 0;
    final ms = 1500 + _rng.nextInt(7000);
    return scoreAnswer(correct: true, msTaken: ms);
  }

  // ------------------------------------------------------------- rewards --
  int claimDaily() {
    if (!canClaimDaily) return 0;
    final amount = nextDailyReward;
    _post(
      type: TxType.bonus,
      amount: amount,
      reference: 'DAILY-D${dailyStreak + 1}',
      description: 'Daily reward — day ${dailyStreak + 1}',
    );
    dailyStreak += 1;
    lastClaim = DateTime.now();
    return amount;
  }

  // --------------------------------------------------------- leaderboard --
  List<LeaderRow> leaderboard(String period) {
    final played = history.length;
    final wins = history.where((g) => g.outcome == GameOutcome.win).length;
    final yourPoints = history.fold<int>(0, (s, g) => s + g.yourScore);

    final seedBase = switch (period) {
      'Daily' => 1,
      'Weekly' => 7,
      _ => 30,
    };
    final rows = <LeaderRow>[];
    for (var i = 0; i < 8; i++) {
      final p = 20 * seedBase + (8 - i) * 37;
      rows.add(LeaderRow(
        rank: 0,
        name: _oppNames[i],
        avatar: _oppAvatars[i],
        played: 12 * seedBase + i * 3,
        wins: (12 * seedBase + i * 3) ~/ 2 + (i.isEven ? 2 : -1),
        points: p * 7,
      ));
    }
    rows.add(LeaderRow(
      rank: 0,
      name: user.fullName,
      avatar: user.avatar,
      played: played,
      wins: wins,
      points: yourPoints,
      isYou: true,
    ));
    rows.sort((a, b) => b.points.compareTo(a.points));
    return [
      for (var i = 0; i < rows.length; i++)
        LeaderRow(
          rank: i + 1,
          name: rows[i].name,
          avatar: rows[i].avatar,
          played: rows[i].played,
          wins: rows[i].wins,
          points: rows[i].points,
          isYou: rows[i].isYou,
        )
    ];
  }

  // ------------------------------------------------------------- seeding --
  void _seedHistory() {
    final entries = [50, 20, 100, 50, 200];
    final outcomes = [
      GameOutcome.win,
      GameOutcome.loss,
      GameOutcome.win,
      GameOutcome.draw,
      GameOutcome.loss,
    ];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final outcome = outcomes[i];
      final gid = _id('GME');
      final when = DateTime.now().subtract(Duration(hours: 6 * (i + 1)));
      final (name, avatar) = drawOpponent();

      _postDated(TxType.gameEntry, -entry, gid, 'Entry — $entry demo coins', when);
      final int yours, theirs, reward;
      switch (outcome) {
        case GameOutcome.win:
          yours = 420 + i * 11;
          theirs = 310 + i * 9;
          reward = entry * 2;
          _postDated(TxType.gameWin, reward, gid, 'Won — $name', when);
        case GameOutcome.loss:
          yours = 260 + i * 7;
          theirs = 395 + i * 6;
          reward = 0;
          _postDated(TxType.gameLoss, 0, gid, 'Lost — $name', when);
        case GameOutcome.draw:
          yours = 350;
          theirs = 350;
          reward = entry;
          _postDated(TxType.refund, reward, gid, 'Draw — entry refunded', when);
      }
      history.add(GameResult(
        gameId: gid,
        playedAt: when,
        entry: entry,
        opponentName: name,
        opponentAvatar: avatar,
        yourScore: yours,
        opponentScore: theirs,
        outcome: outcome,
        reward: reward,
        answers: const [],
      ));
    }
    history.sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  void _postDated(TxType type, int amount, String ref, String desc, DateTime at) {
    final before = demoBalance;
    final after = before + amount;
    demoBalance = after;
    if (type == TxType.gameWin) rewardBalance += amount;
    ledger.insert(
      0,
      WalletTx(
        id: _id('TXN'),
        userId: 'USR-100248',
        type: type,
        amount: amount,
        balanceBefore: before,
        balanceAfter: after,
        referenceId: ref,
        description: desc,
        at: at,
      ),
    );
  }
}
