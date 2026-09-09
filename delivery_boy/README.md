# Delivery Boy

A Flutter app for delivery riders: receive order requests, run a delivery
through its stages, and track what you earned.

## What it does

- **Sign in** with a phone number and a 4-digit PIN.
- **Go online / offline** — requests only arrive while you are online.
- **See new requests** with pickup, drop-off, distance, ETA and payout, then
  accept or decline.
- **Run one delivery at a time** through Accepted → Picked up → On the way →
  Delivered, with a progress rail and a single action button at each step.
- **Know what to collect** — cash orders show the amount due at the door,
  prepaid orders show nothing to collect.
- **History** of completed and cancelled runs.
- **Earnings** split into delivery fees and tips, with a per-order breakdown.
- **Profile** with vehicle, rating and an availability switch.

## Running it

```bash
flutter pub get
flutter run
```

The app ships with seed data (`lib/data/mock_data.dart`), so every screen is
explorable with no backend. Any 4-digit PIN signs you in.

Other targets:

```bash
flutter test           # 15 unit + widget tests
flutter analyze        # clean
flutter build apk      # Android
flutter build web      # web
```

## Layout

```
lib/
  main.dart              entry point
  app.dart               providers, theme, sign-in gate
  models/                Address, Order, OrderStatus, Driver
  data/                  OrderRepository (swap for real HTTP) + seed data
  state/                 SessionController, OrdersController
  screens/               login, dashboard, order detail, active delivery,
                         history, earnings, profile
  widgets/               reusable cards, status chip, progress timeline
  utils/                 money / distance / date formatting
```

State is plain `ChangeNotifier` + `provider`. The only dependency beyond the
Flutter SDK is `provider`.

## Connecting a real backend

`OrderRepository` is the single seam. It exposes:

```dart
Future<List<Order>> fetchOrders();
Future<Order> updateStatus(String orderId, OrderStatus status);
```

Replace the bodies with HTTP calls and nothing above it changes —
`OrdersController` and every screen stay as they are. `OrderRepository` is
injected through `DeliveryBoyApp(repository: ...)`, which is also how the
tests supply fixtures.

## Rules worth knowing

- A rider holds **one** active delivery; accepting a second is refused while
  one is in progress.
- Rider earnings are `deliveryFee + tip`. The item total belongs to the
  merchant.
- Cash orders collect `itemsTotal + deliveryFee`; prepaid collect nothing.
- "Today" figures count only orders **delivered** today.

## Status

This is a working front-end with an in-memory data layer. Not yet wired up:
real authentication, a live orders feed (push/websocket), maps and turn-by-turn
navigation, and actual phone dialling — the call buttons currently show a
snackbar.
