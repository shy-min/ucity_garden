import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide Moderation;

import '../services/chat_service.dart';
import '../services/moderation.dart';
import '../theme.dart';

/// Chat tab. Waits for the chat connection instead of assuming it's ready.
class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatStatus>(
      valueListenable: ChatService.instance.status,
      builder: (context, status, _) {
        if (status == ChatStatus.connected) return const _ConnectedChannelList();
        return Scaffold(
          appBar: AppBar(title: const Text('Messages')),
          body: Center(
            child: status == ChatStatus.failed
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text("Couldn't connect to chat.", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: ChatService.instance.connect, child: const Text('Try again')),
                    ]),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class _ConnectedChannelList extends StatefulWidget {
  const _ConnectedChannelList();

  @override
  State<_ConnectedChannelList> createState() => _ConnectedChannelListState();
}

class _ConnectedChannelListState extends State<_ConnectedChannelList> {
  late final StreamChannelListController _controller = StreamChannelListController(
    client: streamClient,
    filter: Filter.in_('members', [streamClient.state.currentUser!.id]),
    channelStateSort: const [SortOption.desc('last_message_at')],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamChannelListView(
        controller: _controller,
        emptyBuilder: (_) => const Center(
          child: Text('No conversations yet.\nTap + to message someone.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
        onChannelTap: (channel) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StreamChannel(channel: channel, child: const ChannelPage()))),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New message',
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsersListScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChannelPage extends StatelessWidget {
  const ChannelPage({super.key});

  String? _otherMemberId(Channel channel) {
    final me = streamClient.state.currentUser?.id;
    final members = channel.state?.members ?? const <Member>[];
    for (final m in members) {
      if (m.userId != null && m.userId != me) return m.userId;
    }
    return null;
  }

  Future<void> _menu(BuildContext context) async {
    final channel = StreamChannel.of(context).channel;
    final otherId = _otherMemberId(channel);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report conversation'),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
          if (otherId != null)
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Block this member'),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          ListTile(leading: const Icon(Icons.close), title: const Text('Cancel'), onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'report') {
      final reason = await Moderation.pickReason(context);
      if (reason == null) return;
      await Moderation.report(
          contentType: 'chat', contentId: 'stream/${channel.cid}', ownerId: otherId, reason: reason);
      if (context.mounted) showSnack(context, "Thanks, we'll review this within 24 hours.");
    } else if (choice == 'block' && otherId != null) {
      final ok = await Moderation.confirm(context, 'Block this member?',
          "You won't see their posts or messages. You can unblock them from your profile.", 'Block');
      if (!ok) return;
      await Moderation.block(otherId);
      await Moderation.report(
          contentType: 'user', contentId: 'users/$otherId', ownerId: otherId, reason: 'Blocked from chat');
      try {
        await channel.hide();
      } catch (_) {}
      if (context.mounted) {
        showSnack(context, 'Blocked');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamChannelHeader(
        trailing: IconButton(icon: const Icon(Icons.more_vert), tooltip: 'More', onPressed: () => _menu(context)),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [const Expanded(child: StreamMessageListView()), StreamMessageComposer()]),
      ),
    );
  }
}

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  late final StreamUserListController _userListController = StreamUserListController(
    client: streamClient,
    filter: Filter.notEqual('id', streamClient.state.currentUser!.id),
    sort: const [SortOption.asc('name')],
  );

  @override
  void dispose() {
    _userListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: StreamUserListView(
        controller: _userListController,
        onUserTap: (user) async {
          try {
            final channel = await ChatService.instance.directChannelWith(user.id);
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => StreamChannel(channel: channel, child: const ChannelPage())));
          } catch (_) {
            if (context.mounted) showSnack(context, "Couldn't open chat right now.");
          }
        },
      ),
    );
  }
}
