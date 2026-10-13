import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screens.dart';
import 'screens/events_screen.dart';
import 'screens/needs_board_screen.dart';
import 'screens/prayer_wall_screen.dart';
import 'screens/profile_screen.dart';
import 'services/chat_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Local testing against the Firebase emulators:
  //   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATOR')) {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
    await fb.FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = buildTheme();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => StreamChat(client: streamClient, child: child!),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return HomeScreen(key: ValueKey(snapshot.data!.uid));
        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _visited = <int>{0};

  static const _screens = <Widget>[
    EventsScreen(),
    PrayerWallScreen(),
    NeedsBoardScreen(),
    ChannelListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ChatService.instance.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep each tab alive once opened so scroll position and streams persist.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _screens.length; i++) _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          _visited.add(index);
        }),
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Prayers'),
          BottomNavigationBarItem(icon: Icon(Icons.handshake), label: 'Needs'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
