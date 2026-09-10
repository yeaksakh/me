import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/fulfilment_stage.dart';

void main() {
  group('Wire values', () {
    // The one that bites: the Dart name and the API value differ, and a
    // `stage.name` slipping into a request body would silently filter nothing.
    test('pickedUp goes on the wire as picked_up', () {
      expect(FulfilmentStage.pickedUp.apiValue, 'picked_up');
      expect(FulfilmentStage.pickedUp.name, 'pickedUp');
    });

    test('the five timeline stages match the backend STAGES list', () {
      expect(
        kStageTimeline.map((stage) => stage.apiValue).toList(),
        ['ordered', 'prepared', 'checked', 'picked_up', 'delivered'],
      );
    });

    test('every stage round-trips through the wire value', () {
      for (final stage in FulfilmentStage.values) {
        expect(stageFromApi(stage.apiValue), stage);
      }
    });

    test('an unknown wire value falls back instead of throwing', () {
      expect(stageFromApi('teleported'), FulfilmentStage.ordered);
      expect(
        stageFromApi(null, fallback: FulfilmentStage.cancelled),
        FulfilmentStage.cancelled,
      );
    });
  });

  group('Staff boundary', () {
    test('staff can advance ordered and prepared, and nothing else', () {
      expect(FulfilmentStage.ordered.nextForStaff, FulfilmentStage.prepared);
      expect(FulfilmentStage.prepared.nextForStaff, FulfilmentStage.checked);
      expect(FulfilmentStage.checked.nextForStaff, isNull);
      expect(FulfilmentStage.pickedUp.nextForStaff, isNull);
      expect(FulfilmentStage.delivered.nextForStaff, isNull);
    });

    test('the full pipeline still runs past the warehouse', () {
      expect(FulfilmentStage.checked.next, FulfilmentStage.pickedUp);
      expect(FulfilmentStage.pickedUp.next, FulfilmentStage.delivered);
      expect(FulfilmentStage.delivered.next, isNull);
    });

    test('only prepared and checked are the warehouse to reach', () {
      expect(FulfilmentStage.prepared.isStaffOwned, isTrue);
      expect(FulfilmentStage.checked.isStaffOwned, isTrue);
      expect(FulfilmentStage.pickedUp.isStaffOwned, isFalse);
    });
  });

  group('Queues', () {
    test('the three warehouse queues are the open stages', () {
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
