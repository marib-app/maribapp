import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:marib/utils/extensions/extensions.dart';

//This will open image crop SDK
class CropImage {

  static Future<CroppedFile?>? crop(
      BuildContext context, {
        required String filePath,
      }) async {
    final territoryColor = context.color.territoryColor;


    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: territoryColor,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: false,
          activeControlsWidgetColor: territoryColor,
          lockAspectRatio: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
        IOSUiSettings(
          title: 'Cropper',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    return croppedFile;
  }
}
