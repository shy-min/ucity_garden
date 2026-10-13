import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../theme.dart';
import 'user_service.dart';

final streamClient = StreamChatClient(
  AppConfig.streamApiKey,
  logLevel: kReleaseMode ? Level.WARNING : Level.INFO,
);

enum ChatStatus { idle, connecting, connected, failed }

/// Connects the signed-in Firebase member to Stream Chat.
///
/// Token source, in order:
///  1. The Stream "Authenticate with Stream Chat" Firebase extension
///     (callable function `ext-auth-chat-getStreamUserToken`). This is the
///     secure production path.
///  2. A Stream development token, only while [AppConfig.allowStreamDevTokens]
///     is true. Development tokens work only when "Disable Auth Checks" is on
///     in the Stream dashboard, which lets anyone impersonate any user, so
///     production builds should turn this off.
class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final status = ValueNotifier<ChatStatus>(ChatStatus.idle);
  String? lastError;
  Completer<void>? _connecting;

  Future<String> _token(String uid) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('ext-auth-chat-getStreamUserToken')
          .call();
      final data = result.data;
      if (data is String && data.isNotEmpty) return data;
    } catch (e) {
      debugPrint('Secure chat token unavailable: $e');
    }
    if (AppConfig.allowStreamDevTokens) {
      return streamClient.devToken(uid).rawValue;
    }
    throw StateError('Chat sign-in is not configured yet.');
  }

  Future<void> connect() async {
    if (status.value == ChatStatus.connected) return;
    if (_connecting != null) return _connecting!.future;
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _connecting = Completer<void>();
    status.value = ChatStatus.connecting;
    try {
      final name = await UserService.instance.currentFullName();
      await streamClient.connectUser(User(id: user.uid, name: name), await _token(user.uid));
      status.value = ChatStatus.connected;
      lastError = null;
      _connecting!.complete();
    } catch (e) {
      lastError = e.toString();
      status.value = ChatStatus.failed;
      _connecting!.complete();
    } finally {
      _connecting = null;
    }
  }

  Future<void> disconnect() async {
    try {
      await streamClient.disconnectUser();
    } catch (_) {}
    status.value = ChatStatus.idle;
  }

  /// Opens (or creates) the 1:1 conversation with [otherUserId].
  Future<Channel> directChannelWith(String otherUserId) async {
    await connect();
    if (status.value != ChatStatus.connected) {
      throw StateError('Chat is not connected');
    }
    final me = streamClient.state.currentUser!.id;
    final channel = streamClient.channel('messaging', extraData: {
      'members': [me, otherUserId],
    });
    await channel.watch();
    return channel;
  }
}
