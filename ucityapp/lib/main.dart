import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; 
import 'package:cloud_firestore/cloud_firestore.dart' hide Filter; 
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'firebase_options.dart'; 

// --- GLOBAL VARIABLES ---
final streamClient = StreamChatClient(
  'srzvkmn6xvrj', 
  logLevel: Level.INFO,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
  runApp(const MyApp());
}

// --- MAIN APP THEME ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Garden',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF25292e),
        primaryColor: const Color(0xFF1ca931),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF25292e),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        return StreamChat(client: streamClient, child: child!);
      },
      home: const AuthGate(), 
    );
  }
}

// ==========================================
// --- AUTHENTICATION & PROFILE SETUP ---
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) return const HomeScreen(); 
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController(); // New
  final _lastNameController = TextEditingController();  // New
  bool isLogin = true; 
  bool isLoading = false;

  Future<void> _submit() async {
    setState(() => isLoading = true); 
    try {
      if (isLogin) {
        await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // 1. Create Auth User
        fb.UserCredential cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Create Firestore Profile Document
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'joinedAt': Timestamp.now(),
        });
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Auth failed")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Added to prevent overflow with more fields
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              const Text("The Garden", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 40),
              
              if (!isLogin) ...[
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFF3b3e44)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFF3b3e44)),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFF3b3e44)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true, 
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFF3b3e44)),
              ),
              const SizedBox(height: 20),
              isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931), padding: const EdgeInsets.all(15)),
                    onPressed: _submit,
                    child: Text(isLogin ? "Sign In" : "Sign Up", style: const TextStyle(color: Colors.white)),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "Create Account" : "I have an account", style: const TextStyle(color: Color(0xFF1ca931))),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// --- MAIN NAVIGATION ---
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 

  @override
  void initState() {
    super.initState();
    _connectChatUser();
  }

  Future<void> _connectChatUser() async {
    final user = fb.FirebaseAuth.instance.currentUser!;
    await streamClient.connectUser(
      User(id: user.uid, name: user.email!.split('@')[0]),
      streamClient.devToken(user.uid).rawValue, 
    );
  }

  final List<Widget> _screens = [
    const EventsScreen(),
    const PrayerWallScreen(),
    const NeedsBoardScreen(),
    const ChannelListScreen(),
    const ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF25292e),
        selectedItemColor: const Color(0xFF1ca931), 
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Prayers"),
          BottomNavigationBarItem(icon: Icon(Icons.handshake), label: "Needs"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ==========================================
// --- 1. EVENTS SCREEN ---
// ==========================================
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime pickedDate = DateTime((_selectedDay ?? DateTime.now()).year, (_selectedDay ?? DateTime.now()).month, (_selectedDay ?? DateTime.now()).day);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3b3e44),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder( 
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Create New Event", style: TextStyle(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 15),
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Event Title', filled: true, fillColor: Color(0xFF25292e))),
                const SizedBox(height: 10),
                TextField(controller: descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description', filled: true, fillColor: Color(0xFF25292e)), maxLines: 3),
                const SizedBox(height: 15),
                ListTile(
                  tileColor: const Color(0xFF25292e),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF1ca931)),
                  title: Text("Date: ${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    DateTime? date = await showDatePicker(context: context, initialDate: pickedDate, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2030));
                    if (date != null) setModalState(() => pickedDate = DateTime(date.year, date.month, date.day));
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931)),
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;
                    final user = fb.FirebaseAuth.instance.currentUser!;
                    await FirebaseFirestore.instance.collection('events').add({
                      'title': titleController.text,
                      'description': descController.text,
                      'date': Timestamp.fromDate(pickedDate), 
                      'creatorId': user.uid,
                      'rsvps': [user.uid],
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Publish Event", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showTasksDialog(BuildContext context, String eventId, String eventTitle) {
    final taskController = TextEditingController();
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;
    final userEmail = fb.FirebaseAuth.instance.currentUser!.email!.split('@')[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3b3e44),
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          children: [
            Text("Volunteer Tasks: $eventTitle", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('events').doc(eventId).collection('tasks').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final tasks = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isClaimed = task['assigneeId'] != null;
                      final isMine = task['assigneeId'] == currentUserId;

                      return ListTile(
                        title: Text(task['name'], style: TextStyle(color: isClaimed ? Colors.grey : Colors.white, decoration: isClaimed ? TextDecoration.lineThrough : null)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isMine ? Colors.red : (isClaimed ? Colors.grey : const Color(0xFF1ca931))),
                          onPressed: () async {
                            if (isMine) {
                              await task.reference.update({'assigneeId': null, 'assigneeName': null});
                            } else if (!isClaimed) {
                              await task.reference.update({'assigneeId': currentUserId, 'assigneeName': userEmail});
                            }
                          },
                          child: Text(isMine ? "Unclaim" : (isClaimed ? "Taken" : "Claim"), style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: taskController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Add Task..."))),
                IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF1ca931)), onPressed: () async {
                  if (taskController.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('events').doc(eventId).collection('tasks').add({'name': taskController.text, 'assigneeId': null, 'assigneeName': null});
                  taskController.clear();
                })
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRsvp(String eventId, List currentRsvps) async {
    final userId = fb.FirebaseAuth.instance.currentUser!.uid;
    final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
    if (currentRsvps.contains(userId)) {
      await eventRef.update({'rsvps': FieldValue.arrayRemove([userId])});
    } else {
      await eventRef.update({'rsvps': FieldValue.arrayUnion([userId])});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("The Garden Events")),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddEventDialog(context), child: const Icon(Icons.add)),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
            calendarStyle: const CalendarStyle(defaultTextStyle: TextStyle(color: Colors.white), selectedDecoration: BoxDecoration(color: Color(0xFF1ca931), shape: BoxShape.circle)),
            headerStyle: const HeaderStyle(titleTextStyle: TextStyle(color: Colors.white), formatButtonVisible: false),
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final selectedEvents = snapshot.data!.docs.where((doc) {
                  final eventDate = (doc['date'] as Timestamp).toDate();
                  return _selectedDay != null && eventDate.year == _selectedDay!.year && eventDate.month == _selectedDay!.month && eventDate.day == _selectedDay!.day;
                }).toList();

                if (selectedEvents.isEmpty) return const Center(child: Text("No events on this day."));

                return ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final eventData = selectedEvents[index].data() as Map<String, dynamic>;
                    final eventId = selectedEvents[index].id;
                    final List rsvps = eventData['rsvps'] ?? [];
                    final isGoing = rsvps.contains(currentUserId);

                    return Card(
                      color: const Color(0xFF3b3e44),
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(eventData['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(eventData['description']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.checklist), onPressed: () => _showTasksDialog(context, eventId, eventData['title'])),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: isGoing ? Colors.grey : const Color(0xFF1ca931)),
                              onPressed: () => _toggleRsvp(eventId, rsvps),
                              child: Text(isGoing ? "Cancel" : "RSVP"),
                            ),
                          ],
                        ),
                      ),
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

// ==========================================
// --- 2. PRAYER WALL SCREEN ---
// ==========================================
class PrayerWallScreen extends StatelessWidget {
  const PrayerWallScreen({super.key});

  void _showAddPrayerDialog(BuildContext context) {
    final contentController = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF3b3e44), isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share a Prayer Request", style: TextStyle(fontSize: 20, color: Colors.white)),
            const SizedBox(height: 15),
            TextField(controller: contentController, maxLines: 4, decoration: const InputDecoration(hintText: "How can we pray for you?", filled: true, fillColor: Color(0xFF25292e))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931)),
              onPressed: () async {
                if (contentController.text.isEmpty) return;
                final user = fb.FirebaseAuth.instance.currentUser!;
                await FirebaseFirestore.instance.collection('prayers').add({
                  'content': contentController.text,
                  'creatorName': user.email!.split('@')[0],
                  'timestamp': Timestamp.now(),
                  'prayingUsers': [],
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Post Request"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Prayer Wall")),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddPrayerDialog(context), child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('prayers').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final prayer = snapshot.data!.docs[index];
              final List prayingUsers = prayer['prayingUsers'] ?? [];
              final isPraying = prayingUsers.contains(currentUserId);
              return Card(
                color: const Color(0xFF3b3e44),
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(prayer['creatorName'], style: const TextStyle(color: Color(0xFF1ca931))),
                  subtitle: Text(prayer['content']),
                  trailing: TextButton.icon(
                    icon: Icon(Icons.front_hand, color: isPraying ? const Color(0xFF1ca931) : Colors.grey),
                    label: Text("${prayingUsers.length} Praying", style: TextStyle(color: isPraying ? const Color(0xFF1ca931) : Colors.grey)),
                    onPressed: () async {
                      if (isPraying) {
                        await prayer.reference.update({'prayingUsers': FieldValue.arrayRemove([currentUserId])});
                      } else {
                        await prayer.reference.update({'prayingUsers': FieldValue.arrayUnion([currentUserId])});
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// --- 3. NEEDS & OFFERS BOARD ---
// ==========================================
class NeedsBoardScreen extends StatefulWidget {
  const NeedsBoardScreen({super.key});

  @override
  State<NeedsBoardScreen> createState() => _NeedsBoardScreenState();
}

class _NeedsBoardScreenState extends State<NeedsBoardScreen> {
  String _selectedFilter = 'All';

  void _showAddPostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String type = 'Need'; 

    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF3b3e44), isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(label: const Text("Need"), selected: type == 'Need', onSelected: (val) => setModalState(() => type = 'Need')),
                    const SizedBox(width: 10),
                    ChoiceChip(label: const Text("Offer"), selected: type == 'Offer', onSelected: (val) => setModalState(() => type = 'Offer')),
                  ],
                ),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Details')),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () async {
                  final user = fb.FirebaseAuth.instance.currentUser!;
                  await FirebaseFirestore.instance.collection('needs_offers').add({
                    'type': type, 'title': titleController.text, 'description': descController.text,
                    'creatorId': user.uid, 'creatorName': user.email!.split('@')[0], 'timestamp': Timestamp.now(),
                  });
                  Navigator.pop(context);
                }, child: const Text("Post")),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Needs & Offers")),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddPostDialog(context), child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('needs_offers').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final posts = snapshot.data!.docs.where((doc) => _selectedFilter == 'All' || doc['type'] == _selectedFilter).toList();
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                color: const Color(0xFF3b3e44),
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(post['title']),
                  subtitle: Text(post['description']),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final channel = streamClient.channel('messaging', extraData: {'members': [streamClient.state.currentUser!.id, post['creatorId']]});
                      await channel.watch();
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => StreamChannel(channel: channel, child: const ChannelPage())));
                    },
                    child: const Text("Message"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// --- 4. MESSAGING ---
// ==========================================
class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamChannelListView(
        controller: StreamChannelListController(
          client: streamClient, filter: Filter.in_('members', [streamClient.state.currentUser!.id]),
        ),
        onChannelTap: (channel) => Navigator.of(context).push(MaterialPageRoute(builder: (context) => StreamChannel(channel: channel, child: const ChannelPage()))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UsersListScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChannelPage extends StatelessWidget {
  const ChannelPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: const StreamChannelHeader(), body: Column(children: const [Expanded(child: StreamMessageListView()), StreamMessageInput()]));
  }
}

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  late final StreamUserListController _userListController;
  @override
  void initState() {
    super.initState();
    _userListController = StreamUserListController(client: streamClient, filter: Filter.notEqual('id', streamClient.state.currentUser!.id));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Chat")),
      body: StreamUserListView(
        controller: _userListController,
        onUserTap: (user) async {
          final channel = streamClient.channel('messaging', extraData: {'members': [streamClient.state.currentUser!.id, user.id]});
          await channel.watch();
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => StreamChannel(channel: channel, child: const ChannelPage())));
        },
      ),
    );
  }
}

// ==========================================
// --- 5. ENHANCED PROFILE SCREEN ---
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = fb.FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Header
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final firstName = userData?['firstName'] ?? 'User';
                final lastName = userData?['lastName'] ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$firstName $lastName", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            const Text("Events I'm Attending", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1ca931))),
            const Divider(color: Colors.grey),
            
            // 2. Events Attending List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('rsvps', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final myEvents = snapshot.data!.docs;

                if (myEvents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No upcoming events.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myEvents.length,
                  itemBuilder: (context, index) {
                    final event = myEvents[index];
                    return Card(
                      color: const Color(0xFF3b3e44),
                      child: ListTile(
                        title: Text(event['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(event['description'], maxLines: 1),
                        trailing: const Icon(Icons.check_circle, color: Color(0xFF1ca931)),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await streamClient.disconnectUser(); 
                  await fb.FirebaseAuth.instance.signOut(); 
                },
                child: const Text("Log Out", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}