import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_repository_adapter.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_cubit.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/record_button.dart';
import 'package:just_audio/just_audio.dart';

/// Minimal V2 chat screen wired to the new ChatRepositoryV2 stack.
/// This is isolated from the legacy screens so it can be iterated safely.
class ChatScreenV2 extends StatefulWidget {
  const ChatScreenV2({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.senderId,
    this.itemOfferId,
    this.itemId,
    this.title,
  });

  final String conversationId;
  final int receiverId;
  final int senderId;
  final int? itemOfferId;
  final int? itemId;
  final String? title;

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

  @override
  void initState() {
    super.initState();
    _repository = ChatRepositoryAdapter();
    _messagesCubit = ChatMessagesCubit(repository: _repository, pageLimit: 20);
    _scrollController = ScrollController()..addListener(_onScroll);
    _recordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textController.addListener(() => setState(() {}));
    _messagesCubit.loadInitial(widget.conversationId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 12) {
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
    // Fallback to record button flow; FilePicker not used here.
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
                          return ValueListenableBuilder<String?>(
                            valueListenable: _sendingLocalId,
                            builder: (_, sendingId, __) {
                              final bool showSpinner =
                                  sendingId != null && msg.localId == sendingId;
                              return _MessageBubble(
                                message: msg,
                                isMe: isMe,
                                showSendingSpinner: showSpinner,
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullImagePage(imageProvider: provider),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Image(
            image: provider,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _FullImagePage extends StatelessWidget {
  const _FullImagePage({required this.imageProvider});
  final ImageProvider imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
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
    final double max = _duration.inMilliseconds.toDouble().clamp(1, double.maxFinite);
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
    final bool hasImage = _isImageMessage(message);
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

  bool _isImageMessage(ChatMessageEntity msg) {
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
