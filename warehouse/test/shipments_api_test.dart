import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/data/shipments_api.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/order.dart';

/// One shipment, shaped exactly as `core/api/views_shipments.py` sends it.
Map<String, dynamic> shipmentJson({bool withItems = false}) => {
      'id': 118,
      'invoice_no': 'YK-118',
      'ordered_at': '2026-09-10T02:15:00+00:00',
      'shipping_status': 'ordered',
      'customer': 'Dara Shop',
      'customer_name': 'Dara',
      'customer_phone': '',
      'address': '',
      'location': {'id': 3, 'name': 'Main'},
      'prepared_by': {'id': 42, 'name': 'Sok Dara'},
      'accepted_at': '2026-09-10T09:15:00+07:00',
      'packed_at': null,
      'packed_by_name': '',
      'audited_at': null,
      'audited_by_name': '',
      'line_count': 2,
      'packed_count': 1,
      'total_quantity': 3.0,
      'payment_status': 'partial',
      'total': 7.5,
      'due': 2.5,
      'note': 'fragile',
      if (withItems) ...{
        'shipping_details': '',
        'status_log': <String, dynamic>{},
        'items': [
          {
            'id': 900,
            'parent_id': null,
            'product_id': 5,
            'product': 'Jasmine rice',
            'variation': null,
            'sku': 'RICE-5',
            'quantity': 2.0,
            'image': '',
            'rack': 'A',
            'row': '01',
            'position': '2',
            'current_stock': 10.0,
            'packed': true,
            'packed_by': {'id': 42, 'name': 'Sok Dara'},
            'packed_at': '2026-09-10T03:00:00+00:00',
          },
          {
            'id': 901,
            'parent_id': 900,
            'product_id': 6,
            'product': 'Fish sauce',
            'variation': '700 ml',
            'sku': '',
            'quantity': 1.5,
            'image': 'http://example.test/img.webp',
            'rack': '',
            'row': '',
            'position': '',
            'current_stock': null,
            'packed': false,
            'packed_by': null,
            'packed_at': null,
          },
        ],
        'photos': [
          {
            'id': 1,
            'url': 'http://example.test/p.webp',
            'stage': 'packed',
            'taken_at': '2026-09-10T03:00:00+00:00',
          },
        ],
      },
    };

ShipmentsApi apiAnswering(
        http.Response Function(http.Request request) answer) =>
    ShipmentsApi(
      baseUrl: () => 'https://yeaksa.com',
      token: () => 'tok-123',
      httpClient: MockClient((request) async => answer(request)),
    );

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Matcher throwsShipments({Object? message, int? status, String? code}) =>
    throwsA(
      isA<ShipmentsException>()
          .having((e) => e.message, 'message', message ?? anything)
          .having((e) => e.status, 'status', status ?? anything)
          .having((e) => e.code, 'code', code ?? anything),
    );

void main() {
  test('lists one status, newest first, with the Bearer token', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({
        'success': true,
        'data': [shipmentJson()],
        'counts': {'ordered': 4, 'packed': 1, 'audited': 0, 'shipped': 9},
      });
    });

    final page = await api.list(FulfilmentStage.packed);

    expect(sent.method, 'GET');
    expect(sent.url.path, '/api/shipments');
    expect(sent.url.queryParameters['status'], 'packed');
    // No `order`: the server's default is newest first, the website's order.
    expect(sent.url.queryParameters.containsKey('order'), isFalse);
    expect(sent.headers['Authorization'], 'Bearer tok-123');
    expect(page.counts[FulfilmentStage.ordered], 4);
    expect(page.counts[FulfilmentStage.pickedUp], 9);

    final order = page.orders.single;
    expect(order.id, '118');
    expect(order.code, 'YK-118');
    expect(order.customerName, 'Dara Shop');
    expect(order.locationName, 'Main');
    expect(order.preparedBy!.id, '42');
    expect(order.acceptedAt!.toUtc(), DateTime.utc(2026, 9, 10, 2, 15));
    expect(order.packedAt, isNull);
    expect(order.packedCount, 1);
    expect(order.isCashOnDelivery, isTrue);
    expect(order.hasDetail, isFalse);
    expect(order.placedAt.toUtc(), DateTime.utc(2026, 9, 10, 2, 15));
  });

  test('a detail carries items, bundles, shelf positions and photos', () async {
    final api = apiAnswering(
        (_) => json({'success': true, 'data': shipmentJson(withItems: true)}));

    final order = await api.detail('118');
    final rice = order.lines.first;
    final sauce = order.lines.last;

    expect(order.hasDetail, isTrue);
    expect(rice.location, 'Rack A  ·  Row 01  ·  Position 2');
    expect(rice.packed, isTrue);
    expect(rice.packedBy!.name, 'Sok Dara');
    expect(rice.imageUrl, isNull);
    expect(rice.quantityLabel, '2');
    expect(sauce.isBundleItem, isTrue);
    expect(sauce.parentId, '900');
    expect(sauce.displayName, contains('700 ml'));
    expect(sauce.location, isNull);
    expect(sauce.hasLocation, isFalse);
    expect(
      const OrderLine(id: 'x', name: 'x', quantity: 1, rack: 'K').location,
      'Rack K',
    );
    expect(sauce.quantityLabel, '1.5');
    expect(sauce.imageUrl, 'http://example.test/img.webp');
    expect(order.photos.single.stage, FulfilmentStage.packed);
    expect(order.photos.single.takenAt!.toUtc(), DateTime.utc(2026, 9, 10, 3));
  });

  test('ticking an item posts packed to that line', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': shipmentJson(withItems: true)});
    });

    await api.packLine('118', '901', packed: true);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/shipments/118/lines/901/pack');
    expect(jsonDecode(sent.body), {'packed': true});
  });

  test('moving a shipment on posts the ERP status', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': shipmentJson(withItems: true)});
    });

    await api.setStatus('118', FulfilmentStage.packed);

    expect(sent.url.path, '/api/shipments/118/status');
    expect(jsonDecode(sent.body), {'status': 'packed'});
  });

  test("a refusal carries the server's own words", () async {
    final api = apiAnswering((_) => json({
          'success': false,
          'error': 'taken',
          'message': 'Already accepted by Sok Dara.',
        }, 409));

    await expectLater(
      api.accept('118'),
      throwsShipments(
          message: 'Already accepted by Sok Dara.', status: 409, code: 'taken'),
    );
  });

  test('an expired token reads as unauthorized', () async {
    final api = apiAnswering((_) => json({
          'success': false,
          'error': 'expired_token',
          'message': 'This API token has expired.',
        }, 401));

    await expectLater(
      api.list(FulfilmentStage.ordered),
      throwsA(isA<ShipmentsException>()
          .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
    );
  });

  test('a server without these endpoints says so', () async {
    final api =
        apiAnswering((_) => http.Response('<html>Not Found</html>', 404));

    await expectLater(
      api.list(FulfilmentStage.ordered),
      throwsShipments(message: contains('no shipments API')),
    );
  });

  test('no connection is reported as such', () async {
    final api = ShipmentsApi(
      baseUrl: () => 'https://yeaksa.com',
      httpClient: MockClient(
          (_) async => throw http.ClientException('Failed host lookup')),
    );

    await expectLater(
      api.list(FulfilmentStage.ordered),
      throwsShipments(message: contains('Could not reach the server')),
    );
  });

  test('an unknown status in a row falls back rather than failing the list',
      () {
    final order = Order.fromApi({...shipmentJson(), 'shipping_status': null});
    expect(order.stage, FulfilmentStage.ordered);
  });
}
