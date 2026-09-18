import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  List<Map<String, dynamic>> _conversations = [];
  final Map<int, List<Map<String, dynamic>>> _messagesCache = {};
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>>? getCachedMessages(int partnerId) => _messagesCache[partnerId];

  void cacheMessages(int partnerId, List<Map<String, dynamic>> messages) {
    _messagesCache[partnerId] = List<Map<String, dynamic>>.from(messages);
  }

  void addCachedMessage(int partnerId, Map<String, dynamic> message) {
    _messagesCache[partnerId] ??= [];
    _messagesCache[partnerId]!.add(message);
  }

  int get totalUnreadCount => _conversations.fold<int>(
    0,
    (sum, c) {
      final count = c['unread_count'];
      final parsed = count is num ? count.toInt() : int.tryParse(count?.toString() ?? '0');
      return sum + (parsed ?? 0);
    },
  );

  void startPolling({Duration interval = const Duration(seconds: 8)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => fetchConversations(isSilent: true));
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchConversations({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final fetched = await ApiClient.instance.fetchConversations();
      _conversations = fetched;
      _error = null;
    } catch (e) {
      if (!isSilent) _error = e.toString();
    } finally {
      if (!isSilent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> deleteConversation(int withUserId) async {
    await ApiClient.instance.deleteConversation(withUserId);
    _conversations.removeWhere((c) => (c['customer_id'] ?? c['user_id'] ?? c['id']) == withUserId);
    _messagesCache.remove(withUserId);
    notifyListeners();
  }

  void clear() {
    stopPolling();
    _conversations = [];
    _messagesCache.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
