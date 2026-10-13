import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Reads and writes the signed-in member's profile (users/{uid}).
class UserService {
  UserService._();
  static final instance = UserService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> docFor(String uid) => _db.collection('users').doc(uid);

  /// Display name for posts: "First L." when we have a profile, otherwise the
  /// part of the email before the @.
  Future<String> currentDisplayName() async {
    final user = fb.FirebaseAuth.instance.currentUser!;
    try {
      final snap = await docFor(user.uid).get();
      final data = snap.data();
      final first = (data?['firstName'] as String? ?? '').trim();
      final last = (data?['lastName'] as String? ?? '').trim();
      if (first.isNotEmpty) return last.isNotEmpty ? '$first ${last[0]}.' : first;
    } catch (_) {}
    return (user.email ?? 'Member').split('@').first;
  }

  Future<String> currentFullName() async {
    final user = fb.FirebaseAuth.instance.currentUser!;
    try {
      final data = (await docFor(user.uid).get()).data();
      final name = '${data?['firstName'] ?? ''} ${data?['lastName'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return (user.email ?? 'Member').split('@').first;
  }

  /// Live list of user ids the current member has blocked.
  Stream<Set<String>> blockedIds() {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});
    return docFor(uid).snapshots().map((s) {
      final list = (s.data()?['blocked'] as List?) ?? const [];
      return list.whereType<String>().toSet();
    });
  }
}
