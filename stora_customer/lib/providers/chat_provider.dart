import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _conversations = [];
  final Map<int, List<Map<String, dynamic>>> _messagesCache = {};
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>>? getCachedMessages(int storeOwnerId) => _messagesCache[storeOwnerId];

  void cacheMessages(int storeOwnerId, List<Map<String, dynamic>> messages) {
    _messagesCache[storeOwnerId] = List<Map<String, dynamic>>.from(messages);
  }

  void addCachedMessage(int storeOwnerId, Map<String, dynamic> message) {
    _messagesCache[storeOwnerId] ??= [];
    _messagesCache[storeOwnerId]!.add(message);
  }

  int get unreadCount => _conversations.fold<int>(
        0,
        (sum, c) => sum + ((c['unread_count'] as int?) ?? 0),
      );

  void startPolling({Duration interval = const Duration(seconds: 8)}) {
    _pollingTimer?.cancel();
    fetchConversations(isSilent: true);
    _pollingTimer = Timer.periodic(interval, (_) => fetchConversations(isSilent: true));
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchConversations({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await CustomerApiService.instance.fetchConversations();
      _conversations = fetched;
      _errorMessage = null;
    } catch (e) {
      if (!isSilent) _errorMessage = e.toString();
    } finally {
      if (!isSilent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> deleteConversation(int storeOwnerId) async {
    await CustomerApiService.instance.deleteConversation(storeOwnerId);
    _conversations.removeWhere((c) => (c['id'] ?? c['user_id']) == storeOwnerId);
    notifyListeners();
  }
}
