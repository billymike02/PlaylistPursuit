import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:queue_quandry/pages/home.dart';
import 'package:queue_quandry/pages/login.dart';
import 'package:queue_quandry/styles.dart';
import 'game.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../spotify-api.dart';
import '../main.dart';
import 'package:queue_quandry/multiplayer.dart';

// Define a GlobalKey<NavigatorState>
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

int songsPerPlayer = 2;
List<String> playbackQueue = [];
int local_songsQueued = 0;

class LobbyPage extends StatefulWidget {
  final int songsPerPlayer;
  final bool init;
  late String gameCode;
  bool bKicked;

  LobbyPage(
      {Key? key,
      required this.init,
      required this.gameCode,
      this.songsPerPlayer = 1,
      this.bKicked = false})
      : super(key: key);

  @override
  _LobbyPageState createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  Future<void> _createLobby() async {
    await initLobby(widget.gameCode);
  }

  void showKickedMessage() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text("Kicked from Lobby"),
          content: Text("The host has removed you from their lobby."),
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
  }

  Future<void> _handleLobbySetup() async {
    // Execute default local behavior
    if (widget.init == true) {
      // Clear the player list
      bLocalHost.value = true;
      playerList.value.clear();

      await _createLobby();
    }

    firestoreService.listenForChanges();
  }

  @override
  void initState() {
    super.initState();

    if (widget.bKicked)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // This code will run after the build is complete
        showKickedMessage();
      });

    _handleLobbySetup();
  }

  Future<void> removePlayer(Player playerInstance) async {
    await firestoreService.removePlayerFromServer(playerInstance);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: spotifyBlack,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      backgroundColor: spotifyBlack,
      body: Padding(
          padding: EdgeInsets.only(left: 18, right: 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.gameCode}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 50,
                        fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () {
                            _share();
                          },
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 15),
                          color: CupertinoColors.activeGreen,
                          child: Container(
                            child: Row(
                              children: [
                                Text(
                                  "Invite",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500),
                                ),
                                SizedBox(
                                  width: 5,
                                ),
                                Icon(
                                  Icons.ios_share_outlined,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ],
                              mainAxisAlignment: MainAxisAlignment.center,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 7,
                      ),
                      if (bLocalHost.value)
                        Expanded(
                          child: CupertinoButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return BottomSheetSlider(); // Use the new stateful widget
                                },
                              );
                            },
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 15),
                            color: Colors.white,
                            child: Container(
                              child: Row(
                                children: [
                                  Text(
                                    "Settings",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Icon(
                                    Icons.settings,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                ],
                                mainAxisAlignment: MainAxisAlignment.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                ],
              ),
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

                        if (playerInstance.isInitialized() == false) {
                          return Container();
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 6, bottom: 6),
                          child: PlayerListing(
                            color: spotifyGrey,
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
              children: [],
            ),
            const Spacer(),
            Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<List<Player>>(
                      valueListenable: playerList,
                      builder: (context, value, child) {
                        if (playerList.value.length > 0 &&
                            bLocalHost.value == true) {
                          return Center(
                            child: CupertinoButton(
                                color: CupertinoColors.systemIndigo,
                                onPressed: () {
                                  _setQueueingState();
                                },
                                child: const Row(
                                  children: [
                                    Text(
                                      'Let\'s Play',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                          fontFamily: 'Gotham'),
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ],
                                  mainAxisAlignment: MainAxisAlignment.center,
                                )),
                          );
                        }

                        return Container();
                      }),
                  SizedBox(height: 65),
                ]),
          ])),
    );
  }

  Future<void> _setQueueingState() async {
    // Navigate to the next page
    await firestoreService.Host_SetGameState(1);
  }

  void _share() async {
    final result = await Share.share(
        'Here\'s my game code for Playlist Pursuit: ${widget.gameCode}',
        subject: "Invite to Game");
  }
}

class BottomSheetSlider extends StatefulWidget {
  @override
  _BottomSheetSliderState createState() => _BottomSheetSliderState();
}

class _BottomSheetSliderState extends State<BottomSheetSlider> {
  double _currentSliderValue = songsPerPlayer.toDouble();
  String? _sliderStatus;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        width: MediaQuery.of(context).size.width,
        color: spotifyGrey, // Add your specific color
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lobby Settings',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10.0),
              Text(
                'Songs per player: ${_currentSliderValue.toInt()}',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              // Display the current slider value.
              Container(
                width: MediaQuery.of(context).size.width,
                child: CupertinoSlider(
                  key: const Key('slider'),
                  value: _currentSliderValue,
                  // This allows the slider to jump between divisions.
                  // If null, the slide movement is continuous.
                  divisions: 9,
                  // The maximum slider value
                  max: 10,
                  min: 1,
                  activeColor: CupertinoColors.activeGreen,
                  thumbColor: CupertinoColors.activeGreen,
                  // This is called when sliding is started.
                  // This is called when slider value is changed.
                  onChanged: (double value) {
                    setState(() {
                      _currentSliderValue = value;
                    });

                    firestoreService.setSongsPerPlayer(value.toInt());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<List<String>> fetchTopSongs() async {
    return await getTopTracks(myToken);
  }

  Future<void> _getHostingStatus() async {
    bLocalHost.value = await getHost(local_client_id);
  }

  @override
  void initState() {
    super.initState();

    queue_pos = 0;
    playbackQueue = [];
    local_songsQueued = 0;
    firestoreService.Host_clearQueue();

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
            ValueListenableBuilder<List<dynamic>>(
                valueListenable: playlist,
                builder: (context, value, child) {
                  return Builder(builder: (BuildContext context) {
                    if (bLocalHost.value == true) {
                      int start_requirment =
                          playerList.value.length * songsPerPlayer;

                      if (playlist.value.length >= start_requirment) {
                        return Center(
                          child: CupertinoButton(
                              color: CupertinoColors.activeBlue,
                              onPressed: () async {
                                if (await getPlaybackState() != true) {
                                  showConnectionError();

                                  return;
                                }

                                if (bLocalHost.value == true) {
                                  // await firestoreService
                                  //     .Host_ShufflePlaybackOrder();

                                  List<String> track_ids = [];

                                  for (int i = 0;
                                      i < playlist.value.length;
                                      i++) {
                                    track_ids.add(
                                        "spotify:track:${playlist.value[i].keys.first}");
                                  }

                                  await playAllTracks(track_ids);

                                  await firestoreService.Host_setCurrentTrack(
                                      playlist.value[0].keys.first);
                                  await firestoreService.Host_SetGameState(2);
                                }
                              },
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              child: const Row(
                                children: [
                                  Text(
                                    'Start Match',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        fontFamily: 'Gotham'),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Icon(
                                    Icons.gamepad_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ],
                                mainAxisAlignment: MainAxisAlignment.center,
                              )),
                        );
                      } else if (local_songsQueued < songsPerPlayer) {
                        int remainingSongs =
                            widget.songsPerPlayer - local_songsQueued;

                        String message = "";

                        if (remainingSongs > 0)
                          message = "Add " +
                              remainingSongs.toString() +
                              " more songs";
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
                          widget.songsPerPlayer - local_songsQueued;

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
            SizedBox(height: 45),
          ],
        ),
      ),
    );
  }

  void showConnectionError() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text("Unable to Begin Playback"),
          content: Text(
              "Ensure your device is currently playing from Spotify and try again."),
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

    if (playlist.value.any((map) => map.containsKey(widget.track.track_id))) {
      isChecked.value = true;
    }
  }

  Future<void> _firestoreAddSong() async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(widget.gameCode);

    // Fetch the current data from the document
    DocumentSnapshot docSnapshot = await gameRef.get();

    if (docSnapshot.exists) {
      // Get the current list
      List<dynamic> currentList =
          List<dynamic>.from(docSnapshot.get('playlist') ?? []);

      // Add the new entry to the list
      currentList.add({widget.track.track_id: local_client_id});

      // Update the document with the new list
      await gameRef.update({'playlist': currentList});
      playlist.notifyListeners();
    } else {
      // Handle the case where the document does not exist
      print("Document does not exist.");
    }
  }

  Future<void> _firestoreRemoveSong() async {
    DocumentReference gameRef =
        FirebaseFirestore.instance.collection('games').doc(widget.gameCode);

    // Fetch the current data from the document
    DocumentSnapshot docSnapshot = await gameRef.get();

    if (docSnapshot.exists) {
      // Get the current list
      List<dynamic> currentList =
          List<dynamic>.from(docSnapshot.get('playlist') ?? []);

      // Remove the map from the list using custom equality check
      currentList.removeWhere((item) {
        if (item is Map<String, dynamic>) {
          // Check if the map matches the map to remove
          return MapEquality()
              .equals(item, {widget.track.track_id: local_client_id});
        }
        return false;
      });

      // Update the document with the new list
      await gameRef.update({'playlist': currentList});
      playlist.notifyListeners();
    } else {
      // Handle the case where the document does not exist
      print("Document does not exist.");
    }
  }

  Future<void> _awaitTrackLoad() async {
    while (widget.track.isInitialized() == false)
      await Future.delayed(Duration(milliseconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _awaitTrackLoad(),
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
                          local_songsQueued + 1 > songsPerPlayer) {
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
                        local_songsQueued++;
                        _firestoreAddSong();
                      } else {
                        local_songsQueued--;
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
  final Color color;
  bool showScore;

  PlayerListing(
      {required this.playerInstance,
      this.onRemove,
      this.showScore = false,
      required this.color});

  @override
  _PlayerListingState createState() => _PlayerListingState();
}

class _PlayerListingState extends State<PlayerListing> {
  bool enableKicking = false;
  bool bHost = bLocalHost.value;

  /// Enables the option to kick a player if you're the host and the player is not yourself.
  Future<void> _setKicking() async {
    // if the user is remote and the local user is the host then able kicking
    if (widget.playerInstance.getUserID() != local_client_id &&
        await getHost(local_client_id)) {
      enableKicking = true;
      bHost = false;
    } else if (await getHost(widget.playerInstance.getUserID())) {
      bHost = true;
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
        color: widget.color,
      ),
      padding: EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.network(
              widget.playerInstance.getImageURL(),
              width: 35,
              height: 35,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.playerInstance.getDisplayName(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.showScore == true)
            Text(
              widget.playerInstance.getScore().toString(),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            )
          else if (bHost == true)
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
            )

          // Enable the kicking option if it's allowed for the player

          else if (enableKicking)
            CupertinoButton(
              padding: EdgeInsets.all(0),
              minSize: 0,
              onPressed: () {
                showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Text("Confirm"),
                      content: Text(
                          "Are you sure you want to kick ${widget.playerInstance.getDisplayName()} from the lobby?"),
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
                  color: CupertinoColors.destructiveRed,
                  size: 30,
                ),
              ),
            )
        ],
      ),
    );
  }
}
