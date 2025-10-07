// 📁 lib/ui/screens/home/Pc/ads_files/add_item_screen/widgets/image_section.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

mixin ImageSectionMixin<T extends StatefulWidget> on State<T> {
  late final GlobalKey<FormState> _formKey;

  @protected
  PageController get imageSectionPageController;

  // -------------------- واجهة الصور (متجاوبة) --------------------
  Widget itemImagesListener({
    required BuildContext context,
    required List<dynamic> mixedItemImageList,
    required bool isUploadingExtra,
    required dynamic itemImagePicker,
    required void Function(ImageSource source) onPick,
    required void Function(int index) onRemove,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final pageController = imageSectionPageController;

    return LayoutBuilder(
      builder: (context, constraints) {
        // أبعاد الشاشة
        final width = constraints.maxWidth.clamp(240.0, 5000.0);
        final isPhone = width < 600;
        final isSmallPhone = width < 360;
        final isTablet = width >= 600 && width < 1024;

        // أبعاد متكيفة للبلاط
        final double targetTile =
            isSmallPhone ? 96 : (isPhone ? 112 : (isTablet ? 140 : 180));

        // حواف الشبكة والمسافات
        const double gridHPad = 8;
        const double gridSpacing = 14;

        // حساب الأعمدة حسب العرض الفعلي
        final int columns = width <= 340
            ? 2
            : ((width - (gridHPad * 2)) / (targetTile + gridSpacing))
                .floor()
                .clamp(3, 7);

        // عدد الصفوف حسب الجهاز (هنا 2 للموبايل، 3 لغيره)
        final int rows = isPhone ? 2 : 3;

        // حساب عرض البلاط الحقيقي بعد توزيع الأعمدة
        final double tileWidth =
            ((width - (gridHPad * 2) - (gridSpacing * (columns - 1))) / columns)
                .clamp(72.0, 320.0);

        // ارتفاع البلاط (مربع تقريباً)
        final double tileHeight = tileWidth;

        // ارتفاع الشبكة الكامل (للسلايدر)
        final double gridHeight =
            (rows * tileHeight) + ((rows - 1) * gridSpacing) + 2;

        // عدد عناصر الصفحة
        final imageCount = mixedItemImageList.length;
        final showAddButton = imageCount < 25;
        final totalItems = imageCount + (showAddButton ? 1 : 0);

        // صور لكل صفحة = أعمدة × صفوف
        final imagesPerPage = (columns * rows).clamp(1, 25);
        final totalPages = (totalItems / imagesPerPage).ceil().clamp(1, 99);

        List<Widget> buildPageItems(int pageIndex) {
          final widgets = <Widget>[];
          final startIndex = pageIndex * imagesPerPage;
          final endIndex = (startIndex + imagesPerPage).clamp(0, totalItems);

          for (int i = startIndex; i < endIndex; i++) {
            final isAdd = (i == imageCount) && showAddButton;

            if (isAdd) {
              widgets.add(
                _AddTile(
                  color: color,
                  onTap: () {
                    if (mixedItemImageList.length >= 25) {
                      HelperUtils.showSnackBarMessage(
                          context, "🚫 لا يمكنك إضافة أكثر من 25 صورة");
                      return;
                    }
                    showImageSourceDialog(context, onPick);
                  },
                ),
              );
              continue;
            }

            if (i < imageCount) {
              final image = mixedItemImageList[i];
              final bool isUploading =
                  image is Map && image["uploading"] == true;

              int? imageId;
              if (image is Map) {
                final dynamic rawId = image['id'];
                if (rawId is int) {
                  imageId = rawId;
                } else if (rawId is String) {
                  imageId = int.tryParse(rawId);
                }
              }

              bool isMain = false;
              if (image is Map && image['isMain'] == true) {
                isMain = true;
              } else if (!isMain && i == 0) {
                isMain = true;
              }

              ImageProvider<Object>? imageProvider;
              if (image is Map) {
                final dynamic fileValue = image['file'];
                if (fileValue is File) {
                  imageProvider = FileImage(fileValue);
                } else {
                  final dynamic urlValue = image['url'];
                  if (urlValue is String && urlValue.isNotEmpty) {
                    imageProvider = NetworkImage(urlValue);
                  }
                }
              } else if (image is String) {
                imageProvider = NetworkImage(image);
              } else if (image is File) {
                imageProvider = FileImage(image);
              }

              widgets.add(
                _ImageTile(
                  key: ValueKey(imageId ?? 'local_$i'),
                  id: imageId,
                  imageProvider: imageProvider,
                  isMain: isMain,
                  isUploading: isUploading,
                  color: color,
                  onOpen: () {
                    if (imageProvider == null) {
                      HelperUtils.showSnackBarMessage(
                          context, "الصورة لم تجهز بعد");
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ImageGalleryScreen(
                          images: mixedItemImageList,
                          initialIndex: i,
                        ),
                      ),
                    );
                  },
                  onRemove: () {
                    onRemove(i);
                    HelperUtils.showSnackBarMessage(context, "تم حذف الصورة");
                  },
                ),
              );
            }
          }

          // إكمال الصفحة بخانات منقطة (شكل ثابت نظيف)
          while (widgets.length < imagesPerPage) {
            widgets.add(_PlaceholderTile(color: color));
          }

          return widgets;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 6),
              child: Text(
                " اضف صور لأعلانك ",
                style: theme.textTheme.titleMedium,
              ),
            ),

            // السلايدر (ارتفاع متكيف)
            SizedBox(
              height: gridHeight,
              child: PageView.builder(
                controller: pageController,
                itemCount: totalPages,
                itemBuilder: (context, pageIndex) {
                  final items = buildPageItems(pageIndex);
                  return GridView.count(
                    crossAxisCount: columns,
                    padding: const EdgeInsets.symmetric(horizontal: gridHPad),
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                    childAspectRatio: tileWidth / tileHeight,
                    children: items,
                  );
                },
              ),
            ),

            // مؤشر الصفحات (أحجام متكيفة)
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: SmoothPageIndicator(
                    controller: pageController,
                    count: totalPages,
                    effect: ExpandingDotsEffect(
                      dotHeight: isPhone ? 7 : 9,
                      dotWidth: isPhone ? 7 : 9,
                      spacing: 6,
                      expansionFactor: 3,
                      activeDotColor: color.primary,
                      dotColor: color.outline.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // -------------------- حوار اختيار المصدر --------------------
  Future<void> showImageSourceDialog(
    BuildContext context,
    Function(ImageSource) onSelected,
  ) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.rw(context)),
            ),
            title: Text(
              'selectImageSource'.translate(context),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.font.large,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt,
                      color: Colors.deepOrange, size: 28.rw(context)),
                  title: Text('camera'.translate(context),
                      style: TextStyle(fontSize: context.font.normal)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library,
                      color: Colors.teal, size: 28.rw(context)),
                  title: Text('gallery'.translate(context),
                      style: TextStyle(fontSize: context.font.normal)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// -------------------- Widgets داخلية صغيرة (نظيفة) --------------------

class _AddTile extends StatelessWidget {
  const _AddTile({required this.color, required this.onTap});

  final ColorScheme color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      dashPattern: const [6, 4],
      color: color.outline.withOpacity(0.4),
      strokeWidth: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.surface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add,
                      size: 22, color: color.outline.withOpacity(0.55)),
                  const SizedBox(width: 6),
                  Text(
                    "أضف صورة",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color.outline.withOpacity(0.75),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.color});
  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      dashPattern: const [6, 4],
      color: color.outline.withOpacity(0.2),
      strokeWidth: 1,
      child: Container(
        decoration: BoxDecoration(
          color: color.surface.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    this.id,
    required this.imageProvider,
    required this.isMain,
    required this.isUploading,
    required this.color,
    required this.onOpen,
    required this.onRemove,
  });
  final int? id;
  final ImageProvider<Object>? imageProvider;
  final bool isMain;
  final bool isUploading;
  final ColorScheme color;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // صورة + إطار + ظل
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpen,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider!, fit: BoxFit.cover)
                    : null,
                border: Border.all(
                  color: isMain ? color.primary : color.outline.withOpacity(.6),
                  width: isMain ? 2.2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: isUploading
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // تاج "أساسية"
        if (isMain)
          PositionedDirectional(
            top: 6,
            start: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "أساسية",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

        // زر حذف
        PositionedDirectional(
          top: 4,
          end: 4,
          child: Material(
            color: Colors.black45,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- معرض الصور (متجاوب) --------------------

class ImageGalleryScreen extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const ImageGalleryScreen({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _controller;
  late final ValueNotifier<int> _currentIndexNotifier;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _currentIndexNotifier = ValueNotifier(widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 600;

    final dotSize = isPhone ? 8.0 : 10.0;
    final chromePad = isPhone ? 12.0 : 16.0;

    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.images.length,
            builder: (context, index) {
              final image = widget.images[index];
              ImageProvider<Object>? provider;

              if (image is Map) {
                final dynamic fileValue = image['file'];
                if (fileValue is File) {
                  provider = FileImage(fileValue);
                } else {
                  final dynamic urlValue = image['url'];
                  if (urlValue is String && urlValue.isNotEmpty) {
                    provider = NetworkImage(urlValue);
                  }
                }
              } else if (image is String) {
                provider = NetworkImage(image);
              } else if (image is File) {
                provider = FileImage(image);
              }

              if (provider == null) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white70, size: 42),
                  ),
                );
              }

              return PhotoViewGalleryPageOptions(
                imageProvider: provider,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.0,
              );
            },
            onPageChanged: (index) => _currentIndexNotifier.value = index,
            loadingBuilder: (context, _) =>
                const Center(child: CircularProgressIndicator()),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),

          // إغلاق
          PositionedDirectional(
            top: paddingTop + chromePad,
            start: chromePad,
            child: _circleBtn(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // رجوع
          PositionedDirectional(
            top: paddingTop + chromePad,
            end: chromePad,
            child: _circleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // مؤشّر الصفحات
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: EdgeInsets.symmetric(horizontal: isPhone ? 64 : 120),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentIndexNotifier,
                  builder: (_, currentIndex, __) {
                    return AnimatedSmoothIndicator(
                      activeIndex: currentIndex,
                      count: widget.images.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: dotSize,
                        dotWidth: dotSize,
                        spacing: 6,
                        expansionFactor: 3,
                        activeDotColor: color.primary,
                        dotColor: color.onSurface.withOpacity(0.3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    final color = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color.onSurface, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
