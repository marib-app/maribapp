import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/utils/hive_utils.dart';

const List<String> _tabs = ['الكل', 'بيع', 'شراء', 'غير مقروء'];

/// شاشة قائمة الدردشات الجديدة مع شريط بحث وفلاتر (الكل/بيع/شراء/غير مقروء).
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0; // 0: الكل، 1: بيع، 2: شراء، 3: غير مقروء

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text == _searchQuery) return;
      setState(() => _searchQuery = text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('الدردشات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث في الرسائل أو الأسماء...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final selected = _tabIndex == i;
                      final Color baseBg = const Color(0xFFE5E5E5);
                      final Color selectedBg = const Color(0xFFD6D6D6);
                      final Color borderColor = const Color(0xFFB0B0B0);
                      final Color textColor = const Color(0xFF4A4A4A);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(_tabs[i]),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _tabIndex = i),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: selected
                                  ? borderColor
                                  : borderColor.withOpacity(0.8),
                              width: 1.1,
                            ),
                          ),
                          selectedColor: selectedBg,
                          backgroundColor: baseBg,
                          labelStyle: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<ChatedUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ أثناء تحميل الدردشات\n${snapshot.error}'),
            );
          }
          final List<ChatedUser> data = snapshot.data ?? <ChatedUser>[];
          final String query = _searchQuery.toLowerCase();
          final List<ChatedUser> filtered = data.where((chat) {
            final bool matchesTab = switch (_tabIndex) {
              1 => chat.sellerId == _currentUserId, // بيع
              2 => chat.buyerId == _currentUserId, // شراء
              3 => (chat.unreadMessagesCount ?? 0) > 0, // غير مقروء
              _ => true, // الكل
            };
            if (!matchesTab) return false;

            if (query.isEmpty) return true;
            final name =
                (chat.buyer?.name ?? chat.seller?.name ?? '').toLowerCase();
            final lastMsg =
                (chat.lastMessage?.message ?? '').toLowerCase();
            final itemName = (chat.item?.name ?? '').toLowerCase();
            return name.contains(query) ||
                lastMsg.contains(query) ||
                itemName.contains(query);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('لا توجد نتائج مطابقة حالياً'));
          }
          return ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = filtered[index];
              final _ResolvedChat resolved =
                  _resolveChat(chat, currentUserId: _currentUserId);
              if (!resolved.isValid) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: (resolved.avatarUrl != null &&
                          resolved.avatarUrl!.isNotEmpty)
                      ? NetworkImage(resolved.avatarUrl!)
                      : null,
                  child: (resolved.avatarUrl == null ||
                          resolved.avatarUrl!.isEmpty)
                      ? Text(
                          resolved.title.isNotEmpty
                              ? resolved.title.characters.first
                              : '?',
                          style: const TextStyle(color: Colors.black87),
                        )
                      : null,
                ),
                title: Text(resolved.title.isEmpty ? 'مستخدم' : resolved.title),
                subtitle: Text(
                  resolved.lastMessage ?? 'لا توجد رسائل بعد',
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
    this.avatarUrl,
    this.lastMessage,
  });
  final bool isValid;
  final String conversationId;
  final int senderId;
  final int receiverId;
  final int? itemOfferId;
  final int? itemId;
  final String title;
  final String? avatarUrl;
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
    receiverId = seller ?? buyer;
  }
  if (receiverId == null) {
    return _ResolvedChat(isValid: false);
  }
  final String conversationId =
      chat.conversationId ??
          chat.itemOfferId?.toString() ??
          chat.id?.toString() ??
          '';
  if (conversationId.isEmpty) {
    return _ResolvedChat(isValid: false);
  }
  // اسم الطرف الآخر فقط
  final String title = () {
    if (currentUserId == buyer) {
      return chat.seller?.name ?? '';
    }
    if (currentUserId == seller) {
      return chat.buyer?.name ?? '';
    }
    return chat.seller?.name ?? chat.buyer?.name ?? '';
  }();
  // صورة الطرف الآخر فقط
  final String? avatarUrl = () {
    // أولاً جرّب الطرف الآخر (مباشر)
    String? direct;
    if (currentUserId == buyer) {
      direct = chat.seller?.profile;
    } else if (currentUserId == seller) {
      direct = chat.buyer?.profile;
    } else {
      direct = chat.seller?.profile ?? chat.buyer?.profile;
    }
    // ثانياً جرّب المشاركين (أول مستخدم ليس هو الحالي)
    if ((direct == null || direct.isEmpty) && chat.participants != null) {
      final other = chat.participants!
          .firstWhere((p) => p.userId != null && p.userId != currentUserId,
              orElse: () => ChatParticipant());
      if (other.profile != null && other.profile!.isNotEmpty) {
        direct = other.profile;
      }
    }
    return direct;
  }();
  final String? lastMsg = chat.lastMessage?.message;
  return _ResolvedChat(
    isValid: true,
    conversationId: conversationId,
    senderId: senderId ?? currentUserId,
    receiverId: receiverId,
    itemOfferId: chat.itemOfferId,
    itemId: chat.itemId,
    title: title,
    avatarUrl: avatarUrl,
    lastMessage: lastMsg,
  );
}
