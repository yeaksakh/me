import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/fulfilment_stage.dart';

void main() {
  group('Wire values', () {
    // The one that bites: the ERP stores "picked up" as `shipped`, and a
    // `stage.name` slipping into a request would ask for a status that does not
    // exist.
    test('picked up travels as shipped, the ERP value', () {
      expect(FulfilmentStage.pickedUp.apiValue, 'shipped');
      expect(FulfilmentStage.pickedUp.label, 'Picked up');
    });

    test("the timeline is the website's shipment flow", () {
      expect(
        kStageTimeline.map((stage) => stage.apiValue).toList(),
        ['ordered', 'packed', 'audited', 'shipped', 'delivered'],
      );
    });

    test('every status round-trips through its wire value', () {
      for (final stage in FulfilmentStage.values) {
        expect(stageFromApi(stage.apiValue), stage);
      }
    });

    test('capitalised strays from an older screen still read', () {
      expect(stageFromApi('Packed'), FulfilmentStage.packed);
      expect(stageFromApiOrNull(' Ordered '), FulfilmentStage.ordered);
    });

    test('an unknown value falls back instead of throwing', () {
      expect(stageFromApi('teleported'), FulfilmentStage.ordered);
      expect(stageFromApiOrNull(null), isNull);
      expect(
        stageFromApi(null, fallback: FulfilmentStage.cancelled),
        FulfilmentStage.cancelled,
      );
    });
  });

  group('Staff boundary', () {
    test('staff move ordered to packed and packed to audited, and nothing else',
        () {
      expect(FulfilmentStage.ordered.nextForStaff, FulfilmentStage.packed);
      expect(FulfilmentStage.packed.nextForStaff, FulfilmentStage.audited);
      expect(FulfilmentStage.audited.nextForStaff, isNull);
      expect(FulfilmentStage.pickedUp.nextForStaff, isNull);
      expect(FulfilmentStage.delivered.nextForStaff, isNull);
    });

    test('the flow still runs on with the rider', () {
      expect(FulfilmentStage.audited.next, FulfilmentStage.pickedUp);
      expect(FulfilmentStage.pickedUp.next, FulfilmentStage.delivered);
      expect(FulfilmentStage.delivered.next, isNull);
    });
  });

  group('Tabs', () {
    test('the three tabs are the statuses still in the building', () {
      expect(kStaffQueues.every((stage) => stage.isOpen), isTrue);
      expect(FulfilmentStage.pickedUp.isOpen, isFalse);
      expect(FulfilmentStage.delivered.isClosed, isTrue);
    });

    test('cancelled sits nowhere on the timeline', () {
      expect(FulfilmentStage.cancelled.step, -1);
      expect(kStageTimeline.contains(FulfilmentStage.cancelled), isFalse);
    });

    test('timeline steps are in order and contiguous', () {
      for (var index = 0; index < kStageTimeline.length; index++) {
        expect(kStageTimeline[index].step, index);
      }
    });
  });
}
