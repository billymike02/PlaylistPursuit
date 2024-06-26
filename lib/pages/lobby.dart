import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_quandry/pages/login.dart';
import 'package:queue_quandry/styles.dart';
import 'package:spotify_sdk/models/player_options.dart';
import 'game.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../spotify-api.dart';
import '../main.dart';
import 'package:logger/logger.dart';
import 'package:queue_quandry/multiplayer.dart';

// Define a GlobalKey<NavigatorState>
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

int songsPerPlayer = 3;
List<String> playbackQueue = [];

class LobbyPage extends StatefulWidget {
  final int songsPerPlayer;
  final bool init;
  late String gameCode;

  LobbyPage({
    Key? key,
    required this.init,
    this.gameCode = "",
    this.songsPerPlayer = 1,
  }) : super(key: key);

  @override
  _LobbyPageState createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  TextEditingController _textController = TextEditingController();
  String _inputText = '';
  bool bIsHost = false;

  Future<void> _createLobby() async {
    widget.gameCode = generateGameCode();

    await initLobby(widget.gameCode);
  }

  Future<void> _handleLobbySetup() async {
    // Execute default local behavior
    if (widget.init == true) {
      // Clear the player list
      bIsHost = true;
      playerList.value.clear();

      await _createLobby();
    }
    // Execute remote behavior
    else if (widget.gameCode != "") {
      print("loading a lobby...");
    }
    await _getHostingStatus();
    firestoreService.listenForChanges();
  }

  @override
  void initState() {
    super.initState();

    _handleLobbySetup();
  }

  Future<void> _getHostingStatus() async {
    if (await isHost(local_client_id) == true) {
      bIsHost = true;
    }

    setState(() {});
  }

  void removePlayer(Player playerInstance) {
    removePlayerFromServer(playerInstance);

    print("🔴 Removed player ${playerInstance.user_id} from lobby.");

    playerList.notifyListeners();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: spotifyBlack,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      backgroundColor: spotifyBlack,
      body: Padding(
          padding: EdgeInsets.only(left: 18, right: 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Queue Quandary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold),
            ),
            const Text(
              'Contribute anonymously to a playlist. Try to guess who queued each song after they play.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 30),
            Text(
              'Game code: ${widget.gameCode}',
              textAlign: TextAlign.left,
              style: TextStyle(
                  color: spotifyGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 25),
            ),
            SizedBox(
              height: 5,
            ),
            SizedBox(
                height: MediaQuery.of(context).size.height * 0.30,
                child: ValueListenableBuilder<List<Player>>(
                  valueListenable: playerList,
                  builder: (context, value, child) {
                    if (value.length < 1) {
                      return Text(
                        'Loading players...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500),
                      );
                    }

                    return ListView.builder(
                      key: UniqueKey(),
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        final playerInstance = playerList.value[index];

                        if (playerInstance.isInitialized == false) {
                          return Container();
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 6, bottom: 6),
                          child: PlayerListing(
                            playerInstance: playerInstance,
                            onRemove: removePlayer,
                          ),
                        );
                      },
                    );
                  },
                )),
            SizedBox(
              height: 5,
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _share();
                  },
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: Row(
                      children: [
                        Text(
                          "Invite",
                          style: TextStyle(color: Colors.black, fontSize: 18),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Container(
                          height: 30,
                          child: Icon(
                            Icons.ios_share_outlined,
                            color: Colors.black,
                          ),
                        )
                      ],
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  ),
                ),
                SizedBox(
                  width: 5,
                ),
                ElevatedButton(
                  onPressed: () {
                    _showTextFieldDialog(context);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: spotifyGreen),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.17,
                    child: Row(
                      children: [
                        Text(
                          "Join",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Container(
                          height: 30,
                          child: Icon(
                            Icons.install_mobile,
                            color: Colors.white,
                          ),
                        )
                      ],
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bIsHost)
                    Column(
                      children: [
                        const Text(
                          "Songs Per Player",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                              top: 5,
                              right: MediaQuery.of(context).size.width * 0.7),
                          child: _buildDropdown(
                            'Songs Per Player',
                            songsPerPlayer,
                            (value) {
                              setState(() {
                                songsPerPlayer = value!;

                                firestoreService.setSongsPerPlayer(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ValueListenableBuilder<List<Player>>(
                      valueListenable: playerList,
                      builder: (context, value, child) {
                        if (playerList.value.length > 1 && bIsHost) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    _setQueueingState();

                                    navigateToQueueingPage();
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: spotifyPurple,
                                      minimumSize: Size(150, 50)),
                                  child: const Text(
                                    'Continue',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        fontFamily: 'Gotham'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container();
                      }),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                  )
                ]),
          ])),
      // Container(
      //   decoration: BoxDecoration(color: Colors.red),
      //   height: MediaQuery.of(context).size.height * 0.2,
      // ),
    );
  }

  Future<void> _setQueueingState() async {
    await firestoreService.Host_SetGameState(1);
  }

  Future<void> _attemptJoinGame(String code) async {
    int result = await joinGame(code);

    // If the connection fails, inform the user.
    if (result != 0) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text("Unable to Connect to Lobby"),
            content: Text("\"$code\" is an invalid game code."),
            actions: <Widget>[
              CupertinoDialogAction(
                child: Text("OK", style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      return;
    }

    _joinLobby(code);
  }

  void _joinLobby(String code) {
    // Navigate to the new lobby page
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyPage(
            gameCode: code,
            init: false,
          ),
        ));
  }

  void _showTextFieldDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: spotifyBlack,
          title: Text(
            'Connect to Lobby',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _textController,
            decoration: InputDecoration(
                hintText: 'Game Code',
                hintStyle: TextStyle(color: Colors.grey)),
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Join',
                style: TextStyle(color: spotifyGreen),
              ),
              onPressed: () {
                setState(() {
                  _inputText = _textController.text;
                  _textController.clear();

                  _attemptJoinGame(_inputText);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _share() async {
    final result = await Share.share(
        'Here\'s my game code for Playlist Pursuit: ${widget.gameCode}',
        subject: "Invite to Game");
  }
}

DropdownButtonFormField<int> _buildDropdown(
    String label, int currentValue, void Function(int?)? onChanged) {
  return DropdownButtonFormField<int>(
    decoration: InputDecoration(
      fillColor: Color.fromARGB(255, 41, 41, 41),
      filled: true,
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(
            Radius.circular(10.0),
          )),
    ),
    value: currentValue,
    dropdownColor: Color.fromARGB(255, 41, 41, 41),
    focusColor: Color.fromARGB(255, 41, 41, 41),
    iconEnabledColor: Color.fromARGB(255, 41, 41, 41),
    style: TextStyle(color: const Color.fromRGBO(255, 255, 255, 1)),
    borderRadius: BorderRadius.all(Radius.circular(8)),
    items: List.generate(10, (index) => index + 1)
        .map((num) => DropdownMenuItem<int>(
              value: num,
              child: Padding(
                padding: EdgeInsets.only(
                    left: 18), // Adjust the right padding as needed
                child: Text(num.toString(),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ))
        .toList(),
    onChanged: onChanged,
    isExpanded: true,
  );
}

class QueuePage extends StatefulWidget {
  final int songsPerPlayer;
  final String gameCode;

  const QueuePage(
      {Key? key,
      required this.songsPerPlayer,
      required this.gameCode,
      required})
      : super(key: key);

  @override
  _QueuePageState createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  TextEditingController _controller = TextEditingController();

  bool isSearching = false;
  Future<List<String>>? _fetchTopSongsFuture;
  Future<List<String>>? _searchedSongs;
  late bool bIsHost = false;

  Future<List<String>> fetchTopSongs() async {
    return await getTopTracks(myToken);
  }

  Future<void> _getHostingStatus() async {
    bIsHost = await isHost(local_client_id);
  }

  @override
  void initState() {
    super.initState();

    playbackQueue = [];
    _fetchTopSongsFuture = fetchTopSongs();

    _getHostingStatus();
  }

  Future<void> _search(String query) async {
    _searchedSongs = searchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: spotifyBlack,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Add Some Songs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: spotifyBlack,
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _controller,
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.w400),
              onChanged: (value) {
                setState(() {
                  isSearching = value.isNotEmpty;
                });
                String searchTerm = value;
                _search(searchTerm);
              },
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                hintText: 'What do you want to listen to?',
                hintStyle: TextStyle(color: Colors.black),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 30),
            isSearching
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Search results",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Your top songs",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            isSearching
                ? Expanded(
                    child: FutureBuilder(
                        future: _searchedSongs,
                        builder:
                            (context, AsyncSnapshot<List<String>> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                'Loading...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error searching query'));
                          } else {
                            return ListView.builder(
                                itemCount: 5,
                                itemBuilder: (BuildContext context, int index) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: SongListing(
                                      gameCode: widget.gameCode,
                                      track: Track(snapshot.data![index]),
                                    ),
                                  );
                                });
                          }
                        }))
                : Expanded(
                    child: FutureBuilder(
                      future: _fetchTopSongsFuture,
                      builder: (context, AsyncSnapshot<List<String>> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              'Loading tracks...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500),
                            ),
                          );
                        } else {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error fetching top songs'));
                          } else {
                            return ListView.builder(
                              itemCount: snapshot.data!.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: SongListing(
                                    gameCode: widget.gameCode,
                                    track: Track(snapshot.data![index]),
                                  ),
                                );
                              },
                            );
                          }
                        }
                      },
                    ),
                  ),
            SizedBox(
              height: 10,
            ),
            ValueListenableBuilder<List<String>>(
                valueListenable: songQueue,
                builder: (context, value, child) {
                  return Builder(builder: (BuildContext context) {
                    bool _enableButton = false; // true jsut for debug

                    if (widget.songsPerPlayer - songQueue.value.length <= 0) {
                      _enableButton = true;
                    }

                    if (_enableButton && bIsHost) {
                      int start_requirment =
                          playerList.value.length * songsPerPlayer;

                      print(
                          "Songs queued: ${songQueue.value.length} songs required: $start_requirment}");

                      if (songQueue.value.length >= start_requirment) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              firestoreService.Host_SetGameState(2);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GuessingPage()),
                              );
                            },
                            child: Text(
                              "Start Game",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              backgroundColor: spotifyGreen,
                            ),
                          ),
                        );
                      } else {
                        return Center(
                            child: Text(
                          "Waiting for other players.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ));
                      }
                    } else {
                      int remainingSongs =
                          widget.songsPerPlayer - songQueue.value.length;

                      String message = "";

                      if (remainingSongs > 0)
                        message =
                            "Add " + remainingSongs.toString() + " more songs";
                      else
                        message = "Waiting for host.";

                      return Center(
                          child: Text(
                        message,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ));
                    }
                  });
                }),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class SongListing extends StatefulWidget {
  final Track track;

  final String gameCode;

  SongListing({
    required this.track,
    required this.gameCode,
  });

  @override
  _SongListingState createState() => _SongListingState();
}

class _SongListingState extends State<SongListing> {
  ValueNotifier<bool> isChecked = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    if (songQueue.value.contains(widget.track.track_id)) {
      isChecked.value = true;
    }
  }

  Future<void> _firestoreAddSong() async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(widget.gameCode);

    await gameRef
        .update({'queued_tracks.${widget.track.track_id}': local_client_id});

    await firestoreService.Host_ShufflePlaybackOrder();
  }

  Future<void> _firestoreRemoveSong() async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(widget.gameCode);

    await gameRef.update(
        {'queued_tracks.${widget.track.track_id}': FieldValue.delete()});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: widget.track.fetchTrackData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              color: Color.fromARGB(255, 41, 41, 41),
            ),
            padding: EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.track.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.track.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                GestureDetector(
                    onTap: () {
                      if (!isChecked.value &&
                          songQueue.value.length + 1 > songsPerPlayer) {
                        showCupertinoDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoAlertDialog(
                              title: Text("Queue Limit Reached"),
                              content: Text(
                                  "You can't add more than $songsPerPlayer songs."),
                              actions: <Widget>[
                                CupertinoDialogAction(
                                  child: Text("OK",
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        return;
                      }

                      isChecked.value = !isChecked.value;
                      if (isChecked.value) {
                        songQueue.value = List.from(songQueue.value)
                          ..add(widget.track.track_id);

                        _firestoreAddSong();
                      } else {
                        songQueue.value = List.from(songQueue.value)
                          ..remove(widget.track.track_id);

                        _firestoreRemoveSong();
                      }
                    },
                    child: ValueListenableBuilder<bool>(
                        valueListenable: isChecked,
                        builder: (context, value, child) {
                          return Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isChecked.value ? Colors.green : Colors.white,
                            ),
                            child: Icon(
                              isChecked.value ? Icons.check : Icons.add,
                              color:
                                  isChecked.value ? Colors.white : Colors.black,
                              size: 20,
                            ),
                          );
                        })),
                SizedBox(width: 3),
              ],
            ),
          );
        }
      },
    );
  }
}

class PlayerListing extends StatefulWidget {
  final Player playerInstance;
  final Function(Player)? onRemove;

  PlayerListing({
    required this.playerInstance,
    this.onRemove,
  });

  @override
  _PlayerListingState createState() => _PlayerListingState();
}

class _PlayerListingState extends State<PlayerListing> {
  bool enableKicking = false;
  bool bIsHost = false;

  /// Enables the option to kick a player if you're the host and the player is not yourself.
  Future<void> _setKicking() async {
    // if the user is remote and the local user is the host then able kicking
    if (widget.playerInstance.user_id != local_client_id &&
        await isHost(local_client_id)) {
      enableKicking = true;
    }

    if (await isHost(widget.playerInstance.user_id)) {
      bIsHost = true;

      // print(widget.playerInstance.user_id + "is given host icon");
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _setKicking();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        color: Color.fromARGB(255, 41, 41, 41),
      ),
      padding: EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.network(
              widget.playerInstance.image,
              width: 35,
              height: 35,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.playerInstance.display_name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (bIsHost)
            GestureDetector(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),

          // Enable the kicking option if it's allowed for the player

          if (enableKicking)
            GestureDetector(
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Text("Confirm"),
                      content: Text(
                          "Are you sure you want to kick ${widget.playerInstance.display_name} from the lobby?"),
                      actions: [
                        CupertinoDialogAction(
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        CupertinoDialogAction(
                          child: Text(
                            "Kick",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onPressed: () {
                            setState(() {
                              widget.onRemove?.call(widget.playerInstance);
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            )
        ],
      ),
    );
  }
}
