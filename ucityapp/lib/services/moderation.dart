import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../theme.dart';
import 'chat_service.dart';
import 'user_service.dart';

/// Reporting, blocking and deleting user-generated content. Apple's App Review
/// Guideline 1.2 requires all three for apps with posts and chat.
class Moderation {
  static final _db = FirebaseFirestore.instance;

  static Future<void> report({
    required String contentType,
    required String contentId,
    String? ownerId,
    String? excerpt,
    required String reason,
  }) async {
    final user = fb.FirebaseAuth.instance.currentUser!;
    await _db.collection('reports').add({
      'contentType': contentType,
      'contentId': contentId,
      'ownerId': ownerId,
      'excerpt': excerpt == null ? null : (excerpt.length > 300 ? excerpt.substring(0, 300) : excerpt),
      'reason': reason,
      'reporterId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  static Future<void> block(String otherUserId) async {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    await UserService.instance.docFor(uid).set({
      'blocked': FieldValue.arrayUnion([otherUserId]),
    }, SetOptions(merge: true));
    try {
      await streamClient.blockUser(otherUserId);
    } catch (_) {}
  }

  static Future<void> unblock(String otherUserId) async {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    await UserService.instance.docFor(uid).set({
      'blocked': FieldValue.arrayRemove([otherUserId]),
    }, SetOptions(merge: true));
    try {
      await streamClient.unblockUser(otherUserId);
    } catch (_) {}
  }

  /// The "..." menu on a post: delete when it's yours, otherwise report/block.
  static Future<void> showActions(
    BuildContext context, {
    required String contentType,
    required DocumentReference ref,
    String? ownerId,
    String? ownerName,
    String? excerpt,
  }) async {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    final isMine = ownerId != null && ownerId == uid;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          if (!isMine) ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            if (ownerId != null)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: Text('Block ${ownerName ?? 'this member'}'),
                subtitle: const Text("You won't see their posts or messages"),
                onTap: () => Navigator.pop(ctx, 'block'),
              ),
          ],
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'delete':
        final ok = await confirm(context, 'Delete this?', 'This removes it for everyone.', 'Delete');
        if (ok) {
          await ref.delete();
          if (context.mounted) showSnack(context, 'Deleted');
        }
      case 'report':
        final reason = await pickReason(context);
        if (reason != null) {
          await report(contentType: contentType, contentId: ref.path, ownerId: ownerId, excerpt: excerpt, reason: reason);
          if (context.mounted) showSnack(context, "Thanks, we'll review this within 24 hours.");
        }
      case 'block':
        final ok = await confirm(context, 'Block ${ownerName ?? 'this member'}?',
            "You won't see their posts or messages. You can unblock them from your profile.", 'Block');
        if (ok && ownerId != null) {
          await block(ownerId);
          await report(contentType: 'user', contentId: 'users/$ownerId', ownerId: ownerId, reason: 'Blocked by a member');
          if (context.mounted) showSnack(context, 'Blocked');
        }
    }
  }

  static Future<String?> pickReason(BuildContext context) {
    const reasons = ['Inappropriate or offensive', 'Harassment or bullying', 'Spam or scam', 'Something else'];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Why are you reporting this?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
        ]),
      ),
    );
  }

  static Future<bool> confirm(BuildContext context, String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
