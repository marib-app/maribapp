part of 'ad_creation_wizard_screen.dart';

extension _MediaStepView on _AdCreationWizardScreenState {
  Widget _buildMediaStep() => _MediaStepContent(screen: this);
}

class _MediaStepContent extends StatelessWidget {
  const _MediaStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_PendingMedia> images = screen._mediaFiles
        .where((media) => media.isImage)
        .toList(growable: false);
    final List<_PendingMedia> videos = screen._mediaFiles
        .where((media) => media.isVideo)
        .toList(growable: false);
    final bool canAddLink =
        screen._videoLinkFieldController.text.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('أضف وسائط إعلانك', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'يمكنك رفع الصور والفيديوهات بشكل مؤقت أو إضافة روابط فيديو قبل الإرسال.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: screen._isPickingImages ? null : screen._pickImages,
              icon: screen._isPickingImages
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.image_outlined),
              label: const Text('إضافة صور'),
            ),
            FilledButton.icon(
              onPressed: screen._isPickingVideo ? null : screen._pickVideo,
              icon: screen._isPickingVideo
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.videocam_outlined),
              label: const Text('إضافة فيديو'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (images.isEmpty && videos.isEmpty)
          screen._buildInfoCard('لم يتم إضافة ملفات وسائط بعد.'),
        if (images.isNotEmpty) ...[
          Text('الصور (${images.length})', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final _PendingMedia media in images)
                _MediaPreviewCard(
                  key: ValueKey<String>('image_${media.file.path}'),
                  media: media,
                  onRemove: () => screen._removeMediaFile(media),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (videos.isNotEmpty) ...[
          Text('الفيديوهات (${videos.length})',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final _PendingMedia media in videos)
                _MediaPreviewCard(
                  key: ValueKey<String>('video_${media.file.path}'),
                  media: media,
                  onRemove: () => screen._removeMediaFile(media),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const Divider(height: 32),
        Text('روابط الفيديو', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: screen._videoLinkFieldController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'أدخل رابط فيديو (يوتيوب أو ملف مباشر)',
                ),
                onChanged: (_) {
                  screen._clearServerFieldError('media');
                  screen.setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canAddLink ? screen._addVideoLink : null,
              icon: const Icon(Icons.add_link),
              label: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (screen._videoLinks.isEmpty)
          Text('لا توجد روابط فيديو مضافة.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final String link in screen._videoLinks)
                InputChip(
                  label: SizedBox(
                    width: 220,
                    child: Text(
                      link,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () => screen._removeVideoLink(link),
                ),
            ],
          ),
      ],
    );
  }
}