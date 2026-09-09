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
- **Close out with proof** — a cash order cannot be marked delivered until the
  rider confirms they took the money, and an optional note ("left with
  reception") is kept on the order.
- **History** of completed and cancelled runs.
- **Earnings** split into delivery fees and tips, with a per-order breakdown.
- **Profile** with vehicle, rating and an availability switch.
- **Dark mode**, following the system setting — riders work at night.
- **Survives a restart** — an in-progress delivery, and the signed-in session,
  are stored on the device.

## Running it

```bash
flutter pub get
flutter run
```

The app ships with seed data (`lib/data/mock_data.dart`), so every screen is
explorable with no backend. Any 4-digit PIN signs you in.

Other targets:

```bash
flutter test           # 29 unit + widget tests
flutter analyze        # clean
flutter build apk      # Android
flutter build web      # web
```

## Layout

```
lib/
  main.dart              entry point
  app.dart               providers, theme, sign-in gate
  models/                Address, Order, OrderStatus, Driver (+ JSON)
  data/                  OrderRepository (swap for real HTTP), LocalStore,
                         seed data
  state/                 SessionController, OrdersController
  screens/               login, dashboard, order detail, active delivery,
                         history, earnings, profile
  widgets/               reusable cards, status chip, progress timeline,
                         delivery confirmation sheet
  theme/                 light + dark palettes (AppColors ThemeExtension)
  utils/                 money / distance / date formatting
```

State is plain `ChangeNotifier` + `provider`. Dependencies beyond the Flutter
SDK are `provider` and `shared_preferences`.

Card, page and per-status colours live in an `AppColors` `ThemeExtension` with
an explicit value for each brightness, reached via `context.appColors`. Nothing
paints a hardcoded colour, so both themes stay deliberate.

## Connecting a real backend

`OrderRepository` is the single seam. It exposes:

```dart
Future<List<Order>> fetchOrders();
Future<Order> updateStatus(String orderId, OrderStatus status);
Future<Order> completeDelivery(String id, {required bool cashCollected, String? note});
```

Replace the bodies with HTTP calls and nothing above it changes —
`OrdersController` and every screen stay as they are. `OrderRepository` is
injected through `DeliveryBoyApp(repository: ...)`, which is also how the
tests supply fixtures. `LocalStore` is injected the same way; leaving it null
gives a purely in-memory repository, which is what the tests use.

## Rules worth knowing

- A rider holds **one** active delivery; accepting a second is refused while
  one is in progress.
- Rider earnings are `deliveryFee + tip`. The item total belongs to the
  merchant.
- Cash orders collect `itemsTotal + deliveryFee`; prepaid collect nothing.
- "Today" figures count only orders **delivered** today.
- `advance()` deliberately stops short of `delivered`. Closing an order out
  goes through `completeDelivery()`, which refuses a cash order until the
  rider confirms the money.

## Status

This is a working front-end. Orders and session persist on the device; the
data itself is still seeded locally. Not yet wired up: real authentication, a
live orders feed (push/websocket), maps and turn-by-turn navigation, and actual
phone dialling — the call buttons currently show a snackbar.
