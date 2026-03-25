
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; 
import 'package:cloud_firestore/cloud_firestore.dart' hide Filter; // Hide Filter to prevent Stream conflict
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'firebase_options.dart'; 

// --- GLOBAL VARIABLES ---
final streamClient = StreamChatClient(
  'srzvkmn6xvrj', // Your Stream API Key
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
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1ca931),
          foregroundColor: Colors.white,
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
// --- AUTHENTICATION SCREENS ---
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
        await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("The Garden", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 40),
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
    );
  }
}

// ==========================================
// --- MAIN NAVIGATION (BOTTOM TABS) ---
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

  // Expanded to 5 Tabs
  final List<Widget> _screens = [
    const EventsScreen(),        // 0
    const PrayerWallScreen(),    // 1
    const NeedsBoardScreen(),    // 2
    const ChannelListScreen(),   // 3
    const ProfileScreen(),       // 4
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
        type: BottomNavigationBarType.fixed, // Required when having more than 3 tabs
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
// --- 1. EVENTS & TASKS SCREEN ---
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

  // --- TASK MANAGER BOTTOM SHEET ---
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
            // Task List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('events').doc(eventId).collection('tasks').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final tasks = snapshot.data!.docs;
                  if (tasks.isEmpty) return const Center(child: Text("No tasks yet.", style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isClaimed = task['assigneeId'] != null;
                      final isMine = task['assigneeId'] == currentUserId;

                      return ListTile(
                        title: Text(task['name'], style: TextStyle(color: isClaimed ? Colors.grey : Colors.white, decoration: isClaimed ? TextDecoration.lineThrough : null)),
                        subtitle: isClaimed ? Text("Claimed by ${task['assigneeName']}", style: const TextStyle(color: Color(0xFF1ca931))) : null,
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isMine ? Colors.red : (isClaimed ? Colors.grey : const Color(0xFF1ca931))),
                          onPressed: () async {
                            if (isMine) {
                              // Unclaim
                              await task.reference.update({'assigneeId': null, 'assigneeName': null});
                            } else if (!isClaimed) {
                              // Claim
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
            // Add Task Input
            Row(
              children: [
                Expanded(child: TextField(controller: taskController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "E.g. Bring napkins", hintStyle: TextStyle(color: Colors.grey)))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF1ca931), size: 40),
                  onPressed: () async {
                    if (taskController.text.isEmpty) return;
                    await FirebaseFirestore.instance.collection('events').doc(eventId).collection('tasks').add({
                      'name': taskController.text,
                      'assigneeId': null,
                      'assigneeName': null,
                    });
                    taskController.clear();
                  },
                )
              ],
            ),
            const SizedBox(height: 20),
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
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white), weekendTextStyle: TextStyle(color: Colors.grey),
              selectedDecoration: BoxDecoration(color: Color(0xFF1ca931), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Color(0xFF3b3e44), shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(titleTextStyle: TextStyle(color: Colors.white, fontSize: 18), formatButtonVisible: false, leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white), rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white)),
          ),
          const Divider(color: Colors.grey, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final selectedEvents = snapshot.data!.docs.where((doc) {
                  final eventDate = (doc['date'] as Timestamp).toDate();
                  return _selectedDay != null && eventDate.year == _selectedDay!.year && eventDate.month == _selectedDay!.month && eventDate.day == _selectedDay!.day;
                }).toList();

                if (selectedEvents.isEmpty) return const Center(child: Text("No events on this day.", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  itemCount: selectedEvents.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final eventData = selectedEvents[index].data() as Map<String, dynamic>;
                    final eventId = selectedEvents[index].id;
                    final title = eventData['title'] ?? 'No Title';
                    final List rsvps = eventData['rsvps'] ?? [];
                    final isGoing = rsvps.contains(currentUserId);

                    return Card(
                      color: const Color(0xFF3b3e44),
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(eventData['description'] ?? '', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${rsvps.length} attending", style: const TextStyle(color: Color(0xFF1ca931), fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    // TASKS BUTTON
                                    IconButton(
                                      icon: const Icon(Icons.checklist, color: Colors.white),
                                      onPressed: () => _showTasksDialog(context, eventId, title),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: isGoing ? Colors.grey[700] : const Color(0xFF1ca931)),
                                      onPressed: () => _toggleRsvp(eventId, rsvps),
                                      child: Text(isGoing ? "Cancel" : "RSVP", style: const TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                )
                              ],
                            )
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
            TextField(controller: contentController, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "How can we pray for you?", hintStyle: TextStyle(color: Colors.grey), filled: true, fillColor: Color(0xFF25292e))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931), minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                if (contentController.text.isEmpty) return;
                final user = fb.FirebaseAuth.instance.currentUser!;
                await FirebaseFirestore.instance.collection('prayers').add({
                  'content': contentController.text,
                  'creatorName': user.email!.split('@')[0],
                  'timestamp': Timestamp.now(),
                  'prayingUsers': [], // Array of User IDs who tapped "Praying"
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Post Request", style: TextStyle(color: Colors.white)),
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
          final prayers = snapshot.data!.docs;
          if (prayers.isEmpty) return const Center(child: Text("No prayers yet.", style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: prayers.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final prayer = prayers[index];
              final List prayingUsers = prayer['prayingUsers'] ?? [];
              final isPraying = prayingUsers.contains(currentUserId);

              return Card(
                color: const Color(0xFF3b3e44),
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer['creatorName'], style: const TextStyle(color: Color(0xFF1ca931), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(prayer['content'], style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              if (isPraying) {
                                await prayer.reference.update({'prayingUsers': FieldValue.arrayRemove([currentUserId])});
                              } else {
                                await prayer.reference.update({'prayingUsers': FieldValue.arrayUnion([currentUserId])});
                              }
                            },
                            child: Icon(Icons.front_hand, color: isPraying ? const Color(0xFF1ca931) : Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text("${prayingUsers.length} Praying", style: TextStyle(color: isPraying ? const Color(0xFF1ca931) : Colors.grey)),
                        ],
                      )
                    ],
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
  String _selectedFilter = 'All'; // 'All', 'Need', 'Offer'

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
                    ChoiceChip(
                      label: const Text("I have a Need"), selectedColor: const Color(0xFF1ca931),
                      selected: type == 'Need', onSelected: (val) => setModalState(() => type = 'Need'),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("I have an Offer"), selectedColor: const Color(0xFF1ca931),
                      selected: type == 'Offer', onSelected: (val) => setModalState(() => type = 'Offer'),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Short Title', filled: true, fillColor: Color(0xFF25292e))),
                const SizedBox(height: 10),
                TextField(controller: descController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Details', filled: true, fillColor: Color(0xFF25292e))),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931), minimumSize: const Size(double.infinity, 50)),
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;
                    final user = fb.FirebaseAuth.instance.currentUser!;
                    await FirebaseFirestore.instance.collection('needs_offers').add({
                      'type': type,
                      'title': titleController.text,
                      'description': descController.text,
                      'creatorId': user.uid,
                      'creatorName': user.email!.split('@')[0],
                      'timestamp': Timestamp.now(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Post to Board", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  // Magic: Start a private chat with the poster
  Future<void> _contactPoster(BuildContext context, String targetUserId) async {
    final currentUserId = streamClient.state.currentUser!.id;
    if (currentUserId == targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This is your own post!")));
      return;
    }
    final channel = streamClient.channel('messaging', extraData: {
      'members': [currentUserId, targetUserId],
    });
    await channel.watch();
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => StreamChannel(channel: channel, child: const ChannelPage())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Needs & Offers")),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddPostDialog(context), child: const Icon(Icons.add)),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['All', 'Need', 'Offer'].map((filter) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: ChoiceChip(
                  label: Text(filter),
                  selectedColor: const Color(0xFF1ca931),
                  selected: _selectedFilter == filter,
                  onSelected: (val) => setState(() => _selectedFilter = filter),
                ),
              )).toList(),
            ),
          ),
          // The Feed
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('needs_offers').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final posts = snapshot.data!.docs.where((doc) {
                  if (_selectedFilter == 'All') return true;
                  return doc['type'] == _selectedFilter;
                }).toList();

                if (posts.isEmpty) return const Center(child: Text("No posts found.", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isNeed = post['type'] == 'Need';

                    return Card(
                      color: const Color(0xFF3b3e44),
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(post['creatorName'], style: const TextStyle(color: Colors.grey)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isNeed ? Colors.orange : Colors.blue, borderRadius: BorderRadius.circular(10)),
                                  child: Text(post['type'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(post['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 5),
                            Text(post['description'], style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ca931)),
                                icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                                label: Text(isNeed ? "I can help" : "Message them", style: const TextStyle(color: Colors.white)),
                                onPressed: () => _contactPoster(context, post['creatorId']),
                              ),
                            )
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
// --- 4. MESSAGING SCREENS ---
// ==========================================
class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamChannelListView(
        controller: StreamChannelListController(
          client: streamClient, filter: Filter.in_('members', [streamClient.state.currentUser!.id]), limit: 20,
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
    return Scaffold(
      appBar: const StreamChannelHeader(),
      body: Column(children: const [Expanded(child: StreamMessageListView()), StreamMessageInput()]),
    );
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
    _userListController = StreamUserListController(
      client: streamClient, limit: 20,
      filter: Filter.notEqual('id', streamClient.state.currentUser!.id),
      sort: [const SortOption('last_active', direction: SortOption.ASC)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start a New Chat")),
      body: StreamUserListView(
        controller: _userListController,
        itemBuilder: (context, users, index, defaultWidget) {
          final user = users[index];
          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(user.image ?? "https://i.pravatar.cc/150")),
            title: Text(user.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text("Last active: ${user.lastActive?.toLocal() ?? 'Never'}", style: const TextStyle(color: Colors.grey)),
            onTap: () async {
              final channel = streamClient.channel('messaging', extraData: {'members': [streamClient.state.currentUser!.id, user.id]});
              await channel.watch();
              if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (context) => StreamChannel(channel: channel, child: const ChannelPage())));
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// --- 5. PROFILE SCREEN ---
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () async {
          await streamClient.disconnectUser(); 
          await fb.FirebaseAuth.instance.signOut(); 
        },
        child: const Text("Log Out", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}