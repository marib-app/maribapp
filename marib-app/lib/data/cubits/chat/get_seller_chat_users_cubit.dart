// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';




abstract class GetSellerChatListState {}

class GetSellerChatListInitial extends GetSellerChatListState {}

class GetSellerChatListInProgress extends GetSellerChatListState {}

class GetSellerChatListInternalProcess extends GetSellerChatListState {}

class GetSellerChatListSuccess extends GetSellerChatListState {
  final int total;
  final bool isLoadingMore;
  final bool hasError;
  final int page;
  final List<ChatedUser> chatedUserList;

  GetSellerChatListSuccess({
    required this.total,
    required this.isLoadingMore,
    required this.hasError,
    required this.chatedUserList,
    required this.page,
  });

  GetSellerChatListSuccess copyWith({
    int? total,
    int? currentPage,
    bool? isLoadingMore,
    bool? hasError,
    int? page,
    List<ChatedUser>? chatedUserList,
  }) {
    return GetSellerChatListSuccess(
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      chatedUserList: chatedUserList ?? this.chatedUserList,
      page: page ?? this.page,
    );
  }

/*  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'total': total,
      'isLoadingMore': isLoadingMore,
      'hasError': hasError,
      'chatedUserList': chatedUserList.map((x) => x.toJson()).toList(),
      'page':page
    };
  }

  factory GetSellerChatListSuccess.fromMap(Map<String, dynamic> map) {
    return GetSellerChatListSuccess(
      total: map['total'] as int,
      page: map['page'] as int,
      isLoadingMore: map['isLoadingMore'] as bool,
      hasError: map['hasError'] as bool,
      chatedUserList: List<ChatedUser>.from(
        (map['chatedUserList'] as List<int>).map<ChatedUser>(
          (x) => ChatedUser.fromJson(x as Map<String, dynamic>),
        ),
      ),
    );
  }*/
}

class GetSellerChatListFailed extends GetSellerChatListState {
  final dynamic error;

  GetSellerChatListFailed(this.error);
}

class GetSellerChatListCubit extends Cubit<GetSellerChatListState> {
  GetSellerChatListCubit() : super(GetSellerChatListInitial());
  final ChatRepostiory _chatRepository = ChatRepostiory();

  ///Setting build context for later use
  void setContext(BuildContext context) {
    _chatRepository.setContext(context);
  }

  void fetch() async {
    try {
      emit(GetSellerChatListInProgress());

      DataOutput<ChatedUser> result =
          await _chatRepository.fetchSellerChatList(1);

      emit(
        GetSellerChatListSuccess(
            isLoadingMore: false,
            hasError: false,
            chatedUserList: result.modelList,
            total: result.total,
            page: 1),
      );
      _updateBadge(result.modelList);

    } catch (e) {
      emit(GetSellerChatListFailed(e));
    }
  }

  void addNewChat(ChatedUser user) {
    //this will create new chat in chat list if there is no already
    if (state is GetSellerChatListSuccess) {
      List<ChatedUser> chatedUserList =
          (state as GetSellerChatListSuccess).chatedUserList;

      List<String> _identifiersFor(ChatedUser chat) {
        final identifiers = <String>[];
        if ((chat.conversationId ?? '').isNotEmpty) {
          identifiers.add('conversation:${chat.conversationId}');
        }
        if (chat.itemOfferId != null) {
          identifiers.add('itemOffer:${chat.itemOfferId}');
        }
        if (chat.buyerId != null) {
          identifiers.add('buyer:${chat.buyerId}');
        }
        return identifiers;
      }

      final newChatIdentifiers = _identifiersFor(user);

      bool contains = chatedUserList.any(
            (element) {
          final existingIdentifiers = _identifiersFor(element);
          return existingIdentifiers
              .any((identifier) => newChatIdentifiers.contains(identifier));
        },
      );
      if (contains == false) {
        chatedUserList.insert(0, user);
        emit((state as GetSellerChatListSuccess)
            .copyWith(chatedUserList: chatedUserList));
        _updateBadge(chatedUserList);

      }
    }
  }

  Future<void> loadMore() async {
    try {
      if (state is GetSellerChatListSuccess) {
        if ((state as GetSellerChatListSuccess).isLoadingMore) {
          return;
        }
        emit((state as GetSellerChatListSuccess).copyWith(isLoadingMore: true));

        DataOutput<ChatedUser> result =
            await _chatRepository.fetchSellerChatList(
          (state as GetSellerChatListSuccess).page + 1,
        );

        GetSellerChatListSuccess messagesSuccessState =
            (state as GetSellerChatListSuccess);

        // messagesSuccessState.await.insertAll(0, result.modelList);
        messagesSuccessState.chatedUserList.addAll(result.modelList);
        emit(GetSellerChatListSuccess(
          chatedUserList: messagesSuccessState.chatedUserList,
          page: (state as GetSellerChatListSuccess).page + 1,
          hasError: false,
          isLoadingMore: false,
          total: result.total,
        ));
        _updateBadge(messagesSuccessState.chatedUserList);

      }
    } catch (e) {
      emit((state as GetSellerChatListSuccess)
          .copyWith(isLoadingMore: false, hasError: true));
    }
  }

  bool hasMoreData() {
    if (state is GetSellerChatListSuccess) {
      return (state as GetSellerChatListSuccess).chatedUserList.length <
          (state as GetSellerChatListSuccess).total;
    }

    return false;
  }


  void incrementUnread(String conversationId) {
    if (state is! GetSellerChatListSuccess) return;
    final success = state as GetSellerChatListSuccess;
    final List<ChatedUser> updatedList = success.chatedUserList
        .map((chat) => ChatedUser.fromJson(chat.toJson()))
        .toList();
    final index = updatedList.indexWhere((chat) =>
    (chat.conversationId ?? chat.id?.toString() ?? '') == conversationId);
    if (index == -1) {
      return;
    }
    final current = updatedList[index];
    current.unreadMessagesCount = (current.unreadMessagesCount ?? 0) + 1;
    emit(success.copyWith(chatedUserList: updatedList));
    _updateBadge(updatedList);
  }

  void markConversationRead(String conversationId) {
    if (state is! GetSellerChatListSuccess) return;
    final success = state as GetSellerChatListSuccess;
    final List<ChatedUser> updatedList = success.chatedUserList
        .map((chat) => ChatedUser.fromJson(chat.toJson()))
        .toList();
    final index = updatedList.indexWhere((chat) =>
    (chat.conversationId ?? chat.id?.toString() ?? '') == conversationId);
    if (index == -1) {
      return;
    }
    final current = updatedList[index];
    if ((current.unreadMessagesCount ?? 0) == 0) {
      return;
    }
    current.unreadMessagesCount = 0;
    emit(success.copyWith(chatedUserList: updatedList));
    _updateBadge(updatedList);
  }

  void _updateBadge(List<ChatedUser> list) {
    ChatBadgeController.updateSellerUnread(
      list.fold<int>(0, (sum, chat) => sum + (chat.unreadMessagesCount ?? 0)),
    );
  }



}
