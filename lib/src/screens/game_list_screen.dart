import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'game_board_screen.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tic-Tac-Toe Games')),
      body: Column(
        children: [
          Expanded(
            child: _buildActiveGamesList(),
          ),
          Divider(height: 1.5, thickness: 1.5, color: Colors.grey[400]),
          _buildCompletedGamesSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewGame(context),
        tooltip: 'Create New Game',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Active + Waiting games
  Widget _buildActiveGamesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .where('status', whereIn: ['active', 'waiting'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          developer.log(
            'Firestore Stream Error (Active): ${snapshot.error}',
            name: 'GameListScreen.Active',
          );
          return const Center(child: Text('Error loading active games.'));
        }
        final docs = snapshot.data?.docs;
        if (docs == null || docs.isEmpty) {
          return const Center(
            child: Text('No active or waiting games found.'),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildActiveGameTile(context, docs[index]);
          },
        );
      },
    );
  }

  // 整個 Completed 區塊 (ExpansionTile)
  Widget _buildCompletedGamesSection() {
    return ExpansionTile(
      title: _buildCompletedGamesHeader(),
      controlAffinity: ListTileControlAffinity.leading,
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.blueGrey[50],
      children: <Widget>[_buildCompletedGamesListInsideExpansion()],
    );
  }

  // Completed header + count
  Widget _buildCompletedGamesHeader() {
    final userId = _currentUser?.uid;
    if (userId == null) {
      return _buildHeaderContent('Completed Games', null);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          developer.log(
            'Error fetching completed games for count: ${snapshot.error}',
            name: 'GameListScreen.Count',
          );
          return _buildHeaderContent('Completed Games', null);
        }

        int userCompletedCount = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final playerXUserId = data['playerX']?['userId'];
            final playerOUserId = data['playerO']?['userId'];
            if (playerXUserId == userId || playerOUserId == userId) {
              userCompletedCount++;
            }
          }
        }
        return _buildHeaderContent('Completed Games', userCompletedCount);
      },
    );
  }

  Widget _buildHeaderContent(String title, int? count) {
    return Container(
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blueGrey[800],
              ),
            ),
          ),
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '($count)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.blueGrey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Completed games list (inside ExpansionTile)
  Widget _buildCompletedGamesListInsideExpansion() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'completed')
          // 這裡會需要 index: status ASC, endedAt DESC
          .orderBy('endedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          developer.log(
            'Error loading completed games list: ${snapshot.error}',
            name: 'GameListScreen.CompletedList',
            error: snapshot.error,
            level: 1000,
          );
          String errorText = 'Error loading completed games.';
          if (snapshot.error
              .toString()
              .toLowerCase()
              .contains('index')) {
            errorText +=
                '\nPlease create the required Firestore index (status + endedAt).';
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(errorText, textAlign: TextAlign.center),
            ),
          );
        }

        final docs = snapshot.data?.docs;
        if (docs == null || docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No completed games found.')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            if (!mounted) return const SizedBox.shrink();
            return _buildCompletedGameTile(context, docs[index]);
          },
        );
      },
    );
  }

  // Active / Waiting tile
  Widget _buildActiveGameTile(
    BuildContext context,
    DocumentSnapshot gameDoc,
  ) {
    final data = gameDoc.data() as Map<String, dynamic>? ?? {};

    final playerXData = data['playerX'] as Map<String, dynamic>? ?? {};
    final playerOData = data['playerO'] as Map<String, dynamic>?;

    final String playerXName = playerXData['displayName'] ?? 'Unknown Player';
    final String playerOName = playerOData?['displayName'] ?? 'Waiting...';

    final String status = data['status'] ?? 'unknown';
    final String displayStatus =
        status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : '';

    final createdAtData = data['createdAt'];
    final String started = _formatTimestamp(createdAtData);

    String tileTitle;
    if (status == 'waiting') {
      tileTitle = 'Game created by $playerXName';
    } else {
      tileTitle = '$playerXName vs $playerOName';
    }

    return ListTile(
      title: Text(tileTitle),
      subtitle: Text('Status: $displayStatus\nStarted: $started'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameBoardScreen(gameId: gameDoc.id),
          ),
        );
      },
    );
  }

  // Completed tile
  Widget _buildCompletedGameTile(
    BuildContext context,
    DocumentSnapshot gameDoc,
  ) {
    final data = gameDoc.data() as Map<String, dynamic>? ?? {};

    final playerXData = data['playerX'] as Map<String, dynamic>? ?? {};
    final playerOData = data['playerO'] as Map<String, dynamic>? ?? {};

    final String playerXName = playerXData['displayName'] ?? 'Player X';
    final String playerOName = playerOData['displayName'] ?? 'Player O';

    final String? winner = data['winner']; // 'X', 'O', or 'draw'
    final endedAtData = data['endedAt'];
    final String endedDate = _formatTimestamp(endedAtData);

    String resultText;
    Icon resultIcon;

    if (winner == 'draw') {
      resultText = 'Result: Draw';
      resultIcon =
          const Icon(Icons.handshake_outlined, color: Colors.orange);
    } else if (winner == 'X') {
      resultText = 'Winner: $playerXName (X)';
      resultIcon = const Icon(Icons.emoji_events_outlined,
          color: Colors.redAccent);
    } else if (winner == 'O') {
      resultText = 'Winner: $playerOName (O)';
      resultIcon = const Icon(Icons.emoji_events_outlined,
          color: Colors.blueAccent);
    } else {
      resultText = 'Result: Unknown';
      resultIcon =
          const Icon(Icons.question_mark, color: Colors.grey);
    }

    return ListTile(
      leading: resultIcon,
      title: Text('$playerXName vs $playerOName'),
      subtitle: Text('$resultText\nEnded: $endedDate'),
      dense: true,
    );
  }

  // Timestamp formatter
  String _formatTimestamp(dynamic timestampData) {
    if (timestampData is Timestamp) {
      try {
        return DateFormat.yMd().add_jm().format(
              timestampData.toDate().toLocal(),
            );
      } catch (_) {
        final dt = timestampData.toDate().toLocal();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    return 'N/A';
  }

  // 建立新遊戲
  void _createNewGame(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final gameData = {
        'playerX': {
          'userId': user.uid,
          'displayName': (user.displayName?.isNotEmpty ?? false)
              ? user.displayName
              : user.email ?? 'Player X',
        },
        'playerO': null,
        'status': 'waiting',
        'currentTurn': 'X',
        'board': List.filled(9, null),
        'winner': null,
        'createdAt': FieldValue.serverTimestamp(),
        'moves': [],
        'endedAt': null,
      };

      final doc = await FirebaseFirestore.instance
          .collection('games')
          .add(gameData);

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameBoardScreen(gameId: doc.id),
        ),
      );
    } catch (e) {
      developer.log(
        'Error creating game: $e',
        name: 'GameListScreen.CreateGame',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create game: $e')),
      );
    }
  }
}
