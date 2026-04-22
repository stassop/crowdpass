import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Import your Riverpod providers
import 'package:crowdpass/providers/auth_provider.dart';

// Import your screens
import 'package:crowdpass/screens/home_screen.dart';
import 'package:crowdpass/screens/event_screen.dart';
import 'package:crowdpass/screens/privacy_screen.dart';
import 'package:crowdpass/screens/sign_in_screen.dart';
import 'package:crowdpass/screens/sign_up_screen.dart';
import 'package:crowdpass/screens/splash_screen.dart';
import 'package:crowdpass/screens/terms_screen.dart';
import 'package:crowdpass/screens/company_screen.dart';
import 'package:crowdpass/screens/user_profile_screen.dart';
import 'package:crowdpass/screens/my_events_screen.dart';
import 'package:crowdpass/screens/company_events_screen.dart';
// import 'package:crowdpass/screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (kDebugMode) {
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';

    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }

  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REMOVED: final user = ref.watch(authProvider).value;
    // We don't want the entire MaterialApp to rebuild on auth changes.

    return MaterialApp(
      // REMOVED: key: ValueKey(user?.uid ?? 'no-user'),
      debugShowCheckedModeBanner: false,
      title: 'CrowdPass',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'GoogleSans',
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/home/': (context) => const HomeScreen(),
        '/sign_in/': (context) => const SignInScreen(),
        '/sign_up/': (context) => const SignUpScreen(),
        '/company/': (context) => const CompanyScreen(),
        '/user/': (context) => const UserProfileScreen(),
        '/event/': (context) => const EventScreen(),
        '/my_events/': (context) => const MyEventsScreen(),
        '/company_events/': (context) => const CompanyEventsScreen(),
        '/terms/': (context) => TermsScreen(),
        '/privacy/': (context) => PrivacyScreen(),
        // '/calendar/': (context) => const CalendarScreen(),
      },
    );
  }
}