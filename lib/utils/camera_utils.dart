import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraUtils {
  static ImageFormatGroup getImageFormat() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ImageFormatGroup.nv21;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ImageFormatGroup.bgra8888;
    }
    return ImageFormatGroup.yuv420;
  }

  static ResolutionPreset getResolution(CameraDescription camera) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        camera.lensDirection == CameraLensDirection.back) {
      return ResolutionPreset.low;
    }
    return ResolutionPreset.medium;
  }

  static InputImage? inputImageFromCameraImage(
    CameraImage image,
    List<CameraDescription> availableCameras,
    int currentCameraIndex,
  ) {
    try {
      if (currentCameraIndex >= availableCameras.length) return null;

      final camera = availableCameras[currentCameraIndex];
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation rotation;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        var rotationCompensation = _orientations[camera.lensDirection];
        if (rotationCompensation == null) return null;

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }

        rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ??
            InputImageRotation.rotation0deg;
      } else {
        rotation = InputImageRotation.rotation0deg;
      }

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (defaultTargetPlatform == TargetPlatform.iOS &&
          format != InputImageFormat.bgra8888) {
        return null;
      }

      if (image.planes.isEmpty) return null;

      if (image.planes.length == 1) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  static const Map<CameraLensDirection, int> _orientations = {
    CameraLensDirection.back: 90,
    CameraLensDirection.front: 270,
    CameraLensDirection.external: 90,
  };
}