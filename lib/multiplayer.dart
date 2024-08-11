import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:queue_quandry/main.dart';
import 'package:queue_quandry/pages/game.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'package:queue_quandry/pages/login.dart';
import 'spotify-api.dart';

String local_client_id = "<no-user>";
ValueNotifier<List<Player>> playerList = ValueNotifier<List<Player>>([]);
ValueNotifier<List<int>> scoreboard = ValueNotifier<List<int>>([]);
ValueNotifier<Map<String, dynamic>> queued_tracks =
    ValueNotifier<Map<String, dynamic>>({});
bool bSongChange = false;

// Store the game ID locally
late String server_id;
ValueNotifier<bool> bLocalHost = ValueNotifier<bool>(false);

String generateGameCode() {
  // Generate a custom ID here (e.g., using a random string or numeric ID)
  String gameId = 'game_${DateTime.now().millisecondsSinceEpoch}';

  // Trim to the last 4 characters
  if (gameId.length > 4) {
    gameId = gameId.substring(gameId.length - 4);
  }

  return gameId;
}

Future<void> initLobby(String gameCode) async {
  firestoreService.ResetData();

  try {
    CollectionReference gamesRef =
        FirebaseFirestore.instance.collection('games');

    // Create a new game document with custom ID and initial data
    DocumentReference newGameRef = gamesRef.doc(gameCode);

    await newGameRef.set({
      'players': {},
      'created_at': FieldValue.serverTimestamp(),
      'queued_tracks': {},
      'game_state':
          0, // where 0 means lobby, 1 means queueing, 2 means playing/guessing, etc...
      'host': local_client_id,
      'songs_per_player': 3,
      'current_track': ""
    });

    server_id = newGameRef.id;
    bLocalHost.value = true;
  } catch (e) {
    print('Error creating new game: $e');
  }

  // And now we add the local player
  await addLocalPlayer();
  await initAllPlayers();

  // DEBUG
  // await debug_addRemotePlayers();
}

Future<void> debug_addRemotePlayers() async {
// add some multiplayer peeps
  addPlayerToServer("abrawolf");
}

Future<void> initAllPlayers() async {
  await Future.forEach(playerList.value, (Player instance) async {
    if (!instance.isInitialized) {
      await instance.initPlayer();
      String display_name = instance.display_name;
      // print("🟢 Player $display_name joined lobby.");

      playerList.notifyListeners();
    }
  });
}

Future<void> addPlayerToServer(String userID) async {
  DocumentReference gameRef =
      FirebaseFirestore.instance.collection('games').doc(server_id);

  await gameRef.update({'players.$userID': 0});

  if (userID == local_client_id) {
    await gameRef.update({'host': local_client_id});
  }

  // downloadPlayerList();
}

Future<void> addLocalPlayer() async {
  local_client_id = await getLocalUserID();

  await addPlayerToServer(local_client_id);
}

/// Returns true if the supplied player is hosting the lobby.
Future<bool> getHost(String player_id) async {
  DocumentSnapshot gameSnapshot =
      await FirebaseFirestore.instance.collection('games').doc(server_id).get();

  if (gameSnapshot.exists) {
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;
    // Access fields from gameData
    String gameHost = gameData['host'];

    if (gameHost == player_id) {
      return true;
    }
  } else {
    // print('Document does not exist');
  }

  return false;
}

Future<void> downloadTrackQueue() async {
  DocumentSnapshot gameSnapshot =
      await FirebaseFirestore.instance.collection('games').doc(server_id).get();

  if (gameSnapshot.exists) {
    // Clear the locally stored song queue
    queued_tracks.value.clear();

    // Parse the server data for the list of players
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;
    queued_tracks.value = gameData['queued_tracks'];
  } else {
    print('Document does not exist');
  }
}

Future<void> downloadPlayerList() async {
  DocumentSnapshot gameSnapshot =
      await FirebaseFirestore.instance.collection('games').doc(server_id).get();

  if (gameSnapshot.exists) {
    // Clear the locally stored lobby
    playerList.value.clear();
    scoreboard.value.clear();

    // Parse the server data for the list of players
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> players = gameData['players'];

    // Copy these players to the local thing
    players.forEach(
      (key, value) {
        Player newPlayer = Player(key);
        newPlayer.score = value;
        playerList.value.add(newPlayer);
      },
    );

    // Initialize all of them
    initAllPlayers();
  } else {
    print('Document does not exist');
  }
}

Future<int> joinGame(String gameCode) async {
  try {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(gameCode);

    DocumentSnapshot gameDoc = await gameRef.get();

    if (gameDoc.exists) {
      // Add the local player to the session
      await gameRef.update({'players.$local_client_id': 0});

      // print('Joined game with ID: $gameCode');

      // Now we need to update the local fields with the data fetched from the server
      server_id = gameCode;
      bLocalHost.value = await getHost(local_client_id);

      await downloadPlayerList();

      return 0;
    } else {
      // print('Game not found with ID: $gameCode');
    }
  } catch (e) {
    print('Error joining game: $e');
  }

  return -1;
}

void navigateToFinishPage() {
  int maxValue = 0;

  for (int i = 0; i < playerList.value.length; i++) {
    if (playerList.value[i].score >= maxValue) {
      maxValue = playerList.value[i].score;
    }
  }

  bool playerWon = false;

  // if the local player has >= maximum score then they win
  if (playerList.value.any((element) =>
      element.user_id == local_client_id && element.score == maxValue)) {
    playerWon = true;
  }

  navigatorKey.currentState!.push(MaterialPageRoute(
      builder: (context) => FinishPage(playerWon: playerWon)));
}

Future<void> handleScoring() async {
  for (int i = 0; i < playerList.value.length; i++) {
    if (playerList.value[i].user_id == local_client_id && correctGuess) {
      // playerList.value[i].score += 10;
      await firestoreService.Client_incrementScore(10);
      await initAllPlayers();
    }
  }
}

Future<void> navigateToResultPage() async {
  await handleScoring();

  navigatorKey.currentState!.push(
    MaterialPageRoute(
        builder: (context) => ResultPage(
              isCorrect: correctGuess,
              guiltyPlayer: guiltyPlayer,
            )),
  );
}

void navigateToQueueingPage() {
  navigatorKey.currentState!.push(
    MaterialPageRoute(
        builder: (context) => QueuePage(
              gameCode: server_id,
              songsPerPlayer: songsPerPlayer,
            )),
  );
}

void navigateToGuessingPage() {
  navigatorKey.currentState!.push(
    MaterialPageRoute(builder: (context) => GuessingPage()),
  );
}

class FirestoreController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  // Saved fields for update checking
  Map<String, dynamic> previousPlayerList = {};
  Map<String, dynamic> previousTrackQueue = {};
  int previousGameState = 0;
  int previousSongsPerPlayer = 3;
  String previousCurrentTrack = "";

  void ResetData() {
    previousPlayerList = {};
    previousTrackQueue = {};
    previousGameState = 0;
    previousSongsPerPlayer = 3;
    previousCurrentTrack = "";
  }

  void stopListening() {
    _subscription?.cancel();
  }

  Future<void> removePlayerFromServer(Player playerInstance) async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    String playerId = playerInstance.user_id;

    await gameRef
        .update({'players.$playerId': FieldValue.delete()}).whenComplete(() {
      print("player removed from map");
    });
  }

  Future<void> Client_downloadCurrentTrack() async {
    DocumentSnapshot gameSnapshot = await FirebaseFirestore.instance
        .collection('games')
        .doc(server_id)
        .get();

    if (gameSnapshot.exists) {
      Map<String, dynamic> gameData =
          gameSnapshot.data() as Map<String, dynamic>;
      // Access fields from gameData
      current_track = gameData['current_track'];
      bSongChange = true;
    }
  }

  Future<void> Client_incrementScore(int value) async {
    DocumentSnapshot gameSnapshot = await FirebaseFirestore.instance
        .collection('games')
        .doc(server_id)
        .get();

    if (gameSnapshot.exists) {
      Map<String, dynamic> gameData =
          gameSnapshot.data() as Map<String, dynamic>;
      // Access fields from gameData
      Map<String, dynamic>? players =
          gameData['players'] as Map<String, dynamic>?;

      int previousScore = players![local_client_id];

      DocumentReference gameRef =
          FirebaseFirestore.instance.collection('games').doc(server_id);

      await gameRef.update({'players.$local_client_id': previousScore + value});

      print("new score: ${previousScore + value}");
    }
  }

  Future<void> Host_setCurrentTrack(String track_uri) async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    await gameRef.update({'current_track': track_uri});
  }

  Future<void> Host_ShufflePlaybackOrder() async {
    _db.collection('games').doc(server_id).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> currentTrackQueue =
            snapshot.data()!['queued_tracks'] as Map<String, dynamic>;

        List<MapEntry<String, dynamic>> entryList =
            currentTrackQueue.entries.toList();

        entryList.shuffle();
        Map<String, dynamic> shuffledTrackQueue =
            Map<String, dynamic>.fromEntries(entryList);

        DocumentReference gameRef =
            FirebaseFirestore.instance.collection('games').doc(server_id);
        gameRef.update({'queued_tracks': shuffledTrackQueue});

        // print("Shuffled tracks: " + shuffledTrackQueue.toString());
      }
    });
  }

  void listenForChanges() {
    _subscription =
        _db.collection('games').doc(server_id).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> currentPlayerList =
            snapshot.data()!['players'] as Map<String, dynamic>;

        if (mapEquals(previousPlayerList, {}) ||
            _playerListHasChanged(currentPlayerList)) {
          if (currentPlayerList.containsKey(local_client_id) == false) {
            String gameCode = generateGameCode();

            navigatorKey.currentState!.push(
              MaterialPageRoute(
                  builder: (context) => LobbyPage(
                        gameCode: gameCode,
                        init: true,
                        bKicked: true,
                      )),
            );
            return;
          }
          _onPlayerListChange();
        }

        previousPlayerList = Map<String, dynamic>.from(currentPlayerList);

        Map<String, dynamic> currentTrackQueue =
            snapshot.data()!['queued_tracks'] as Map<String, dynamic>;

        if (mapEquals(previousTrackQueue, {}) ||
            _trackQueueHasChanged(currentTrackQueue)) {
          _onTrackQueueChange();
        }

        previousTrackQueue = Map<String, dynamic>.from(currentTrackQueue);

        int currentGameState = snapshot.data()!['game_state'];

        if (previousGameState != currentGameState) {
          _onGameStateChange(currentGameState);
        }

        previousGameState = currentGameState;

        int currentSongsPerPlayer = snapshot.data()!['songs_per_player'];

        if (previousSongsPerPlayer != currentSongsPerPlayer) {
          _onSongsPerPlayerChange(currentSongsPerPlayer);
        }

        previousSongsPerPlayer = currentSongsPerPlayer;

        String currentTrack = snapshot.data()!['current_track'];

        if (previousCurrentTrack != currentTrack) {
          // print('track has changed');

          _onCurrentTrackChange(currentTrack);
        }

        previousCurrentTrack = currentTrack;
      }
    });
  }

  Future<void> setSongsPerPlayer(int newNum) async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    await gameRef.update({'songs_per_player': newNum});
  }

  void _onCurrentTrackChange(String newUri) {
    current_track = newUri;
    bSongChange = true;
  }

  void _onSongsPerPlayerChange(int newNum) {
    //downloadSongsPerPlayer
    songsPerPlayer = newNum;
  }

  Future<void> _onGameStateChange(int newState) async {
    if (newState == 1) {
      navigateToQueueingPage();
    } else if (newState == 2) {
      navigateToGuessingPage();
    } else if (newState == 3) {
      navigateToResultPage();
    } else if (newState == 4) {
      navigateToFinishPage();
    }
  }

  void _onPlayerListChange() {
    downloadPlayerList();
  }

  void _onTrackQueueChange() {
    downloadTrackQueue();
  }

  bool _trackQueueHasChanged(Map<String, dynamic> currentMap) {
    return previousTrackQueue.isNotEmpty &&
        !mapEquals(previousTrackQueue, currentMap);
  }

  bool _playerListHasChanged(Map<String, dynamic> currentMap) {
    return previousPlayerList.isNotEmpty &&
        !mapEquals(previousPlayerList, currentMap);
  }

  bool mapEquals(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  Future<void> Host_SetGameState(int newState) async {
    // update
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);
    await gameRef.update({'game_state': newState});
  }
}
