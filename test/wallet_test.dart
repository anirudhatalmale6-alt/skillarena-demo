import 'package:flutter_test/flutter_test.dart';
import 'package:skillarena/core/backend.dart';
import 'package:skillarena/core/models.dart';

/// These cover the parts the spec says matter most: ledger integrity,
/// settlement correctness, and not being able to spend the same balance twice.
void main() {
  late DemoBackend be;

  setUp(() {
    be = DemoBackend.instance;
    be.reset();
    be.bootstrap('9999999999', seedDemoData: false);
  });

  group('wallet ledger', () {
    test('signup grant is recorded as a transaction, not a bare balance write', () {
      expect(be.demoBalance, DemoBackend.startingDemoCoins);
      final first = be.ledger.last;
      expect(first.type, TxType.demoCredit);
      expect(first.balanceBefore, 0);
      expect(first.balanceAfter, DemoBackend.startingDemoCoins);
    });

    test('every row chains: balanceAfter of one equals balanceBefore of the next', () {
      be.startGame(50);
      be.settleGame(
        gameId: 'G1', entry: 50, yourScore: 400, opponentScore: 100,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      be.claimDaily();

      final rows = be.ledger.reversed.toList(); // oldest first
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].balanceBefore, rows[i - 1].balanceAfter,
            reason: 'ledger broken between ${rows[i - 1].id} and ${rows[i].id}');
      }
      expect(rows.last.balanceAfter, be.demoBalance);
    });

    test('balance always equals the sum of every ledger amount', () {
      be.startGame(100);
      be.settleGame(
        gameId: 'G2', entry: 100, yourScore: 10, opponentScore: 900,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      final sum = be.ledger.fold<int>(0, (s, t) => s + t.amount);
      expect(be.demoBalance, sum);
    });
  });

  group('entry and double-spend', () {
    test('entry is debited immediately when the game starts', () {
      final before = be.demoBalance;
      be.startGame(200);
      expect(be.demoBalance, before - 200);
      expect(be.ledger.first.type, TxType.gameEntry);
      expect(be.ledger.first.amount, -200);
    });

    test('a second match cannot start while one is in progress', () {
      be.startGame(50);
      expect(() => be.startGame(50), throwsA(isA<StateError>()));
    });

    test('an entry larger than the balance is rejected', () {
      expect(() => be.startGame(be.demoBalance + 1), throwsA(isA<InsufficientBalance>()));
    });

    test('a rejected entry leaves the balance and ledger untouched', () {
      final balance = be.demoBalance;
      final rows = be.ledger.length;
      expect(() => be.startGame(999999), throwsA(isA<InsufficientBalance>()));
      expect(be.demoBalance, balance);
      expect(be.ledger.length, rows);
    });
  });

  group('settlement', () {
    test('a win credits twice the entry', () {
      final start = be.demoBalance;
      be.startGame(100);
      final r = be.settleGame(
        gameId: 'G3', entry: 100, yourScore: 500, opponentScore: 200,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      expect(r.outcome, GameOutcome.win);
      expect(r.reward, 200);
      expect(be.demoBalance, start + 100); // -100 entry, +200 win
    });

    test('a loss keeps the entry and credits nothing', () {
      final start = be.demoBalance;
      be.startGame(100);
      final r = be.settleGame(
        gameId: 'G4', entry: 100, yourScore: 100, opponentScore: 500,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      expect(r.outcome, GameOutcome.loss);
      expect(r.reward, 0);
      expect(be.demoBalance, start - 100);
    });

    test('a draw refunds the entry in full', () {
      final start = be.demoBalance;
      be.startGame(100);
      final r = be.settleGame(
        gameId: 'G5', entry: 100, yourScore: 300, opponentScore: 300,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      expect(r.outcome, GameOutcome.draw);
      expect(be.demoBalance, start);
    });

    test('settling releases the lock so the next match can start', () {
      be.startGame(10);
      be.settleGame(
        gameId: 'G6', entry: 10, yourScore: 1, opponentScore: 2,
        opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
      );
      expect(be.matchInProgress, isFalse);
      expect(() => be.startGame(10), returnsNormally);
    });

    test('abandoning a match refunds the entry and clears the lock', () {
      final start = be.demoBalance;
      final id = be.startGame(500);
      be.abandonGame(id, 500);
      expect(be.demoBalance, start);
      expect(be.matchInProgress, isFalse);
      expect(be.ledger.first.type, TxType.refund);
    });
  });

  group('scoring', () {
    test('a wrong answer scores nothing', () {
      expect(be.scoreAnswer(correct: false, msTaken: 100), 0);
    });

    test('a faster correct answer scores more than a slower one', () {
      final fast = be.scoreAnswer(correct: true, msTaken: 1000);
      final slow = be.scoreAnswer(correct: true, msTaken: 9000);
      expect(fast, greaterThan(slow));
      expect(slow, greaterThanOrEqualTo(DemoBackend.basePoints));
    });

    test('scores never exceed base plus the maximum speed bonus', () {
      final best = be.scoreAnswer(correct: true, msTaken: 0);
      expect(best, DemoBackend.basePoints + 50);
    });
  });

  group('daily reward', () {
    test('claiming credits the ladder amount and advances the streak', () {
      final start = be.demoBalance;
      final amount = be.claimDaily();
      expect(amount, DemoBackend.dailyLadder.first);
      expect(be.demoBalance, start + amount);
      expect(be.dailyStreak, 1);
    });

    test('a second claim on the same day is refused', () {
      be.claimDaily();
      final balance = be.demoBalance;
      expect(be.claimDaily(), 0);
      expect(be.demoBalance, balance, reason: 'duplicate claim must not credit again');
    });
  });

  group('load', () {
    test('100 sequential matches keep the ledger and balance consistent', () {
      for (var i = 0; i < 100; i++) {
        if (be.demoBalance < 10) break;
        be.startGame(10);
        be.settleGame(
          gameId: 'L$i', entry: 10,
          yourScore: i.isEven ? 500 : 100,
          opponentScore: i.isEven ? 100 : 500,
          opponentName: 'Bot', opponentAvatar: '🤖', answers: const [],
        );
      }
      final sum = be.ledger.fold<int>(0, (s, t) => s + t.amount);
      expect(be.demoBalance, sum);
      expect(be.matchInProgress, isFalse);

      final rows = be.ledger.reversed.toList();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].balanceBefore, rows[i - 1].balanceAfter);
      }
    });
  });
}
