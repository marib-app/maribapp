import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/seller_ratings_model.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';

abstract class GetBuyerChatListState {}

class GetBuyerChatListInitial extends GetBuyerChatListState {}

class GetBuyerChatListInProgress extends GetBuyerChatListState {}

class GetBuyerChatListInternalProcess extends GetBuyerChatListState {}

class GetBuyerChatListSuccess extends GetBuyerChatListState {
  final int total;
  final bool isLoadingMore;
  final bool hasError;
  final int page;
  final List<ChatedUser> chatedUserList;

  GetBuyerChatListSuccess({
    required this.total,
    required this.isLoadingMore,
    required this.hasError,
    required this.chatedUserList,
    required this.page,
  });

  GetBuyerChatListSuccess copyWith({
    int? total,
    int? currentPage,
    bool? isLoadingMore,
    bool? hasError,
    int? page,
    List<ChatedUser>? chatedUserList,
  }) {
    return GetBuyerChatListSuccess(
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      chatedUserList: chatedUserList ?? this.chatedUserList,
      page: page ?? this.page,
    );
  }
}

class GetBuyerChatListFailed extends GetBuyerChatListState {
  final dynamic error;

  GetBuyerChatListFailed(this.error);
}

class GetBuyerChatListCubit extends Cubit<GetBuyerChatListState> {
  GetBuyerChatListCubit() : super(GetBuyerChatListInitial());
  final ChatRepostiory _chatRepository = ChatRepostiory();

  ///Setting build context for later use
  void setContext(BuildContext context) {
    _chatRepository.setContext(context);
  }

  void fetch() async {
    try {
      emit(GetBuyerChatListInProgress());

      DataOutput<ChatedUser> result =
          await _chatRepository.fetchBuyerChatList(1);

      emit(
        GetBuyerChatListSuccess(
            isLoadingMore: false,
            hasError: false,
            chatedUserList: result.modelList,
            total: result.total,
            page: 1),
      );
      _updateBadge(result.modelList);
    } catch (e) {
      emit(GetBuyerChatListFailed(e));
    }
  }

  void addNewChat(ChatedUser user) {
    //this will create new chat in chat list if there is no already
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> chatedUserList =
          (state as GetBuyerChatListSuccess).chatedUserList;
      bool contains = chatedUserList.any(
        (element) => element.itemId == user.itemId,
      );
      if (contains == false) {
        chatedUserList.insert(0, user);
        emit((state as GetBuyerChatListSuccess)
            .copyWith(chatedUserList: chatedUserList));
        _updateBadge(chatedUserList);
      }
    }
  }

  void updateAlreadyReview(int itemId) {
    //this will create new chat in chat list if there is no already
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> chatedUserList =
          (state as GetBuyerChatListSuccess).chatedUserList;
      int index =
          chatedUserList.indexWhere((element) => element.itemId == itemId);

      if (index < 0) {
        return;
      }

      final item = chatedUserList[index].item;
      if (item == null) {
        return;
      }

      final rating = UserRatings(
        sellerId: chatedUserList[index].sellerId,
        itemId: itemId,
        buyerId: chatedUserList[index].buyerId,
      );
      item
        ..review = rating
        ..reviews = [rating];
      if (!isClosed) {
        emit((state as GetBuyerChatListSuccess)
            .copyWith(chatedUserList: chatedUserList));
      }
    }
  }

  Future<void> loadMore() async {
    try {
      if (state is GetBuyerChatListSuccess) {
        if ((state as GetBuyerChatListSuccess).isLoadingMore) {
          return;
        }
        emit((state as GetBuyerChatListSuccess).copyWith(isLoadingMore: true));

        DataOutput<ChatedUser> result =
            await _chatRepository.fetchBuyerChatList(
          (state as GetBuyerChatListSuccess).page + 1,
        );

        GetBuyerChatListSuccess messagesSuccessState =
            (state as GetBuyerChatListSuccess);

        // messagesSuccessState.await.insertAll(0, result.modelList);
        messagesSuccessState.chatedUserList.addAll(result.modelList);
        emit(GetBuyerChatListSuccess(
          chatedUserList: messagesSuccessState.chatedUserList,
          page: (state as GetBuyerChatListSuccess).page + 1,
          hasError: false,
          isLoadingMore: false,
          total: result.total,
        ));

        _updateBadge(messagesSuccessState.chatedUserList);
      }
    } catch (e) {
      emit((state as GetBuyerChatListSuccess)
          .copyWith(isLoadingMore: false, hasError: true));
    }
  }

  bool hasMoreData() {
    if (state is GetBuyerChatListSuccess) {
      return (state as GetBuyerChatListSuccess).chatedUserList.length <
          (state as GetBuyerChatListSuccess).total;
    }

    return false;
  }

  void incrementUnread(String conversationId) {
    if (state is! GetBuyerChatListSuccess) return;
    final success = state as GetBuyerChatListSuccess;
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
    if (state is! GetBuyerChatListSuccess) return;
    final success = state as GetBuyerChatListSuccess;
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
    ChatBadgeController.updateBuyerUnread(
      list.fold<int>(0, (sum, chat) => sum + (chat.unreadMessagesCount ?? 0)),
    );
  }

  @override
  GetBuyerChatListState? fromJson(Map<String, dynamic> json) {
    return null;
  }

  @override
  Map<String, dynamic>? toJson(GetBuyerChatListState state) {
    return null;
  }

  ChatedUser? getOfferForItem(int itemId) {
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> offerList =
          (state as GetBuyerChatListSuccess).chatedUserList;

      int matchingOffer = offerList.indexWhere(
        (offer) => offer.itemId == itemId,
      );
      if (matchingOffer != -1) {
        return (state as GetBuyerChatListSuccess).chatedUserList[matchingOffer];
      } else {
        return null;
      }
    }
    return null; // Return null if state is not GetBuyerChatListSuccess
  }

  void resetState() {
    emit(GetBuyerChatListInProgress());
  }
}
