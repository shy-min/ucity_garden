import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../services/moderation.dart';
import '../services/user_service.dart';
import '../theme.dart';

class PrayerWallScreen extends StatefulWidget {
  const PrayerWallScreen({super.key});

  @override
  State<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends State<PrayerWallScreen> {
  final _stream = FirebaseFirestore.instance
      .collection('prayers')
      .orderBy('timestamp', descending: true)
      .limit(200)
      .snapshots();
  final _blockedStream = UserService.instance.blockedIds();

  void _showAddPrayerDialog(BuildContext context) {
    final contentController = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share a Prayer Request', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 15),
              TextField(
                controller: contentController,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'How can we pray for you?', fillColor: AppColors.background),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final text = contentController.text.trim();
                        if (text.isEmpty) return;
                        setModalState(() => saving = true);
                        final user = fb.FirebaseAuth.instance.currentUser!;
                        await FirebaseFirestore.instance.collection('prayers').add({
                          'content': text,
                          'creatorId': user.uid,
                          'creatorName': await UserService.instance.currentDisplayName(),
                          'timestamp': Timestamp.now(),
                          'prayingUsers': [],
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Post Request'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Wall')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New prayer request',
        onPressed: () => _showAddPrayerDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<Set<String>>(
        stream: _blockedStream,
        builder: (context, blockedSnap) {
          final blocked = blockedSnap.data ?? const <String>{};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Couldn't load prayers. Check your connection."));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.where((d) => !blocked.contains(d.data()['creatorId'])).toList();
              if (docs.isEmpty) {
                return const Center(
                    child: Text('No prayer requests yet.\nTap + to share one.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final prayer = docs[index];
                  final data = prayer.data();
                  final List prayingUsers = data['prayingUsers'] ?? [];
                  final isPraying = prayingUsers.contains(currentUserId);
                  final ts = data['timestamp'];
                  final color = isPraying ? AppColors.green : Colors.grey;
                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                '${data['creatorName'] ?? 'Member'}${ts is Timestamp ? '  ·  ${timeAgo(ts.toDate())}' : ''}',
                                style: const TextStyle(color: AppColors.green),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.grey),
                              tooltip: 'More',
                              onPressed: () => Moderation.showActions(context,
                                  contentType: 'prayer',
                                  ref: prayer.reference,
                                  ownerId: data['creatorId'],
                                  ownerName: data['creatorName'],
                                  excerpt: data['content']),
                            ),
                          ]),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(data['content'] ?? '', style: const TextStyle(fontSize: 15)),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: Icon(Icons.front_hand, color: color),
                              label: Text('${prayingUsers.length} Praying', style: TextStyle(color: color)),
                              onPressed: () => prayer.reference.update({
                                'prayingUsers': isPraying
                                    ? FieldValue.arrayRemove([currentUserId])
                                    : FieldValue.arrayUnion([currentUserId]),
                              }),
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
    );
  }
}
