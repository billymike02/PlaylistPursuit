import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'spotify-api.dart';

String local_client_id = "DefaultUser";
ValueNotifier<List<MyPlayer>> playerList = ValueNotifier<List<MyPlayer>>([]);

// Store the game ID locally
String loaded_session = "";

String generateGameCode() {
  // Generate a custom ID here (e.g., using a random string or numeric ID)
  String gameId = 'game_${DateTime.now().millisecondsSinceEpoch}';

  // Trim to the last 4 characters
  if (gameId.length > 4) {
    gameId = gameId.substring(gameId.length - 4);
  }

  return gameId;
}

Future<void> initLobby() async {

  try {
    CollectionReference gamesRef =
        FirebaseFirestore.instance.collection('games');

    // Create a new game document with custom ID and initial data
    DocumentReference newGameRef = gamesRef.doc(generateGameCode());

    await newGameRef.set({
      'players': {},
      'created_at': FieldValue.serverTimestamp(),
      'queued_tracks': {},
      'started': false,
      'host': local_client_id
    });

    loaded_session = newGameRef.id;
    print('New game created with ID: ${loaded_session}');
  } catch (e) {
    print('Error creating new game: $e');
  }

  // And now we add the local player
  await addLocalPlayer();
  await initAllPlayers();
}

Future<void> initAllPlayers() async {
  // // populate the lobby
  // await addLocalPlayer();
  // addHeadlessPlayer('abrawolf');
  // addHeadlessPlayer('tommyryan2002');
  // addHeadlessPlayer('nickwaizenegger');

  await Future.forEach(playerList.value, (MyPlayer instance) async {
    if (!instance.isInitialized) {
      await instance.initPlayer();
      String display_name = instance.display_name;
      print("🟢 Player $display_name joined lobby.");

      playerList.notifyListeners();
    }
  });
}

Future<void> addPlayerToServer(String userID) async {
  DocumentReference gameRef =
      FirebaseFirestore.instance.collection('games').doc(loaded_session);

  await gameRef.update({'players.$userID': 0});

  if (userID == local_client_id) {
    await gameRef.update({'host': local_client_id});
  }
}

Future<void> removePlayerFromServer(MyPlayer playerInstance) async {
  print("removing player from server");
  DocumentReference gameRef =
      FirebaseFirestore.instance.collection('games').doc(loaded_session);

  String playerId = playerInstance.user_id;

  await gameRef.update({'players.$playerId': FieldValue.delete()});
}

Future<void> addLocalPlayer() async {
  local_client_id = await getLocalUserID();

  playerList.value.add(MyPlayer(local_client_id));
  addPlayerToServer(local_client_id);
}

void addHeadlessPlayer(String id) {
  playerList.value.add(MyPlayer(id));
  addPlayerToServer(id);
}

void addRemotePlayer(String incomingID) {
  playerList.value.add(MyPlayer(incomingID));
  addPlayerToServer(incomingID);
}

/// Returns true if the supplied player is hosting the lobby.
Future<bool> isHost(String player_id) async {
  DocumentSnapshot gameSnapshot = await FirebaseFirestore.instance
      .collection('games')
      .doc(loaded_session)
      .get();

  if (gameSnapshot.exists) {
    Map<String, dynamic> gameData = gameSnapshot.data() as Map<String, dynamic>;
    // Access fields from gameData
    String gameHost = gameData['host'];

    if (gameHost == player_id) {
      return true;
    }
  } else {
    print('Document does not exist');
  }

  return false;
}

Future<void> downloadPlayerList() async {
  DocumentSnapshot gameSnapshot = await FirebaseFirestore.instance
      .collection('games')
      .doc(loaded_session)
      .get();

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
      loaded_session = gameCode;

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
