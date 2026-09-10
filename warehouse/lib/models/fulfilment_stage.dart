/// The shop's fulfilment stages, in the order an order moves through them.
///
/// These names mirror `core/api/shop/orders.py::STAGES` on the mekhea backend --
/// the same five the customer app filters by (`?delivery_status=`) and draws its
/// order timeline from. [apiValue] is what travels on the wire; the enum name is
/// only for Dart, which is why the two differ for `pickedUp`/`picked_up`.
///
/// Warehouse staff own the middle of this list. `ordered` arrives from checkout,
/// `pickedUp` and `delivered` belong to the rider app, and the handoff between
/// the two apps is the step from `checked` to `pickedUp`.
enum FulfilmentStage {
  ordered,
  prepared,
  checked,
  pickedUp,
  delivered,
  cancelled,
}

extension FulfilmentStageX on FulfilmentStage {
  /// The value the backend sends and expects. Never derive this from [name] --
  /// `pickedUp` and `picked_up` are deliberately not the same string.
  String get apiValue => switch (this) {
        FulfilmentStage.ordered => 'ordered',
        FulfilmentStage.prepared => 'prepared',
        FulfilmentStage.checked => 'checked',
        FulfilmentStage.pickedUp => 'picked_up',
        FulfilmentStage.delivered => 'delivered',
        FulfilmentStage.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        FulfilmentStage.ordered => 'Ordered',
        FulfilmentStage.prepared => 'Prepared',
        FulfilmentStage.checked => 'Checked',
        FulfilmentStage.pickedUp => 'Picked up',
        FulfilmentStage.delivered => 'Delivered',
        FulfilmentStage.cancelled => 'Cancelled',
      };

  /// What the floor calls this stage -- the work waiting to happen, not what
  /// already did.
  ///
  /// Kept to one word because it labels a tab, and three tabs share the width of
  /// a phone. "To prepare" plus a count badge overflows a 420px screen, and a
  /// truncated verb is worse than a short one.
  String get queueLabel => switch (this) {
        FulfilmentStage.ordered => 'Prepare',
        FulfilmentStage.prepared => 'Check',
        FulfilmentStage.checked => 'Driver',
        FulfilmentStage.pickedUp => 'Collected',
        FulfilmentStage.delivered => 'Delivered',
        FulfilmentStage.cancelled => 'Cancelled',
      };

  /// The button that moves an order out of this stage, for the staff who can.
  /// Null once the order has left the warehouse's hands.
  String? get staffActionLabel => switch (this) {
        FulfilmentStage.ordered => 'Mark prepared',
        FulfilmentStage.prepared => 'Mark checked',
        _ => null,
      };

  /// The next stage in the list, or null at a terminal one. This is the whole
  /// pipeline, including the rider's half.
  FulfilmentStage? get next => switch (this) {
        FulfilmentStage.ordered => FulfilmentStage.prepared,
        FulfilmentStage.prepared => FulfilmentStage.checked,
        FulfilmentStage.checked => FulfilmentStage.pickedUp,
        FulfilmentStage.pickedUp => FulfilmentStage.delivered,
        FulfilmentStage.delivered || FulfilmentStage.cancelled => null,
      };

  /// The next stage *this app is allowed to set*.
  ///
  /// Deliberately stops at `checked`: moving an order to `picked_up` is the
  /// rider confirming they have it, and staff marking it on the driver's behalf
  /// is how parcels get recorded as collected while still sitting on the rack.
  FulfilmentStage? get nextForStaff {
    final candidate = next;
    if (candidate == null) return null;
    return candidate.isStaffOwned ? candidate : null;
  }

  /// Stages the warehouse is responsible for reaching.
  bool get isStaffOwned =>
      this == FulfilmentStage.prepared || this == FulfilmentStage.checked;

  /// Sitting in a warehouse queue, waiting on staff or on the driver.
  bool get isOpen =>
      this == FulfilmentStage.ordered ||
      this == FulfilmentStage.prepared ||
      this == FulfilmentStage.checked;

  /// Gone from the warehouse -- collected, delivered, or called off.
  bool get isClosed => !isOpen;

  bool get isFinished =>
      this == FulfilmentStage.delivered || this == FulfilmentStage.cancelled;

  /// Position on the five-step timeline, or -1 for a cancelled order which
  /// does not sit anywhere on it.
  int get step => switch (this) {
        FulfilmentStage.ordered => 0,
        FulfilmentStage.prepared => 1,
        FulfilmentStage.checked => 2,
        FulfilmentStage.pickedUp => 3,
        FulfilmentStage.delivered => 4,
        FulfilmentStage.cancelled => -1,
      };
}

/// The timeline, in order, without the off-path `cancelled`.
const kStageTimeline = [
  FulfilmentStage.ordered,
  FulfilmentStage.prepared,
  FulfilmentStage.checked,
  FulfilmentStage.pickedUp,
  FulfilmentStage.delivered,
];

/// The queues this app puts on screen, in the order staff work them.
const kStaffQueues = [
  FulfilmentStage.ordered,
  FulfilmentStage.prepared,
  FulfilmentStage.checked,
];

/// Reads a stage back from the wire (or from disk), falling back rather than
/// throwing: an unknown value means the backend grew a stage this build predates,
/// and one unexpected order should not take the whole list down.
FulfilmentStage stageFromApi(Object? value, {
  FulfilmentStage fallback = FulfilmentStage.ordered,
}) {
  for (final stage in FulfilmentStage.values) {
    if (stage.apiValue == value) return stage;
  }
  return fallback;
}
