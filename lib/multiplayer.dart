import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_quandry/pages/game.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'spotify-api.dart';

String local_client_id = "DefaultUser";
ValueNotifier<List<MyPlayer>> playerList = ValueNotifier<List<MyPlayer>>([]);

// Store the game ID locally
late String server_id;

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
      'songs_per_player': 3
    });

    server_id = newGameRef.id;
    print('New game created with ID: ${server_id}');
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
  await Future.forEach(playerList.value, (MyPlayer instance) async {
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
}

Future<void> removePlayerFromServer(MyPlayer playerInstance) async {
  DocumentReference gameRef =
      FirebaseFirestore.instance.collection('games').doc(server_id);

  String playerId = playerInstance.user_id;

  await gameRef.update({'players.$playerId': FieldValue.delete()});
}

Future<void> addLocalPlayer() async {
  local_client_id = await getLocalUserID();

  await addPlayerToServer(local_client_id);
}

/// Returns true if the supplied player is hosting the lobby.
Future<bool> isHost(String player_id) async {
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

Future<void> downloadPlayerList() async {
  DocumentSnapshot gameSnapshot =
      await FirebaseFirestore.instance.collection('games').doc(server_id).get();

  if (gameSnapshot.exists) {
    // Clear the locally stored lobby
    playerList.value.clear();

    // Parse the server data for the list of players
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> players = gameData['players'];

    // Copy these players to the local thing
    players.forEach(
      (key, value) {
        MyPlayer newPlayer = MyPlayer(key);
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

      print('Joined game with ID: $gameCode');

      // Now we need to update the local fields with the data fetched from the server
      server_id = gameCode;

      await downloadPlayerList();

      return 0;
    } else {
      print('Game not found with ID: $gameCode');
    }
  } catch (e) {
    print('Error joining game: $e');
  }

  return -1;
}

Future<void> startPlayerListen() async {
  DocumentReference reference =
      FirebaseFirestore.instance.collection('games').doc(server_id);
  reference.snapshots().listen((querySnapshot) {
    print("NEW PLAYER LIST OUTTA BE DOWNLOADED!");
    downloadPlayerList();
  });
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

  // Saved fields for update checking
  Map<String, dynamic> previousMap = {};
  // Map<String, dynamic> previousTrackQueue 
  int previousGameState = 0;
  int previousSongsPerPlayer = 3;

  void listenForChanges() {
    _db.collection('games').doc(server_id).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> currentMap =
            snapshot.data()!['players'] as Map<String, dynamic>;

        if (mapEquals(previousMap, {}) || _mapHasChanged(currentMap)) {
          _onPlayerListChange();
        }

        previousMap = Map<String, dynamic>.from(currentMap);

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
      }
    });
  }

  Future<void> setSongsPerPlayer(int newNum) async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(server_id);

    await gameRef.update({'songs_per_player': newNum});
  }

  void _onSongsPerPlayerChange(int newNum) {
    // idk
  }

  void _onGameStateChange(int newState) {
    if (newState == 1) {
      navigateToQueueingPage();
    } else if (newState == 2) {
      navigateToGuessingPage();
    }
  }

  void _onPlayerListChange() {
    downloadPlayerList();
  }

  bool _mapHasChanged(Map<String, dynamic> currentMap) {
    return previousMap.isNotEmpty && !mapEquals(previousMap, currentMap);
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
