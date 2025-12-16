import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';

/// Lightweight V2 chat list screen that uses the legacy repository to fetch
/// conversations, then routes into the new ChatScreenV2 stack.
class ChatListScreenV2 extends StatefulWidget {
  const ChatListScreenV2({super.key});

  @override
  State<ChatListScreenV2> createState() => _ChatListScreenV2State();
}

class _ChatListScreenV2State extends State<ChatListScreenV2> {
  final ChatRepostiory _repo = ChatRepostiory();
  late final int _currentUserId =
      int.tryParse(HiveUtils.getUserId() ?? '') ?? 0;
  Future<List<ChatedUser>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<List<ChatedUser>> _loadAll() async {
    final buyer = await _repo.fetchBuyerChatList(1);
    final seller = await _repo.fetchSellerChatList(1);
    final List<ChatedUser> combined = <ChatedUser>[
      ...buyer.modelList,
      ...seller.modelList,
    ];
    combined.sort((a, b) {
      final DateTime? ta = _parse(b.lastMessage?.createdAt ?? b.createdAt);
      final DateTime? tb = _parse(a.lastMessage?.createdAt ?? a.createdAt);
      if (ta != null && tb != null) return ta.compareTo(tb);
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return combined;
  }

  DateTime? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشات (تجريبي V2)'),
      ),
      body: FutureBuilder<List<ChatedUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('تعذر تحميل الدردشات\n${snapshot.error}'),
            );
          }
          final List<ChatedUser> data = snapshot.data ?? <ChatedUser>[];
          if (data.isEmpty) {
            return const Center(child: Text('لا توجد دردشات حالياً'));
          }
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = data[index];
              final _ResolvedChat resolved =
                  _resolveChat(chat, currentUserId: _currentUserId);
              if (!resolved.isValid) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: CircleAvatar(
                  child: Text(resolved.title.isNotEmpty
                      ? resolved.title.characters.first
                      : '?'),
                ),
                title: Text(resolved.title.isEmpty
                    ? 'مستخدم'
                    : resolved.title),
                subtitle: Text(
                  resolved.lastMessage ??
                      'عرض المحادثة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: chat.unreadMessagesCount != null &&
                        (chat.unreadMessagesCount ?? 0) > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (chat.unreadMessagesCount ?? 0).toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.chatV2,
                    arguments: {
                      'conversationId': resolved.conversationId,
                      'receiverId': resolved.receiverId,
                      'senderId': resolved.senderId,
                      'itemOfferId': resolved.itemOfferId,
                      'itemId': resolved.itemId,
                      'title': resolved.title,
                      'itemTitle': chat.item?.name ?? '',
                      'itemImage': chat.item?.image ?? '',
                      'itemPrice': chat.item?.price,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ResolvedChat {
  _ResolvedChat({
    required this.isValid,
    this.conversationId = '',
    this.senderId = 0,
    this.receiverId = 0,
    this.itemOfferId,
    this.itemId,
    this.title = '',
    this.lastMessage,
  });
  final bool isValid;
  final String conversationId;
  final int senderId;
  final int receiverId;
  final int? itemOfferId;
  final int? itemId;
  final String title;
  final String? lastMessage;
}

_ResolvedChat _resolveChat(ChatedUser chat, {required int currentUserId}) {
  final int? seller = chat.sellerId;
  final int? buyer = chat.buyerId;
  int? receiverId;
  int? senderId = currentUserId;
  if (currentUserId == seller) {
    receiverId = buyer;
  } else if (currentUserId == buyer) {
    receiverId = seller;
  } else {
    // Fallback: treat seller as other.
    receiverId = seller ?? buyer;
  }
  if (receiverId == null) {
    return _ResolvedChat(isValid: false);
  }
  final String conversationId =
      chat.conversationId ?? chat.itemOfferId?.toString() ?? chat.id?.toString() ?? '';
  if (conversationId.isEmpty) {
    return _ResolvedChat(isValid: false);
  }
  final String title =
      chat.buyer?.name ?? chat.seller?.name ?? 'محادثة';
  final String? lastMsg = chat.lastMessage?.message;
  return _ResolvedChat(
    isValid: true,
    conversationId: conversationId,
    senderId: senderId ?? currentUserId,
    receiverId: receiverId,
    itemOfferId: chat.itemOfferId,
    itemId: chat.itemId,
    title: title,
    lastMessage: lastMsg,
  );
}
