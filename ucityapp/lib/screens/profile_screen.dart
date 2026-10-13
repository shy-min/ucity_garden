import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chat_service.dart';
import '../services/moderation.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'legal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = fb.FirebaseAuth.instance.currentUser!;
  late final _profileStream = UserService.instance.docFor(user.uid).snapshots();
  late final _myEventsStream =
      FirebaseFirestore.instance.collection('events').where('rsvps', arrayContains: user.uid).snapshots();

  Future<void> _editName(Map<String, dynamic>? data) async {
    final first = TextEditingController(text: data?['firstName'] ?? '');
    final last = TextEditingController(text: data?['lastName'] ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: first,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First Name', fillColor: AppColors.background)),
          const SizedBox(height: 10),
          TextField(
              controller: last,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last Name', fillColor: AppColors.background)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true || first.text.trim().isEmpty) return;
    await UserService.instance.docFor(user.uid).set({
      'firstName': first.text.trim(),
      'lastName': last.text.trim(),
      'email': user.email,
    }, SetOptions(merge: true));
    try {
      await streamClient.partialUpdateUser(user.uid, set: {'name': '${first.text.trim()} ${last.text.trim()}'.trim()});
    } catch (_) {}
  }

  Future<void> _logOut() async {
    await ChatService.instance.disconnect();
    await fb.FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete your account?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'This permanently deletes your profile, your prayer requests, your needs and offers, and your chat account. This cannot be undone.'),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Enter your password to confirm', fillColor: AppColors.background),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await user.reauthenticateWithCredential(
          fb.EmailAuthProvider.credential(email: user.email!, password: password.text));
      final db = FirebaseFirestore.instance;
      for (final col in ['prayers', 'needs_offers']) {
        final mine = await db.collection(col).where('creatorId', isEqualTo: user.uid).get();
        for (final d in mine.docs) {
          await d.reference.delete();
        }
      }
      final rsvped = await db.collection('events').where('rsvps', arrayContains: user.uid).get();
      for (final d in rsvped.docs) {
        await d.reference.update({'rsvps': FieldValue.arrayRemove([user.uid])});
      }
      await UserService.instance.docFor(user.uid).delete();
      await ChatService.instance.disconnect();
      await user.delete();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context,
            e.code == 'wrong-password' || e.code == 'invalid-credential' ? 'Incorrect password.' : (e.message ?? 'Could not delete account.'));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context, 'Could not delete account. Please try again.');
      }
    }
  }

  Future<void> _contact() async {
    final uri = Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=The Garden app');
    if (!await launchUrl(uri) && mounted) {
      showSnack(context, 'Email us at ${AppConfig.supportEmail}');
    }
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 4),
        child: Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.green)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _profileStream,
          builder: (context, profileSnap) {
            final data = profileSnap.data?.data();
            final firstName = data?['firstName'] ?? 'Member';
            final lastName = data?['lastName'] ?? '';
            final blocked = ((data?['blocked'] as List?) ?? const []).whereType<String>().toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.green,
                    child: Text(firstName.toString().isNotEmpty ? firstName.toString()[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$firstName $lastName'.trim(),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit name', onPressed: () => _editName(data)),
                ]),
                _section("Events I'm Attending"),
                const Divider(color: Colors.grey),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _myEventsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    final today = DateTime.now().subtract(const Duration(days: 1));
                    final myEvents = snapshot.data!.docs
                        .where((d) => d.data()['date'] is Timestamp && (d.data()['date'] as Timestamp).toDate().isAfter(today))
                        .toList()
                      ..sort((a, b) => (a.data()['date'] as Timestamp).compareTo(b.data()['date'] as Timestamp));
                    if (myEvents.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No upcoming events.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(children: [
                      for (final event in myEvents)
                        Card(
                          color: AppColors.surface,
                          child: ListTile(
                            title: Text(event.data()['title'] ?? '',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(formatDate((event.data()['date'] as Timestamp).toDate())),
                            trailing: const Icon(Icons.check_circle, color: AppColors.green),
                          ),
                        ),
                    ]);
                  },
                ),
                if (blocked.isNotEmpty) ...[
                  _section('Blocked Members'),
                  const Divider(color: Colors.grey),
                  for (final id in blocked)
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: UserService.instance.docFor(id).get(),
                      builder: (context, s) {
                        final d = s.data?.data();
                        final name = d == null ? 'Member' : '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name.isEmpty ? 'Member' : name),
                          trailing: TextButton(onPressed: () => Moderation.unblock(id), child: const Text('Unblock')),
                        );
                      },
                    ),
                ],
                _section('About'),
                const Divider(color: Colors.grey),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Community Guidelines'),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const LegalScreen(page: LegalPage.terms))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const LegalScreen(page: LegalPage.privacy))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Contact Us'),
                  onTap: _contact,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _logOut,
                    child: const Text('Log Out'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
