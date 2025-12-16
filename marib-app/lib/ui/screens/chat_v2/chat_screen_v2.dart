import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_repository_adapter.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_cubit.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_state.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/record_button.dart';

/// شاشة المحادثة V2 المعتمدة على طبقة chat_core الجديدة (رسائل/صور/صوت).
class ChatScreenV2 extends StatefulWidget {
  const ChatScreenV2({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.senderId,
    this.itemOfferId,
    this.itemId,
    this.title,
    this.itemTitle,
    this.itemImage,
    this.itemPrice,
  });

  final String conversationId;
  final int receiverId;
  final int senderId;
  final int? itemOfferId;
  final int? itemId;
  final String? title;
  final String? itemTitle;
  final String? itemImage;
  final double? itemPrice;

  @override
  State<ChatScreenV2> createState() => _ChatScreenV2State();
}

class _ChatScreenV2State extends State<ChatScreenV2>
    with SingleTickerProviderStateMixin {
  late final ChatRepositoryAdapter _repository;
  late final ChatMessagesCubit _messagesCubit;
  late final ScrollController _scrollController;
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<String?> _sendingLocalId = ValueNotifier<String?>(null);
  late final AnimationController _recordController;
  final ChatRepostiory _legacyRepo = ChatRepostiory();
  String? _itemTitle;
  String? _itemImage;
  double? _itemPrice;
  String? _itemCurrency;
  String? _itemStatus;
  int? _itemId;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepositoryAdapter();
    _messagesCubit = ChatMessagesCubit(
      repository: _repository,
      pageLimit: 20,
      itemOfferId: widget.itemOfferId,
    );
    _scrollController = ScrollController()..addListener(_onScroll);
    _recordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textController.addListener(() => setState(() {}));
    _itemTitle = widget.itemTitle;
    _itemImage = widget.itemImage;
    _itemPrice = widget.itemPrice;
    _itemCurrency = null;
    _itemId = widget.itemId;
    _prefetchConversationDetailsIfNeeded();
    _messagesCubit.loadInitial(widget.conversationId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // مع reverse:true الرسائل الأقدم في الأعلى (maxScrollExtent).
    final double distanceToTop =
        (position.maxScrollExtent - position.pixels).clamp(0.0, double.infinity);
    if (distanceToTop <= 20) {
      _messagesCubit.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _sendingLocalId.dispose();
    _recordController.dispose();
    _messagesCubit.close();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _prefetchConversationDetailsIfNeeded() async {
    if ((_itemTitle?.isNotEmpty ?? false) || (_itemImage?.isNotEmpty ?? false)) {
      return;
    }
    final convo = await _legacyRepo.fetchConversationDetails(
      conversationId: widget.conversationId,
      itemOfferId: widget.itemOfferId,
    );
    if (convo?.item != null && mounted) {
      final item = convo!.item!;
      setState(() {
        _itemTitle = item.name ?? _itemTitle;
        _itemImage = item.image ?? _itemImage;
        _itemPrice = item.price ?? _itemPrice;
        _itemCurrency = item.currencySymbol ?? item.currency ?? _itemCurrency;
        _itemStatus = item.status ?? _itemStatus;
        _itemId = item.id ?? _itemId;
      });
    }
  }

  Future<void> _sendText() async {
    final String text = _textController.text.trim();
    if (text.isEmpty || _sendingLocalId.value != null) return;
    final draft = ChatMessageDraft(
      localId: 'local_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
      conversationId: widget.conversationId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      itemOfferId: widget.itemOfferId,
      itemId: widget.itemId,
      text: text,
      filePath: null,
      audioPath: null,
      messageType: 'text',
      createdAt: DateTime.now(),
    );
    _textController.clear();
    _sendingLocalId.value = draft.localId;
    await _messagesCubit.sendMessage(draft);
    _sendingLocalId.value = null;
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingLocalId.value != null) return;
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد إرسال الصورة'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(file.path),
            fit: BoxFit.cover,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final draft = ChatMessageDraft(
      localId: 'img_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
      conversationId: widget.conversationId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      itemOfferId: widget.itemOfferId,
      itemId: widget.itemId,
      text: '',
      filePath: file.path,
      audioPath: null,
      messageType: 'image',
      createdAt: DateTime.now(),
    );
    _sendingLocalId.value = draft.localId;
    await _messagesCubit.sendMessage(draft);
    _sendingLocalId.value = null;
  }

  Future<void> _pickAndSendAudio() async {
    // التسجيل المباشر متوفر عبر RecordButton
    return;
  }

  Future<void> _sendRecordedAudio(String? path) async {
    if (path == null || path.isEmpty || _sendingLocalId.value != null) return;
    final draft = ChatMessageDraft(
      localId: 'aud_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
      conversationId: widget.conversationId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      itemOfferId: widget.itemOfferId,
      itemId: widget.itemId,
      text: '',
      filePath: null,
      audioPath: path,
      messageType: 'audio',
      createdAt: DateTime.now(),
    );
    _sendingLocalId.value = draft.localId;
    await _messagesCubit.sendMessage(draft);
    _sendingLocalId.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _messagesCubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'المحادثة'),
        ),
        body: Column(
          children: [
            Builder(builder: (context) {
              final bool showOffer = (widget.itemOfferId != null &&
                      widget.itemOfferId! > 0) ||
                  (widget.itemId != null && widget.itemId! > 0) ||
                  (_itemTitle?.isNotEmpty ?? false) ||
                  (_itemImage?.isNotEmpty ?? false);
              if (!showOffer) return const SizedBox.shrink();
              final String? currency = _itemCurrency;
              final bool isUnavailable = () {
                final status = (_itemStatus ?? '').toLowerCase();
                return status.contains('sold') ||
                    status.contains('sold out') ||
                    status.contains('inactive') ||
                    status.contains('deleted') ||
                    status.contains('rejected');
              }();
              final ColorScheme colors = Theme.of(context).colorScheme;
              final int? targetId = _itemId ?? widget.itemId;
              final VoidCallback? openDetails = (isUnavailable ||
                      targetId == null ||
                      targetId <= 0)
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        Routes.adDetailsScreen,
                        arguments: {
                          'id': targetId,
                          'model': ItemModel(
                            id: targetId,
                            name: _itemTitle ?? widget.title,
                            price: _itemPrice,
                            image: _itemImage,
                            currency: _itemCurrency,
                            status: _itemStatus,
                          ),
                        },
                      );
                    };
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isUnavailable)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: colors.error.withOpacity(0.35)),
                        ),
                        child: Text(
                          'الإعلان غير متوفر حالياً',
                          style: TextStyle(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    _OfferCard(
                      title: _itemTitle ?? widget.title ?? 'إعلان',
                      imageUrl: _itemImage ?? '',
                      price: _itemPrice,
                      currency: currency,
                      isUnavailable: isUnavailable,
                      onTap: openDetails,
                    ),
                  ],
                ),
              );
            }),
            Expanded(
              child: BlocBuilder<ChatMessagesCubit, ChatMessagesState>(
                builder: (context, state) {
                  if (state.status == ChatMessagesStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ChatMessagesStatus.failure) {
                    return Center(
                      child: Text(state.error ?? 'تعذر تحميل الرسائل'),
                    );
                  }
                  final messages = state.messages;
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return state.isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          final msg = messages[index];
                          final bool isMe = msg.senderId == widget.senderId;
                          final ChatMessageEntity? prevChrono =
                              index + 1 < messages.length
                                  ? messages[index + 1]
                                  : null;
                          final bool showDateChip = _shouldShowDateChip(
                            current: msg,
                            previous: prevChrono,
                          );
                          return ValueListenableBuilder<String?>(
                            valueListenable: _sendingLocalId,
                            builder: (_, sendingId, __) {
                              final bool showSpinner =
                                  sendingId != null && msg.localId == sendingId;
                              return Column(
                                children: [
                                  if (showDateChip)
                                    _DateChip(
                                      label: _formatDateLabel(msg.createdAt),
                                    ),
                                  _MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    showSendingSpinner: showSpinner,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      if (state.isLoadingMore && messages.isEmpty)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'أرفق صورة',
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickAndSendImage,
                    ),
                    if (_textController.text.trim().isEmpty)
                      RecordButton(
                        controller: _recordController,
                        isSending: _sendingLocalId.value != null,
                        callback: (path) async {
                          await _sendRecordedAudio(path as String?);
                        },
                      )
                    else
                      IconButton(
                        tooltip: 'تسجيل صوت',
                        icon: const Icon(Icons.mic_none),
                        onPressed: _pickAndSendAudio,
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageBubbleContent extends StatelessWidget {
  const _ImageBubbleContent({required this.message});

  final ChatMessageEntity message;

  @override
  Widget build(BuildContext context) {
    final String url = message.fileUrl ?? '';
    final bool isLocal = url.isNotEmpty && File(url).existsSync();
    final ImageProvider provider = isLocal
        ? FileImage(File(url))
        : NetworkImage(url) as ImageProvider;

    return GestureDetector(
      onTap: () {
        final state = context.read<ChatMessagesCubit>().state;
        final imageUrls = state.messages
            .where((m) => _MessageBubble.isImageMessage(m))
            .map((m) => m.fileUrl ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullImagePage(
              imageUrls: imageUrls,
              initialUrl: url,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160,
          height: 160,
          child: Image(
            image: provider,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _FullImagePage extends StatefulWidget {
  const _FullImagePage({required this.imageUrls, required this.initialUrl});
  final List<String> imageUrls;
  final String initialUrl;

  @override
  State<_FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<_FullImagePage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.indexOf(widget.initialUrl);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: widget.imageUrls.length,
            itemBuilder: (_, index) {
              final url = widget.imageUrls[index];
              final isLocal = url.isNotEmpty && File(url).existsSync();
              final ImageProvider provider =
                  isLocal ? FileImage(File(url)) : NetworkImage(url) as ImageProvider;
              return Center(
                child: InteractiveViewer(
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.imageUrls.length,
                itemBuilder: (_, index) {
                  final url = widget.imageUrls[index];
                  final isLocal = url.isNotEmpty && File(url).existsSync();
                  final ImageProvider provider = isLocal
                      ? FileImage(File(url))
                      : NetworkImage(url) as ImageProvider;
                  final bool selected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = index);
                      _pageController.jumpToPage(index);
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white54,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image(
                          image: provider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.url, required this.isMe});
  final String url;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final AudioPlayer _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      setState(() {
        _loading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    _player.durationStream.listen((d) {
      if (d != null) {
        setState(() => _duration = d);
      }
    });
    _player.positionStream.listen((p) {
      setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.idle) {
      final String url = widget.url;
      if (url.startsWith('http')) {
        await _player.setUrl(url);
      } else {
        await _player.setFilePath(url);
      }
    }
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color active =
        widget.isMe ? colors.primary : colors.tertiaryContainer;
    final Color inactive = active.withValues(alpha: 0.3);
    final double max =
        _duration.inMilliseconds.toDouble().clamp(1, double.maxFinite);
    final double value = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds == 0 ? 0 : _duration.inMilliseconds)
        .toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _togglePlay,
          child: _loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(active),
                  ),
                )
              : Icon(
                  _player.playing ? Icons.pause : Icons.play_arrow,
                  color: active,
                ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: max,
              onChanged: (v) {
                final seekTo = Duration(milliseconds: v.toInt());
                _player.seek(seekTo);
              },
              activeColor: active,
              inactiveColor: inactive,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _fmt(_position),
          style: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _shouldShowDateChip({
  required ChatMessageEntity current,
  ChatMessageEntity? previous,
}) {
  if (previous == null) return true;
  return !_isSameDay(current.createdAt, previous.createdAt);
}

String _formatDateLabel(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  final DateTime d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'اليوم';
  if (d == yesterday) return 'أمس';
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.title,
    required this.imageUrl,
    this.price,
    this.currency,
    this.isUnavailable = false,
    this.onTap,
  });

  final String title;
  final String imageUrl;
  final double? price;
  final String? currency;
  final bool isUnavailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // إذا كان الإعلان غير متوفر، أظهر تنبيه بدلاً من البطاقة القابلة للنقر.
    if (isUnavailable) {
      return Container(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.error.withOpacity(0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الإعلان غير متوفر (مباع / محذوف / غير نشط)',
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: colors.surfaceVariant,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: colors.surfaceVariant,
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(price!, currency),
                        style: TextStyle(
                          color: colors.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (isUnavailable) ...[
                      const SizedBox(height: 6),
                      Text(
                        'الإعلان غير متوفر',
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double value, String? cur) {
    final String formatted = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    if (cur != null && cur.trim().isNotEmpty) {
      return '$formatted $cur';
    }
    return formatted;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showSendingSpinner = false,
  });

  final ChatMessageEntity message;
  final bool isMe;
  final bool showSendingSpinner;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color bubbleColor =
        isMe ? colors.primary.withValues(alpha: 0.12) : colors.surfaceContainerHighest;
    final Color textColor =
        isMe ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final String statusLabel = _statusText(message.deliveryStatus);
    final bool hasImage = _MessageBubble.isImageMessage(message);
    final bool hasAudio = _isAudioMessage(message);

    return Align(
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if ((message.text ?? '').isNotEmpty)
              Text(
                message.text ?? '',
                style: TextStyle(color: textColor),
              ),
            if (hasImage) ...[
              const SizedBox(height: 8),
              _ImageBubbleContent(message: message),
            ],
            if (hasAudio) ...[
              const SizedBox(height: 8),
              _AudioBubble(
                url: message.audioUrl ?? message.fileUrl ?? '',
                isMe: isMe,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSendingSpinner) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool isImageMessage(ChatMessageEntity msg) {
    final String t = msg.messageType.toLowerCase();
    final String url = (msg.fileUrl ?? '').toLowerCase();
    const exts = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.heic', '.heif'];
    return t.contains('image') || exts.any((ext) => url.endsWith(ext));
  }

  bool _isAudioMessage(ChatMessageEntity msg) {
    final String t = msg.messageType.toLowerCase();
    final String url = (msg.audioUrl ?? msg.fileUrl ?? '').toLowerCase();
    const exts = ['.m4a', '.aac', '.mp3', '.wav'];
    return t.contains('audio') || exts.any((ext) => url.endsWith(ext));
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusText(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return '...';
      case MessageDeliveryStatus.sent:
        return 'مرسلة';
      case MessageDeliveryStatus.delivered:
        return 'وُصلت';
      case MessageDeliveryStatus.read:
        return 'مقروءة';
      case MessageDeliveryStatus.failed:
        return 'فشل';
    }
  }
}
