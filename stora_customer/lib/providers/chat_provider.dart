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
      final hasChanged = !_areConversationsEqual(_conversations, fetched);
      _conversations = fetched;
      _errorMessage = null;
      if (!isSilent || hasChanged) {
        notifyListeners();
      }
    } catch (e) {
      if (!isSilent) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    } finally {
      if (!isSilent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _areConversationsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] ||
          a[i]['unread_count'] != b[i]['unread_count'] ||
          a[i]['last_message'] != b[i]['last_message'] ||
          (a[i]['last_message_at'] ?? a[i]['timestamp']) != (b[i]['last_message_at'] ?? b[i]['timestamp'])) {
        return false;
      }
    }
    return true;
  }

  Future<void> deleteConversation(int storeOwnerId) async {
    await CustomerApiService.instance.deleteConversation(storeOwnerId);
    _conversations.removeWhere((c) => (c['id'] ?? c['user_id']) == storeOwnerId);
    _messagesCache.remove(storeOwnerId);
    notifyListeners();
  }

  void reset() {
    stopPolling();
    _conversations = [];
    _messagesCache.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
