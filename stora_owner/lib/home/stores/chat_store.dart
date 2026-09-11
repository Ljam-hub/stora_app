import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalUnreadCount => _conversations.fold<int>(
        0,
        (sum, c) => sum + ((c['unread_count'] as int?) ?? 0),
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
}
