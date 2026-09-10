import 'package:image_picker/image_picker.dart';

/// The camera, behind a hook.
///
/// Overridable so tests can stand in for it: under `flutter_test` there is no
/// picker to answer, and a button that waits on a photo can never be reached.
class Camera {
  const Camera._();

  /// Takes a photo and returns its path, or null if the person backed out.
  static Future<String?> Function() takePhoto = _fromCamera;

  static Future<String?> _fromCamera() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      // A clock-in selfie is a record, not a portrait, and it goes up over a
      // phone plan.
      maxWidth: 1200,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    return shot?.path;
  }
}
