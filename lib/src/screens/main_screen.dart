import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'game_list_screen.dart';
import 'leaderboard_list_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      // ✅ 只有在 Android/iOS 才呼叫 google_sign_in 的 signOut
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      // authStateChanges() 會自動把畫面切回 SignInScreen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tic Tac Toe'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Games'),
              Tab(text: 'Leaderboard'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            GameListScreen(),
            LeaderboardListScreen(),
          ],
        ),
      ),
    );
  }
}
