part of "../chat_widget.dart";

class AttachmentMessage extends StatefulWidget {
  final String url;
  final String? messageType;

  const AttachmentMessage({
    super.key,
    required this.url,
    this.messageType,
  });

  @override
  State<AttachmentMessage> createState() => _AttachmentMessageState();
}

class _AttachmentMessageState extends State<AttachmentMessage> {
  bool isFileDownloading = false;
  double persontage = 0;

  static const Set<String> _imageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  bool get _isLocalFile {
    if (widget.url.trim().isEmpty) {
      return false;
    }
    try {
      return File(widget.url).existsSync();
    } catch (_) {
      return false;
    }
  }

  String get _normalizedPath {
    final String raw = widget.url.trim();
    if (raw.isEmpty) {
      return raw;
    }
    final int queryIndex = raw.indexOf('?');
    if (queryIndex == -1) {
      return raw;
    }
    return raw.substring(0, queryIndex);
  }

  bool get _isImageAttachment {
    final String messageType = (widget.messageType ?? '').toLowerCase();
    if (messageType.contains('image') || messageType.contains('photo')) {
      return true;
    }

    final String candidate = _normalizedPath.toLowerCase();
    final int dotIndex = candidate.lastIndexOf('.');
    if (dotIndex == -1) {
      return false;
    }
    final String extension = candidate.substring(dotIndex + 1);
    return _imageExtensions.contains(extension);
  }

  bool get _isRemoteAttachment => !_isLocalFile;

  String get _remoteUrl => HelperUtils.absoluteImage(widget.url);

  ImageProvider? _imageProvider() {
    if (_isLocalFile) {
      final File file = File(widget.url);
      if (file.existsSync()) {
        return FileImage(file);
      }
      return null;
    }
    final String resolved = _remoteUrl;
    if (resolved.isEmpty) {
      return null;
    }
    return CachedNetworkImageProvider(resolved);
  }

  String getExtentionOfFile() {
    final String fileName = getFileName();
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return fileName.substring(dotIndex + 1);
  }

  String getFileName() {
    String candidate = widget.url;
    candidate = candidate.split('?').first;
    candidate = candidate.split('#').first;
    if (candidate.contains('/')) {
      candidate = candidate.split('/').last;
    }
    if (candidate.contains('\\')) {
      candidate = candidate.split('\\').last;
    }
    if (candidate.isEmpty) {
      return 'attachment';
    }
    return candidate;
  }

  Future<void> downloadFile() async {
    if (isFileDownloading) {
      return;
    }
    try {
      final String? downloadPath = await getDownloadPath();
      if (downloadPath == null) {
        HelperUtils.showSnackBarMessage(
          context,
          "fileNotSaved".translate(context),
          type: MessageType.error,
        );
        return;
      }

      final String fileName = getFileName();
      final String destinationPath = "$downloadPath/$fileName";

      if (_isRemoteAttachment) {
        setState(() {
          isFileDownloading = true;
          persontage = 0;
        });

        await Dio().download(
          _remoteUrl,
          destinationPath,
          onReceiveProgress: (int count, int total) {
            if (!mounted) {
              return;
            }
            setState(() {
              persontage = total > 0 ? count / total : 0;
            });
          },
        );
      } else {
        final File sourceFile = File(widget.url);
        await sourceFile.copy(destinationPath);
      }

      HelperUtils.showSnackBarMessage(
        context,
        "fileSavedIn".translate(context),
        type: MessageType.success,
      );
      await OpenFilex.open(destinationPath);
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "errorFileSave".translate(context),
        type: MessageType.error,
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        isFileDownloading = false;
        persontage = 0;
      });
    }
  }

  Future<String?> getDownloadPath() async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        // Put file in global download folder, if for an unknown reason it didn't exist, we fallback
        // ignore: avoid_slow_async_io
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (err) {
      if (kDebugMode) {
        HelperUtils.showSnackBarMessage(
            context, "fileNotSaved".translate(context),
            type: MessageType.success);
      }
    }
    return directory?.path;
  }

  Widget _buildImageAttachment(BuildContext context) {
    final ImageProvider? provider = _imageProvider();
    final Widget imageChild;

    if (provider != null) {
      if (_isLocalFile) {
        imageChild = Image(
          image: provider,
          fit: BoxFit.cover,
        );
      } else {
        imageChild = CachedNetworkImage(
          imageUrl: _remoteUrl,
          fit: BoxFit.cover,
          placeholder: (context, _) => _buildImagePlaceholder(context),
          errorWidget: (context, _, __) => _buildImageError(context),
        );
      }
    } else {
      imageChild = _buildImageError(context);
    }

    final double maxWidth = MediaQuery.of(context).size.width * 0.65;
    final double minWidth = MediaQuery.of(context).size.width * 0.4;
    final double minConstraint = minWidth.clamp(160, 260).toDouble();
    final double maxConstraint = maxWidth.clamp(200, 320).toDouble();

    return GestureDetector(
      onTap: () {
        if (provider != null) {
          UiUtils.showFullScreenImage(context, provider: provider);
        }
      },
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minConstraint,
              maxWidth: maxConstraint,
            ),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageChild,
              ),
            ),
          ),
          if (isFileDownloading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: (persontage > 0 && persontage < 1) ? persontage : null,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else if (_isRemoteAttachment)
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () async {
                    await downloadFile();
                  },
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.download,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      color: context.color.textDefaultColor.withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildImageError(BuildContext context) {
    return Container(
      color: context.color.textDefaultColor.withOpacity(0.12),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: context.color.textLightColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () async {
            await downloadFile();
          },
          child: Container(
            height: 56,
            width: 56,
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              color: context.color.secondaryColor.withOpacity(0.064),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.color.borderColor, width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isFileDownloading && persontage > 0 && persontage < 1) ...[
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.color.territoryColor,
                      value: persontage,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.insert_drive_file_rounded,
                    size: 20,
                    color: context.color.territoryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getExtentionOfFile().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 56,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              getFileName(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: context.color.textDefaultColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_isImageAttachment) {
      return _buildImageAttachment(context);
    }
    return _buildFileAttachment(context);
  }
}
