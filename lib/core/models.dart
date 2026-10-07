/// Domain models for SkillArena.
///
/// These mirror the PostgreSQL tables in the production spec (users, wallets,
/// wallet_transactions, games, questions, ...). In this demo build they are
/// held in memory by DemoBackend; in production the same shapes come back from
/// the NestJS REST API.
library;

enum TxType {
  demoCredit('DEMO_CREDIT', 'Demo credit'),
  gameEntry('GAME_ENTRY', 'Game entry'),
  gameWin('GAME_WIN', 'Game win'),
  gameLoss('GAME_LOSS', 'Game loss'),
  bonus('BONUS', 'Bonus'),
  refund('REFUND', 'Refund'),
  adminAdjustment('ADMIN_ADJUSTMENT', 'Admin adjustment');

  const TxType(this.code, this.label);
  final String code;
  final String label;
}

/// A single immutable ledger row. Balance before and after are recorded on
/// every movement — a balance is never written without one of these.
class WalletTx {
  WalletTx({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.referenceId,
    required this.description,
    required this.at,
  });

  final String id;
  final String userId;
  final TxType type;
  final int amount; // signed: negative = debit
  final int balanceBefore;
  final int balanceAfter;
  final String referenceId;
  final String description;
  final DateTime at;

  bool get isCredit => amount >= 0;
}

enum AccountStatus { active, suspended, blocked }

class UserProfile {
  UserProfile({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.dob,
    required this.avatar,
    required this.status,
    required this.verified,
    required this.joinedAt,
    required this.lastLogin,
    required this.referralCode,
  });

  final String id;
  String fullName;
  final String mobile;
  String email;
  String dob;
  String avatar;
  AccountStatus status;
  bool verified;
  final DateTime joinedAt;
  DateTime lastLogin;
  final String referralCode;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class Question {
  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.category,
    required this.difficulty,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String category;
  final String difficulty;
}

/// What the player answered on one question, and what the server scored it.
class AnswerRecord {
  AnswerRecord({
    required this.questionId,
    required this.chosenIndex,
    required this.correctIndex,
    required this.msTaken,
    required this.points,
  });

  final String questionId;
  final int chosenIndex; // -1 = no answer / timed out
  final int correctIndex;
  final int msTaken;
  final int points;

  bool get correct => chosenIndex == correctIndex;
}

enum GameOutcome { win, loss, draw }

class GameResult {
  GameResult({
    required this.gameId,
    required this.playedAt,
    required this.entry,
    required this.opponentName,
    required this.opponentAvatar,
    required this.yourScore,
    required this.opponentScore,
    required this.outcome,
    required this.reward,
    required this.answers,
  });

  final String gameId;
  final DateTime playedAt;
  final int entry;
  final String opponentName;
  final String opponentAvatar;
  final int yourScore;
  final int opponentScore;
  final GameOutcome outcome;
  final int reward; // credited back to the wallet (0 on a loss)
  final List<AnswerRecord> answers;
}

class LeaderRow {
  LeaderRow({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.played,
    required this.wins,
    required this.points,
    this.isYou = false,
  });

  final int rank;
  final String name;
  final String avatar;
  final int played;
  final int wins;
  final int points;
  final bool isYou;

  int get winRate => played == 0 ? 0 : ((wins / played) * 100).round();
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.icon,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final String icon;
  bool read;
}
