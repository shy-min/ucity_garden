import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show StreamChannel;

import '../services/chat_service.dart';
import '../services/moderation.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'chat_screens.dart';

class NeedsBoardScreen extends StatefulWidget {
  const NeedsBoardScreen({super.key});

  @override
  State<NeedsBoardScreen> createState() => _NeedsBoardScreenState();
}

class _NeedsBoardScreenState extends State<NeedsBoardScreen> {
  String _selectedFilter = 'All';
  final _stream = FirebaseFirestore.instance
      .collection('needs_offers')
      .orderBy('timestamp', descending: true)
      .limit(200)
      .snapshots();
  final _blockedStream = UserService.instance.blockedIds();

  void _showAddPostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String type = _selectedFilter == 'Offer' ? 'Offer' : 'Need';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Post a Need or Offer', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                      label: const Text('I need'),
                      selected: type == 'Need',
                      onSelected: (_) => setModalState(() => type = 'Need')),
                  const SizedBox(width: 10),
                  ChoiceChip(
                      label: const Text('I can offer'),
                      selected: type == 'Offer',
                      onSelected: (_) => setModalState(() => type = 'Offer')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title', fillColor: AppColors.background),
              ),
              TextField(
                controller: descController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Details', fillColor: AppColors.background),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          showSnack(context, 'Please add a title.');
                          return;
                        }
                        setModalState(() => saving = true);
                        final user = fb.FirebaseAuth.instance.currentUser!;
                        await FirebaseFirestore.instance.collection('needs_offers').add({
                          'type': type,
                          'title': titleController.text.trim(),
                          'description': descController.text.trim(),
                          'creatorId': user.uid,
                          'creatorName': await UserService.instance.currentDisplayName(),
                          'timestamp': Timestamp.now(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Post'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _message(BuildContext context, String otherUserId) async {
    try {
      final channel = await ChatService.instance.directChannelWith(otherUserId);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StreamChannel(channel: channel, child: const ChannelPage())));
    } catch (e) {
      if (context.mounted) showSnack(context, "Couldn't open chat right now. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Needs & Offers')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New post',
        onPressed: () => _showAddPostDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                for (final f in const ['All', 'Need', 'Offer']) ...[
                  ChoiceChip(
                    label: Text(f == 'All' ? 'All' : '${f}s'),
                    selected: _selectedFilter == f,
                    selectedColor: AppColors.green,
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _blockedStream,
              builder: (context, blockedSnap) {
                final blocked = blockedSnap.data ?? const <String>{};
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("Couldn't load posts. Check your connection."));
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final posts = snapshot.data!.docs.where((doc) {
                      final d = doc.data();
                      return (_selectedFilter == 'All' || d['type'] == _selectedFilter) &&
                          !blocked.contains(d['creatorId']);
                    }).toList();
                    if (posts.isEmpty) {
                      return const Center(
                          child: Text('Nothing here yet.\nTap + to post a need or an offer.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final d = post.data();
                        final isNeed = d['type'] == 'Need';
                        final creatorId = d['creatorId'] as String?;
                        final isMine = creatorId == currentUserId;
                        final ts = d['timestamp'];
                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isNeed ? const Color(0x33ff9800) : const Color(0x331ca931),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(isNeed ? 'NEED' : 'OFFER',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isNeed ? Colors.orange : AppColors.green)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${d['creatorName'] ?? 'Member'}${ts is Timestamp ? '  ·  ${timeAgo(ts.toDate())}' : ''}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                                    tooltip: 'More',
                                    onPressed: () => Moderation.showActions(context,
                                        contentType: 'need_offer',
                                        ref: post.reference,
                                        ownerId: creatorId,
                                        ownerName: d['creatorName'],
                                        excerpt: '${d['title']}: ${d['description']}'),
                                  ),
                                ]),
                                Text(d['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                if ((d['description'] ?? '').toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, right: 12),
                                    child: Text(d['description'], style: const TextStyle(color: Colors.white70)),
                                  ),
                                if (!isMine && creatorId != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8, top: 4),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                        label: const Text('Message'),
                                        onPressed: () => _message(context, creatorId),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
