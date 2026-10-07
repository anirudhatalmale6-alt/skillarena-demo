# SkillArena — demo build

Flutter skill-game platform (quiz duels). **Demo coins only — no real money,
no deposits, no payouts.**

Live web demo: https://anirudhatalmale6-alt.github.io/skillarena-demo/
Android APK: see the Releases tab.

Sign in with mobile `9999999999`, OTP `123456`.

## What this build is

The complete player journey in real Flutter, with the game and wallet logic
written the way the production spec requires:

* mobile + OTP login (mock OTP service)
* home dashboard, demo balance, daily reward ladder, entry levels 10–500
* matchmaking → "opponent found" → synchronised 3-2-1 countdown
* 5 questions, 10-second timer, 4 options, live score against the opponent
* result screen with entry, reward, net, and a per-question audit
* ledger-based wallet: every movement writes a transaction with balance
  before/after — a balance is never written on its own
* transaction history with filters, game history with detail, leaderboards
  (daily / weekly / all-time), referrals, notifications
* dark premium theme, bottom navigation, loading/empty/error states

## What is simulated

`lib/core/backend.dart` stands in for the NestJS + PostgreSQL + Redis backend.
Everything the spec says the client must not be trusted with — scoring, the
winner, the entry deduction, the balance, the settlement — lives in that one
file and nowhere else. The UI only reads results from it.

That means swapping it for the real API is mechanical: the method signatures
are already shaped like the REST endpoints.

The opponent is currently a simulated player, not a second real device.

## Not in this build

Real backend (NestJS, PostgreSQL, Redis, Socket.IO), admin panel, real
matchmaking between two devices, horizontal scaling, load tests, Docker.
Those are the production phases.

## Run it

```
flutter pub get
flutter run                 # Android device or emulator
flutter test                # 18 wallet / settlement / scoring tests
flutter build apk --release
flutter build web --release --base-href /skillarena-demo/
```

## Tests

`test/wallet_test.dart` covers the things that must not break:
ledger chaining (every row's balanceAfter equals the next row's balanceBefore),
balance always equals the sum of the ledger, entry debited on start,
double-spend prevented, insufficient balance rejected cleanly, win/loss/draw
settlement, abandoned-match refund, scoring bounds, duplicate daily-reward
claim refused, and 100 sequential matches leaving the ledger consistent.

All 18 pass.
