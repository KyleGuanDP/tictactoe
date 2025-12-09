import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameBoardScreen extends StatefulWidget {
  final String gameId;

  const GameBoardScreen({super.key, required this.gameId});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  List<dynamic>? _localBoardState;
  User? _currentUser;
  Map<String, dynamic>? _currentGameData;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    developer.log(
      'GameBoardScreen Init - Current User UID: ${_currentUser?.uid}',
      name: 'GameBoardScreen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Game ${widget.gameId.length >= 6 ? widget.gameId.substring(0, 6) : widget.gameId}...'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.gameId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            _currentGameData =
                snapshot.data!.data() as Map<String, dynamic>;
            _localBoardState = List<dynamic>.from(
              _currentGameData!['board'] ?? List.filled(9, null),
            );
            developer.log(
              'Stream Update - Status: ${_currentGameData!['status']}, Turn: ${_currentGameData!['currentTurn']}',
              name: 'GameBoardScreen.Stream',
            );
          } else if (snapshot.connectionState == ConnectionState.active &&
              snapshot.hasData &&
              !snapshot.data!.exists) {
            _currentGameData = null;
            _localBoardState = null;
          }

          if (_currentGameData == null) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              developer.log(
                'Stream Error: ${snapshot.error}',
                name: 'GameBoardScreen.Stream',
                error: snapshot.error,
              );
              return Center(
                child: Text('Error loading game: ${snapshot.error}'),
              );
            }
            return const Center(
              child: Text('Game not found or has been deleted.'),
            );
          }

          final game = _currentGameData!;
          String? winnerText;
          if (game['status'] == 'completed' && game['winner'] != null) {
            if (game['winner'] == 'draw') {
              winnerText = 'It\'s a Draw!';
            } else {
              String winnerName = '';
              if (game['winner'] == 'X') {
                winnerName =
                    game['playerX']?['displayName'] ?? 'Player X';
              } else if (game['winner'] == 'O') {
                winnerName =
                    game['playerO']?['displayName'] ?? 'Player O';
              }
              winnerText = 'Winner: $winnerName (${game['winner']})';
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16.0),
                child: _buildPlayerInfo(game, _currentUser),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 450,
                      maxHeight: 450,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildBoard(game, _currentUser),
                    ),
                  ),
                ),
              ),
              if (winnerText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20.0),
                  child: Text(
                    winnerText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (game['status'] == 'active')
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    'Turn: ${game['currentTurn'] ?? ''}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerInfo(Map<String, dynamic> game, User? user) {
    if (user == null) return const Text('Not logged in');

    if (game['status'] == 'waiting' &&
        game['playerO'] == null &&
        game['playerX']?['userId'] != user.uid) {
      return ElevatedButton(
        onPressed: () => _joinGame(user),
        child: const Text('Join as Player O'),
      );
    }

    final String playerXName =
        game['playerX']?['displayName'] ?? 'Player X';
    final String playerOName =
        game['playerO']?['displayName'] ?? 'Waiting...';
    final String currentTurn = game['currentTurn'] ?? '';
    final bool isXTurn = currentTurn == 'X';
    final bool isOTurn = currentTurn == 'O';
    final bool isCompleted = game['status'] == 'completed';

    const normalStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.w500);
    const boldStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.blue,
    );

    final xStyle = !isCompleted && isXTurn ? boldStyle : normalStyle;
    final oStyle = !isCompleted && isOTurn ? boldStyle : normalStyle;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: normalStyle.copyWith(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        children: <TextSpan>[
          TextSpan(text: '$playerXName (X)', style: xStyle),
          const TextSpan(text: ' vs '),
          TextSpan(text: '$playerOName (O)', style: oStyle),
        ],
      ),
    );
  }

  Widget _buildBoard(Map<String, dynamic> game, User? user) {
    final boardList = _localBoardState ?? List.filled(9, null);

    if (user == null) {
      developer.log(
        'BuildBoard: User is null, cannot build board.',
        name: 'GameBoardScreen.BuildBoard',
      );
      return const Center(child: Text('Login required to play.'));
    }

    final currentUserUID = user.uid;
    final String gameStatus = game['status'];
    final String currentTurn = game['currentTurn'];
    final String? playerXUserId = game['playerX']?['userId'];
    final Map<String, dynamic>? playerOData =
        game['playerO'] as Map<String, dynamic>?;
    final String? playerOUserId = playerOData?['userId'];

    bool isMyTurnCheck = false;
    if (gameStatus == 'active') {
      if (currentTurn == 'X' && playerXUserId == currentUserUID) {
        isMyTurnCheck = true;
      } else if (currentTurn == 'O' &&
          playerOUserId == currentUserUID) {
        isMyTurnCheck = true;
      }
    }

    developer.log(
      'BuildBoard Check: Status="$gameStatus", Turn="$currentTurn", '
      'PlayerX="$playerXUserId", PlayerO="$playerOUserId", '
      'CurrentUser="$currentUserUID" => isMyTurn=$isMyTurnCheck',
      name: 'GameBoardScreen.BuildBoard',
    );

    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: boardList.length,
      itemBuilder: (context, index) {
        final String notation = _getChessNotation(index);
        final String? cellValue =
            boardList.length > index ? boardList[index]?.toString() : null;
        final String displayValue = cellValue ?? notation;

        final bool cellValueIsNullCheck = cellValue == null;
        final bool canTap =
            gameStatus == 'active' &&
                isMyTurnCheck &&
                cellValueIsNullCheck;

        if (index == 4) {
          developer.log(
            'Cell $index Check: active=${gameStatus == 'active'}, '
            'isMyTurn=$isMyTurnCheck, cellNull=$cellValueIsNullCheck '
            '(value="$cellValue") => canTap=$canTap',
            name: 'GameBoardScreen.BuildBoard.Cell',
          );
        }

        return GestureDetector(
          onTap: canTap
              ? () {
                  final String player =
                      (playerXUserId == currentUserUID) ? 'X' : 'O';
                  developer.log(
                    'Cell $index TAPPED by Player $player. '
                    'Current local value: "${_localBoardState?[index]}"',
                    name: 'GameBoardScreen.Tap',
                  );

                  setState(() {
                    _localBoardState ??= List.filled(9, null);
                    if (index >= 0 &&
                        index < _localBoardState!.length) {
                      if (_localBoardState![index] == null) {
                        _localBoardState![index] = player;
                        developer.log(
                          'Optimistic Update: Set cell $index to $player',
                          name: 'GameBoardScreen.Tap',
                        );
                      } else {
                        developer.log(
                          'Optimistic Update SKIPPED: '
                          'Cell $index already has value '
                          '"${_localBoardState![index]}"',
                          name: 'GameBoardScreen.Tap',
                        );
                        return;
                      }
                    } else {
                      developer.log(
                        'Optimistic Update ERROR: Invalid index $index',
                        name: 'GameBoardScreen.Tap',
                      );
                      return;
                    }
                  });

                  _makeMove(index, game);
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4.0),
              color: canTap
                  ? Colors.lightBlue.shade50
                  : (cellValue == null
                      ? Colors.white
                      : Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cellValue == 'X'
                      ? Colors.redAccent
                      : (cellValue == 'O'
                          ? Colors.blueAccent
                          : (canTap
                              ? Colors.black54
                              : Colors.grey.shade600)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _joinGame(User user) {
    developer.log(
      'Attempting to join game ${widget.gameId} as Player O.',
      name: 'GameBoardScreen.Join',
    );
    FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .update({
      'playerO': {
        'userId': user.uid,
        'displayName':
            user.displayName ?? user.email ?? 'Player O',
      },
      'status': 'active',
    }).then((_) {
      developer.log(
        'Successfully joined game. Status set to active.',
        name: 'GameBoardScreen.Join',
      );
    }).catchError((error) {
      developer.log(
        'Failed to join game: $error',
        name: 'GameBoardScreen.Join',
        error: error,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining game: $error')),
        );
      }
    });
  }

  void _makeMove(int index, Map<String, dynamic> game) async {
    if (_currentUser == null) {
      developer.log(
        'MakeMove Error: Current user is null.',
        name: 'GameBoardScreen.MakeMove',
      );
      return;
    }

    final String player = game['playerX']?['userId'] ==
            _currentUser!.uid
        ? 'X'
        : 'O';

    developer.log(
      'Attempting move at index $index by Player $player.',
      name: 'GameBoardScreen.MakeMove',
    );

    final boardAfterMove = List<dynamic>.from(
      _localBoardState ?? List.filled(9, null),
    );

    if (index < 0 ||
        index >= boardAfterMove.length ||
        boardAfterMove[index] != player) {
      developer.log(
        'MakeMove Firestore Update SKIPPED. Mismatch. '
        'Index: $index, Expected: $player, '
        'BoardValue: "${boardAfterMove.length > index ? boardAfterMove[index] : 'OOB'}"',
        name: 'GameBoardScreen.MakeMove',
        level: 900,
      );
      return;
    }

    final move = {
      'position': index,
      'player': player,
      'notation': _getChessNotation(index),
    };

    final String? winner = _checkWinner(boardAfterMove);
    final String nextTurn = player == 'X' ? 'O' : 'X';
    final String newStatus = game['status'];

    final Map<String, dynamic> updateData = {
      'board': boardAfterMove,
      'moves': FieldValue.arrayUnion([move]),
      'lastMoveTimestamp': FieldValue.serverTimestamp(),
    };

    if (winner != null) {
      developer.log(
        'Winner detected: $winner',
        name: 'GameBoardScreen.MakeMove',
      );
      updateData['winner'] = winner;
      updateData['status'] = 'completed';
      updateData['endedAt'] =
          FieldValue.serverTimestamp();
    } else {
      updateData['currentTurn'] = nextTurn;
      if (newStatus != 'active') {
        updateData['status'] = 'active';
      }
    }

    developer.log(
      'Updating Firestore with keys: ${updateData.keys.toList()}',
      name: 'GameBoardScreen.MakeMove',
    );

    await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .update(updateData)
        .then((_) {
      developer.log(
        'Firestore update successful for move at index $index.',
        name: 'GameBoardScreen.MakeMove',
      );
    }).catchError((error) {
      developer.log(
        'Firestore update FAILED: $error',
        name: 'GameBoardScreen.MakeMove',
        error: error,
        level: 1000,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making move: $error')),
        );
      }
    });
  }

  String _getChessNotation(int index) {
    final row = ['a', 'b', 'c'][index ~/ 3];
    final col = ['1', '2', '3'][index % 3];
    return '$row$col';
  }

  String? _checkWinner(List board) {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      if (board.length > line[2] &&
          board[line[0]] != null &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        return board[line[0]]?.toString();
      }
    }
    if (!board.contains(null)) return 'draw';
    return null;
  }
}
