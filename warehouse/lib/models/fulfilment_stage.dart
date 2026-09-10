/// A shipment's status, exactly as the website's /shipments page names it.
///
/// [apiValue] is the ERP's `transactions.shipping_status`. The one that differs
/// from its Dart name is [pickedUp]: the ERP stores it as `shipped`, and the
/// website labels it "Picked up" -- the moment the rider takes the parcel.
///
/// The warehouse owns the first half. A shipment arrives `ordered`; someone
/// accepts it, ticks its items into the box and marks it `packed`; a supervisor
/// marks it `audited`. From there it belongs to the rider app, which records
/// `shipped` and `delivered` with a photo each.
enum FulfilmentStage {
  ordered,
  packed,
  audited,
  pickedUp,
  delivered,
  cancelled,
}

extension FulfilmentStageX on FulfilmentStage {
  /// The value the server sends and expects. Never derive this from [name]:
  /// `pickedUp` travels as `shipped`.
  String get apiValue => switch (this) {
        FulfilmentStage.ordered => 'ordered',
        FulfilmentStage.packed => 'packed',
        FulfilmentStage.audited => 'audited',
        FulfilmentStage.pickedUp => 'shipped',
        FulfilmentStage.delivered => 'delivered',
        FulfilmentStage.cancelled => 'cancelled',
      };

  /// The website's own words, so the phone and the page agree.
  String get label => switch (this) {
        FulfilmentStage.ordered => 'Ordered',
        FulfilmentStage.packed => 'Packed',
        FulfilmentStage.audited => 'Audited',
        FulfilmentStage.pickedUp => 'Picked up',
        FulfilmentStage.delivered => 'Delivered',
        FulfilmentStage.cancelled => 'Cancelled',
      };

  /// The button that moves a shipment out of this stage in this app, or null
  /// once it is the rider's.
  String? get staffActionLabel => switch (this) {
        FulfilmentStage.ordered => 'Mark packed',
        FulfilmentStage.packed => 'Mark audited',
        _ => null,
      };

  /// The next status on the whole flow, including the rider's half.
  FulfilmentStage? get next => switch (this) {
        FulfilmentStage.ordered => FulfilmentStage.packed,
        FulfilmentStage.packed => FulfilmentStage.audited,
        FulfilmentStage.audited => FulfilmentStage.pickedUp,
        FulfilmentStage.pickedUp => FulfilmentStage.delivered,
        FulfilmentStage.delivered || FulfilmentStage.cancelled => null,
      };

  /// The next status *this app may set*.
  ///
  /// Stops at `audited`: `shipped` is the rider confirming they hold the parcel,
  /// and staff marking it for them is how parcels get recorded as collected while
  /// still sitting on the rack. The server refuses it too.
  FulfilmentStage? get nextForStaff => switch (this) {
        FulfilmentStage.ordered => FulfilmentStage.packed,
        FulfilmentStage.packed => FulfilmentStage.audited,
        _ => null,
      };

  /// Still in the building: waiting on staff, or on the rider to collect.
  bool get isOpen =>
      this == FulfilmentStage.ordered ||
      this == FulfilmentStage.packed ||
      this == FulfilmentStage.audited;

  bool get isClosed => !isOpen;

  /// Position on the five-step timeline, or -1 for a cancelled shipment, which
  /// does not sit anywhere on it.
  int get step => switch (this) {
        FulfilmentStage.ordered => 0,
        FulfilmentStage.packed => 1,
        FulfilmentStage.audited => 2,
        FulfilmentStage.pickedUp => 3,
        FulfilmentStage.delivered => 4,
        FulfilmentStage.cancelled => -1,
      };
}

/// The timeline, in order, without the off-path `cancelled`.
const kStageTimeline = [
  FulfilmentStage.ordered,
  FulfilmentStage.packed,
  FulfilmentStage.audited,
  FulfilmentStage.pickedUp,
  FulfilmentStage.delivered,
];

/// The tabs this app puts on screen, in the order the work moves through them.
const kStaffQueues = [
  FulfilmentStage.ordered,
  FulfilmentStage.packed,
  FulfilmentStage.audited,
];

/// The status for a wire value, or null when this build does not know it.
///
/// Case-insensitive: the ERP table holds capitalised strays ('Ordered',
/// 'Packed') written by an older screen.
FulfilmentStage? stageFromApiOrNull(Object? value) {
  final wanted = '$value'.trim().toLowerCase();
  for (final stage in FulfilmentStage.values) {
    if (stage.apiValue == wanted) return stage;
  }
  return null;
}

/// Reads a status back from the wire, falling back rather than throwing: one
/// shipment with a value this build predates should not take the list down.
FulfilmentStage stageFromApi(
  Object? value, {
  FulfilmentStage fallback = FulfilmentStage.ordered,
}) =>
    stageFromApiOrNull(value) ?? fallback;
