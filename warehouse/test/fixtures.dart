import 'package:warehouse/data/warehouse_repository.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/order.dart';
import 'package:warehouse/models/staff.dart';
import 'package:warehouse/models/stock_item.dart';
import 'package:warehouse/state/stock_controller.dart';
import 'package:warehouse/state/tasks_controller.dart';

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

OrderLine buildLine({
  String id = 'ln-1',
  String sku = 'SKU-1',
  String name = 'Widget',
  String? barcode = 'BC-1',
  int quantity = 2,
  int picked = 0,
}) =>
    OrderLine(
      id: id,
      sku: sku,
      name: name,
      barcode: barcode,
      quantity: quantity,
      picked: picked,
    );

Order buildOrder({
  required String id,
  FulfilmentStage stage = FulfilmentStage.ordered,
  List<OrderLine>? lines,
  PaymentStatus payment = PaymentStatus.paid,
  DateTime? placedAt,
  String? staffNote,
  DateTime? checkedAt,
  DateTime? preparedAt,
}) =>
    Order(
      id: id,
      code: 'YK-$id',
      customerName: 'Customer $id',
      shippingAddress: '1 Test St',
      lines: lines ?? [buildLine()],
      placedAt: placedAt ?? DateTime(2026, 1, 1, 9),
      paymentStatus: payment,
      stage: stage,
      staffNote: staffNote,
      preparedAt: preparedAt,
      checkedAt: checkedAt,
    );

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

WarehouseRepository repositoryWith({
  List<Order>? orders,
  List<StockItem>? stock,
}) =>
    WarehouseRepository(
      initialOrders: orders ?? [buildOrder(id: '1')],
      initialStock: stock ?? [buildStock()],
    )..latency = Duration.zero;

/// A loaded tasks controller over [orders].
Future<TasksController> tasksWith(List<Order> orders) async {
  final controller = TasksController(repositoryWith(orders: orders));
  await controller.load();
  return controller;
}

/// A loaded stock controller over [stock].
Future<StockController> stockWith(List<StockItem> stock) async {
  final controller = StockController(repositoryWith(stock: stock));
  await controller.load();
  return controller;
}
