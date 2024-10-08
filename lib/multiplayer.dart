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
ValueNotifier<List<dynamic>> playlist = ValueNotifier<List<dynamic>>([]);
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
      'playlist': [],
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
    while (instance.isInitialized() == false)
      await Future.delayed(Duration(milliseconds: 10));

    String display_name = instance.getDisplayName();

    playerList.notifyListeners();
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
    playlist.value.clear();

    // Parse the server data for the list of players
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;

    playlist.value = gameData['playlist'];
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
        newPlayer.setScore(value);
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
    if (playerList.value[i].getScore() >= maxValue) {
      maxValue = playerList.value[i].getScore();
    }
  }

  bool playerWon = false;

  // if the local player has >= maximum score then they win
  if (playerList.value.any((element) =>
      element.getUserID() == local_client_id &&
      element.getScore() == maxValue)) {
    playerWon = true;
  }

  navigatorKey.currentState!.push(MaterialPageRoute(
      builder: (context) => FinishPage(playerWon: playerWon)));
}

Future<void> handleScoring() async {
  if (correctGuess) {
    await firestoreService.Client_incrementScore(10);
    await initAllPlayers();
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
  List<Map<String, dynamic>> previousTrackQueue = [];
  int previousGameState = 0;
  int previousSongsPerPlayer = 3;
  String previousCurrentTrack = "";

  void ResetData() {
    previousPlayerList = {};
    previousTrackQueue = [];
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

    String playerId = playerInstance.getUserID();

    await gameRef
        .update({'players.$playerId': FieldValue.delete()}).whenComplete(() {});
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
    }
  }

  Future<void> Host_listenForNextTrack() async {
    String? this_track;

    while (true) {
      await Future.delayed(Duration(seconds: 2));
      this_track = await getCurrentTrack();

      // Ignore null values and continue the loop if the track is null
      if (this_track == null) continue;

      // Break if the track is different from the previous one
      if (this_track != previousCurrentTrack) break;
    }

    // At this point, we have a new track that is not null, so update the current track
    if (this_track != null) {
      await Host_setCurrentTrack(this_track);
      await Host_SetGameState(3);
    }
  }

  Future<void> Host_setCurrentTrack(String song_uri) async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    await gameRef.update({'current_track': song_uri});
  }

  Future<void> Host_ShufflePlaybackOrder() async {
    _db.collection('games').doc(server_id).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> currentTrackQueue =
            snapshot.data()!['playlist'] as Map<String, dynamic>;

        List<MapEntry<String, dynamic>> entryList =
            currentTrackQueue.entries.toList();

        entryList.shuffle();
        Map<String, dynamic> shuffledTrackQueue =
            Map<String, dynamic>.fromEntries(entryList);

        DocumentReference gameRef =
            FirebaseFirestore.instance.collection('games').doc(server_id);
        gameRef.update({'playlist': shuffledTrackQueue});

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

        List<dynamic> currentTrackQueue = snapshot.data()!['playlist'];

        if (previousTrackQueue == [] ||
            _trackQueueHasChanged(currentTrackQueue)) {
          _onTrackQueueChange();
        }

        previousTrackQueue = List<Map<String, dynamic>>.from(currentTrackQueue);

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

  Future<void> _onCurrentTrackChange(String newUri) async {
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

  bool _trackQueueHasChanged(List<dynamic> currentMap) {
    return true;
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

  Future<void> Host_clearQueue() async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    DocumentSnapshot gameDoc = await gameRef.get();

    if (gameDoc.exists) {
      // Add the local player to the session
      await gameRef.update({'playlist': []});
      playlist.notifyListeners();
    }
  }
}
