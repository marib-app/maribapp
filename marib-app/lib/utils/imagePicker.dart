// ignore_for_file: unnecessary_getters_setters, file_names

import 'dart:async';
import 'dart:io';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:marib/utils/helper_utils.dart';

class PickImage {
  final ImagePicker _picker = ImagePicker();
  final StreamController _imageStreamController = StreamController.broadcast();

  /// Last payload emitted by the picker (for debugging). It holds the same
  /// map that is added to the stream, e.g. {"error": "", "file": [...]}
  dynamic lastPayload;

  Stream get imageStream => _imageStreamController.stream;

  StreamSink get _sink => _imageStreamController.sink;
  StreamSubscription? subscription;
  File? _pickedFile;

  File? get pickedFile => _pickedFile;

  set pickedFile(File? pickedFile) {
    _pickedFile = pickedFile;
  }

  pick(
      {ImageSource? source,
      bool? pickMultiple,
      int? imageLimit,
      int? maxLength,
      required BuildContext context}) async {
    if (pickMultiple == false || pickMultiple == null) {
      await _picker
          .pickImage(
        source: source ?? ImageSource.gallery,
      )
          .then((XFile? pickedFile) async {
        if (pickedFile != null) {
          File file = File(pickedFile.path);

          if (await file.length() > Constant.maxSizeInBytes) {
            file = await HelperUtils.compressImageFile(file);
          }

          // Ensure internal pickedFile is set (so getters like
          // coverImageFile that rely on pickedFile return a value).
          this.pickedFile = file;

          // store the exact payload for debugging and UI inspection
          lastPayload = {"error": "", "file": [file]};

          if (kDebugMode) {
            // ignore: avoid_print
            print('[debug] PickImage.pick single -> file: ${file.path}');
          }

          _sink.add(lastPayload);
        }
      }).catchError((error) {
        _sink.add({
          "error": error,
          "file": [],
        });
      });
    } else {
      List<XFile> list = await _picker.pickMultiImage(
          imageQuality: Constant.uploadImageQuality, requestFullMetadata: true);

      if (imageLimit != null &&
          maxLength != null &&
          (list.length + maxLength) > imageLimit) {
        HelperUtils.showSnackBarMessage(
            context, "max5ImagesAllowed".translate(context));
      } else {
        Iterable<Future<File>> result = list.map((image) async {
          File myImage = File(image.path);
          if (await myImage.length() > Constant.maxSizeInBytes) {
            myImage = await HelperUtils.compressImageFile(myImage);
          } else {
            myImage = File(image.path);
          }
          return myImage;
        });
        List<File> templistFile = [];
        await for (Future<File> futureFile in Stream.fromIterable(result)) {
          File file = await futureFile;
          templistFile.add(file);
        }

        // Set the pickedFile to the first file so callers that rely on
        // PickImage.pickedFile see a value immediately.
        if (templistFile.isNotEmpty) {
          this.pickedFile = templistFile.first;
        }

        // store payload for debugging/UI
        lastPayload = {"error": "", "file": templistFile};

        if (kDebugMode) {
          // ignore: avoid_print
          print('[debug] PickImage.pick multiple -> files: ${templistFile.map((f) => f.path).toList()}');
        }

        _sink.add(lastPayload);
      }
    }
  }

  /// This widget will listen changes in ui, it is wrapper around Stream builder
  Widget listenChangesInUI(
    dynamic Function(
      BuildContext context,
      List<File>? images,
    ) ondata,
  ) {
    return StreamBuilder(
      stream: imageStream,
      builder: ((context, AsyncSnapshot snapshot) {
        if (snapshot.hasData &&
            snapshot.connectionState == ConnectionState.active) {
          List<File>? files;
          if (snapshot.data['file'] is List) {
            files = (snapshot.data['file'] as List).cast<File>();
          } else if (snapshot.data['file'] is File) {
            files = [snapshot.data['file'] as File];
          }

          pickedFile = files?.isNotEmpty == true ? files![0] : null;

          return ondata.call(context, files);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ondata.call(context, null);
        }
        return ondata.call(context, null);
      }),
    );
  }

  void listener(void Function(dynamic)? onData) {
    subscription?.cancel();
    subscription = imageStream.listen((data) {
      if ((subscription?.isPaused == false)) {
        onData?.call(data['file']);
      }
    });
  }


  void removeListener([void Function(dynamic)? onData]) {
    subscription?.cancel();
    subscription = null;
  }


  void pauseSubscription() {
    subscription?.pause();
  }

  void resumeSubscription() {
    subscription?.resume();
  }

  void clearImage() {
    pickedFile = null;
    _sink.add({"file": []});
  }

  void dispose() {
    if (!_imageStreamController.isClosed) {
      _imageStreamController.close();
    }
    subscription?.cancel();
  }
}

enum PickImageStatus { initial, waiting, done, error }
