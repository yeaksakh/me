import 'package:warehouse/data/auth_api.dart';
import 'package:warehouse/data/shipments_api.dart';
import 'package:warehouse/data/warehouse_repository.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/order.dart';
import 'package:warehouse/models/staff.dart';
import 'package:warehouse/models/stock_item.dart';
import 'package:warehouse/state/stock_controller.dart';
import 'package:warehouse/state/tasks_controller.dart';

const supervisor = Staff(
  id: 's1',
  name: 'Sokha Chan',
  role: StaffRole.supervisor,
  warehouseName: 'Phnom Penh · Main',
  username: 'sokha',
);

const packer = Staff(
  id: 'p1',
  name: 'Sok Dara',
  role: StaffRole.packer,
  warehouseName: 'Test WH',
);

const checker = Staff(
  id: 'c1',
  name: 'Chan Vy',
  role: StaffRole.checker,
  warehouseName: 'Test WH',
);

/// Signs in without the network. Any username works and [password] is the
/// only password that does, so a test can exercise the refusal too.
class FakeAuthApi extends AuthApi {
  FakeAuthApi({this.staff = supervisor, this.password = 'secret'});

  final Staff staff;
  final String password;

  @override
  Future<SignInResult> signIn({
    required String username,
    required String password,
  }) async {
    if (password != this.password) {
      throw AuthException('Wrong username or password.');
    }
    return SignInResult(token: 'test-token', staff: staff);
  }

  @override
  Future<void> signOut(String token) async {}
}

OrderLine buildLine({
  String id = 'ln-1',
  String sku = 'SKU-1',
  String name = 'Widget',
  double quantity = 2,
  bool packed = false,
  String? parentId,
}) =>
    OrderLine(
      id: id,
      sku: sku,
      name: name,
      quantity: quantity,
      parentId: parentId,
      packed: packed,
      packedBy: packed ? StaffRef(id: supervisor.id, name: supervisor.name) : null,
    );

/// A shipment with its items loaded, as an opened one is.
Order buildOrder({
  required String id,
  FulfilmentStage stage = FulfilmentStage.ordered,
  List<OrderLine>? lines,
  PaymentStatus payment = PaymentStatus.paid,
  DateTime? placedAt,
  String? preparedById,
  String preparedByName = 'Sokha Chan',
  String note = '',
}) {
  final items = lines ?? [buildLine()];
  return Order(
    id: id,
    code: 'YK-$id',
    customerName: 'Customer $id',
    placedAt: placedAt ?? DateTime(2026, 1, 1, 9),
    stage: stage,
    paymentStatus: payment,
    note: note,
    preparedBy: preparedById == null
        ? null
        : StaffRef(id: preparedById, name: preparedByName),
    lineCount: items.length,
    packedCount: items.where((line) => line.packed).length,
    totalQuantity: items.fold(0, (sum, line) => sum + line.quantity),
    lines: items,
    hasDetail: true,
  );
}

/// The shipments server in memory, with its rules: only an ordered shipment is
/// accepted and never out from under someone, only its packer ticks, Packed waits
/// for every item, and nothing moves past Audited.
class FakeShipmentsApi extends ShipmentsApi {
  FakeShipmentsApi({List<Order>? orders, this.staff = supervisor})
      : _orders = {
          for (final order in orders ?? [buildOrder(id: '1')]) order.id: order,
        };

  /// Who the fake server believes is signed in.
  final Staff staff;
  final Map<String, Order> _orders;

  /// Set to answer the next list as an expired session would.
  bool expired = false;

  Order? stored(String id) => _orders[id];

  Order _find(String id) {
    final order = _orders[id];
    if (order == null) {
      throw ShipmentsException('No such shipment.', status: 404);
    }
    return order;
  }

  Order _save(Order order) => _orders[order.id] = order;

  StaffRef get _me => StaffRef(id: staff.id, name: staff.name);

  @override
  Future<ShipmentPage> list(FulfilmentStage stage, {int limit = 100}) async {
    if (expired) {
      throw ShipmentsException('This API token has expired.', status: 401);
    }
    final counts = <FulfilmentStage, int>{};
    for (final order in _orders.values) {
      counts[order.stage] = (counts[order.stage] ?? 0) + 1;
    }
    final orders = _orders.values.where((order) => order.stage == stage).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return ShipmentPage(orders: orders, counts: counts);
  }

  @override
  Future<Order> detail(String id) async => _find(id);

  @override
  Future<Order> accept(String id) async {
    final order = _find(id);
    if (order.stage != FulfilmentStage.ordered) {
      throw ShipmentsException('Only an ordered shipment can be accepted.',
          status: 409);
    }
    final holder = order.preparedBy;
    if (holder != null && holder.id != staff.id) {
      throw ShipmentsException('Already accepted by ${holder.name}.',
          status: 409);
    }
    return _save(order.copyWith(preparedBy: _me));
  }

  @override
  Future<Order> release(String id) async {
    final order = _find(id);
    if (!order.isAcceptedBy(staff.id)) {
      throw ShipmentsException('You have not accepted this shipment.',
          status: 409);
    }
    if (order.packedCount > 0) {
      throw ShipmentsException(
          'Items are already packed. Untick them before handing it back.',
          status: 409);
    }
    return _save(order.copyWith(clearPreparedBy: true));
  }

  @override
  Future<Order> packLine(String id, String lineId,
      {required bool packed}) async {
    final order = _find(id);
    if (order.stage != FulfilmentStage.ordered) {
      throw ShipmentsException('Packing is finished for this shipment.',
          status: 409);
    }
    if (!order.isAccepted) {
      throw ShipmentsException('Accept this shipment before packing it.',
          status: 409);
    }
    if (!order.isAcceptedBy(staff.id)) {
      throw ShipmentsException('Someone else is packing this shipment.',
          status: 409);
    }
    final lines = [
      for (final line in order.lines)
        line.id == lineId
            ? line.copyWith(
                packed: packed,
                packedBy: packed ? _me : null,
                clearPackedBy: !packed,
              )
            : line,
    ];
    return _save(order.copyWith(lines: lines));
  }

  @override
  Future<Order> setStatus(String id, FulfilmentStage stage) async {
    final order = _find(id);
    if (order.stage.nextForStaff != stage) {
      throw ShipmentsException('This shipment cannot be moved to that status.',
          status: 409);
    }
    if (stage == FulfilmentStage.packed && !order.isFullyPacked) {
      throw ShipmentsException('Tick every item before marking it packed.',
          status: 409);
    }
    return _save(order.copyWith(stage: stage));
  }
}

StockItem buildStock({
  String id = 'stk-1',
  String sku = 'SKU-1',
  String name = 'Widget',
  String? barcode = 'BC-1',
  int onHand = 10,
  int reserved = 0,
  int reorderLevel = 0,
}) =>
    StockItem(
      id: id,
      sku: sku,
      name: name,
      barcode: barcode,
      onHand: onHand,
      reserved: reserved,
      reorderLevel: reorderLevel,
    );

WarehouseRepository repositoryWith({List<StockItem>? stock}) =>
    WarehouseRepository(initialStock: stock ?? [buildStock()])
      ..latency = Duration.zero;

/// A tasks controller over [orders], with every tab loaded.
Future<TasksController> tasksWith(
  List<Order> orders, {
  Staff staff = supervisor,
}) async {
  final controller =
      TasksController(FakeShipmentsApi(orders: orders, staff: staff));
  await controller.refreshAll();
  return controller;
}

/// A loaded stock controller over [stock].
Future<StockController> stockWith(List<StockItem> stock) async {
  final controller = StockController(repositoryWith(stock: stock));
  await controller.load();
  return controller;
}
