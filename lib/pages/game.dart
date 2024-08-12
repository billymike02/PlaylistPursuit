import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:queue_quandry/main.dart';
import 'package:queue_quandry/pages/home.dart';
import 'package:queue_quandry/pages/login.dart';
import 'package:http/http.dart' as http;
import 'package:queue_quandry/spotify-api.dart';
import "../credentials.dart";
import 'package:flutter/material.dart';
import 'lobby.dart';
import 'package:queue_quandry/styles.dart';
import 'dart:convert';
import 'package:queue_quandry/multiplayer.dart';

final int winningScore = 10;
bool musicPlaying = true;
late Player guiltyPlayer;
// Local fields
bool correctGuess = false;
List<bool> buttonsPressed = [];

String current_track = "";
int queue_pos = 0;

class GuessingPage extends StatefulWidget {
  GuessingPage({
    Key? key,
  }) : super(key: key);
  @override
  _GuessingPageState createState() => _GuessingPageState();
}

class _GuessingPageState extends State<GuessingPage> {
  bool _trackDataLoaded = false;

  // Fields (to be mutated by Spotify API)
  late String songName;
  late String songArtist;
  late String albumArt;
  late int songLength;

  Timer? timer;
  String new_song = "NULL";

  Future<void> getNewTrack() async {
    // wait for song change to be detected
    while (bSongChange == false) {
      await Future.delayed(Duration(milliseconds: 10)); // Check every 100ms
    }

    await playTrack(current_track);

    await firestoreService.Client_downloadCurrentTrack();
    bSongChange = false;

    var data = await getTrackInfo(current_track);
    songName = data['name'];

    songArtist = data['artists'][0]['name'];
    albumArt = data['album']['images'][0]['url'];
    songLength = (data['duration_ms'] / 1000).toInt();

    _trackDataLoaded = true;
    setState(() {});
  }

  void _handleButtonPressed(int index, String buttonName) {
    buttonsPressed[index] = true;

    if (buttonName == guiltyPlayer.getUserID()) {
      correctGuess = true;
    }
  }

  @override
  void initState() {
    super.initState();

    buttonsPressed = [];
    correctGuess = false;

    for (int i = 0; i < playerList.value.length; i++) {
      buttonsPressed.add(false);
    }

    if (bLocalHost.value == true) {
      playbackQueue = [];

      for (int i = 0; i < playlist.value.length; i++) {
        new_song = playlist.value[i].keys.first;
        playbackQueue.add(new_song);
      }

      firestoreService.Host_setCurrentTrack(playbackQueue[queue_pos]);
    }

    List<String> guilty_players = [];

    for (int i = 0; i < playlist.value.length; i++) {
      String guiltyName = playlist.value[i].values.first;
      guilty_players.add(guiltyName);
    }

    guiltyPlayer = Player(playlist.value[queue_pos].values.first);
    playlist.value.remove(new_song);

    queue_pos++;
    getNewTrack();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _handlePause() async {
    musicPlaying = !musicPlaying;

    if (musicPlaying == false)
      while (await isPlaying() == true) {
        await pausePlayback();
      }
    else
      while (await isPlaying() == false) {
        await resumePlayback();
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_trackDataLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFF8300e7),
        body: Center(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.1,
              ),
              const Text(
                'Who queued it?',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                child: Builder(
                  builder: (context) {
                    if (_trackDataLoaded) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              albumArt,
                              height: 200,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            songName,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            songArtist,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 45, vertical: 10),
                  shrinkWrap: true,
                  itemCount: playerList.value.length,
                  itemBuilder: (context, index) {
                    Player buttonPlayer = playerList.value[index];

                    // Don't draw a button with the local player's name
                    if (local_client_id == buttonPlayer.getUserID()) {
                      return Container();
                    }

                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _handleButtonPressed(
                                index, buttonPlayer.getUserID());
                          });
                        },
                        child: Text(
                          buttonPlayer.getDisplayName(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(Size(200, 70)),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (buttonsPressed[index] == true) {
                                return Color(0xFF5e03a6);
                              } else {
                                return Color(0xFF7202ca);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Visibility(
                visible: bLocalHost.value,
                child: Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.07,
                      child: CupertinoButton(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () async {
                          firestoreService.Host_SetGameState(3);
                        },
                        color: Colors.white,
                        child: Row(
                          children: [
                            Text(
                              "Next",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.skip_next_rounded,
                              size: 30,
                              color: Colors.black,
                            ),
                          ],
                          mainAxisAlignment: MainAxisAlignment.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.08,
              )
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: spotifyPurple,
      );
    }
  }
}

class TimerBar extends StatefulWidget {
  final Color backgroundColor;
  final Color progressColor;
  final Duration period;
  final Function()? onComplete;

  TimerBar({
    required this.backgroundColor,
    required this.progressColor,
    required this.period,
    this.onComplete,
  });

  @override
  _TimerBarState createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar> {
  double _progressValue = 0.0;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  void _startTimer() {
    Duration duration = widget.period;
    const steps = 500;
    final stepDuration = duration ~/ steps;
    final increment = 1 / steps.toDouble();

    _timer = Timer.periodic(stepDuration, (Timer timer) {
      if (musicPlaying == false) return;

      setState(() {
        _progressValue += increment;
        _elapsed += stepDuration;
      });

      if (_progressValue >= 1.0) {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 6,
        width: MediaQuery.of(context).size.width * 0.6,
        child: LinearProgressIndicator(
          backgroundColor: widget.backgroundColor,
          value: _progressValue,
          valueColor: AlwaysStoppedAnimation<Color>(widget.progressColor),
        ),
      ),
    );
  }
}

class ResultPage extends StatefulWidget {
  final bool isCorrect;
  final Player guiltyPlayer;
  const ResultPage(
      {Key? key, required this.isCorrect, required this.guiltyPlayer})
      : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late final bool isCorrect;
  late String correctChoice;

  bool playerWon = false;

  @override
  void initState() {
    super.initState();
    isCorrect = widget.isCorrect;
    correctChoice = widget.guiltyPlayer.getDisplayName();
  }

  void _proceedToNextPage() {
    // only change the page if you're the host
    if (bLocalHost.value == false) return;

    if (queue_pos < playbackQueue.length) {
      firestoreService.Host_SetGameState(2);
    } else {
      firestoreService.Host_SetGameState(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor =
        isCorrect ? const Color(0xFF1cb955) : const Color(0xFFfe3356);
    String playStatus = isCorrect ? 'Correct' : 'Wrong';
    Color boxColor = backgroundColor == const Color(0xFF1cb955)
        ? const Color(0xFF0d943f)
        : const Color(0xFFdb2948);
    Color myBoxColor;
    if (boxColor == const Color(0xFFdb2948))
      myBoxColor = const Color(0xFFa11b32);
    else
      myBoxColor = const Color(0xFF096129);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            height: 80,
          ),
          Text(
            playStatus,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ClipOval(
              child: Image.network(widget.guiltyPlayer.getImageURL(),
                  width: 200, height: 200, fit: BoxFit.cover)),
          Text(correctChoice,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 30),
          Text('Current Scores',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700)),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.30,
            width: MediaQuery.of(context).size.width * 0.9,
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
                        color: boxColor,
                        playerInstance: playerInstance,
                        showScore: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: Container(
                alignment: Alignment.bottomCenter,
                child: Column(
                  children: [
                    TimerBar(
                      backgroundColor: spotifyGrey,
                      progressColor: Colors.white,
                      period: Duration(seconds: 5),
                      onComplete: _proceedToNextPage,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1)
                  ],
                  mainAxisAlignment: MainAxisAlignment.end,
                )),
          )
        ],
      )),
    );
  }
}

class FinishPage extends StatefulWidget {
  final bool playerWon;
  const FinishPage({Key? key, required this.playerWon}) : super(key: key);

  @override
  _FinishPageState createState() => _FinishPageState();
}

class _FinishPageState extends State<FinishPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor =
        widget.playerWon ? const Color(0xFF1cb955) : const Color(0xFFfe3356);
    String playStatus = widget.playerWon ? 'You Win' : 'You Lost';
    Color boxColor = backgroundColor == const Color(0xFF1cb955)
        ? const Color(0xFF0d943f)
        : const Color(0xFFdb2948);
    Color myBoxColor;
    if (boxColor == const Color(0xFFdb2948))
      myBoxColor = const Color(0xFFa11b32);
    else
      myBoxColor = const Color(0xFF096129);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            height: 80,
          ),
          Text(
            playStatus,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 150),
          Text('Final Scores',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700)),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.30,
            width: MediaQuery.of(context).size.width * 0.9,
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
                        color: boxColor,
                        playerInstance: playerInstance,
                        showScore: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Spacer(),
          Container(
            child: CupertinoButton(
                color: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EndPage(),
                    ),
                  );
                },
                child: Text(
                  "Continue",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w500),
                )),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.08,
          )
        ],
      )),
    );
  }
}

class EndPage extends StatefulWidget {
  const EndPage({Key? key}) : super(key: key);

  @override
  _EndPageState createState() => _EndPageState();
}

class _EndPageState extends State<EndPage> {
  bool _isChecked = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _isChecked = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Column(children: [
          Spacer(),
          const Text(
            "Save your game",
            style: TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: 20,
          ),
          SavePlaylistButton(),
          Spacer(),
          Container(
            child: CupertinoButton(
                color: Colors.white,
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LobbyPage(
                              gameCode: server_id,
                              init: false,
                            )),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text(
                  "Return to Lobby",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w500),
                )),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.08,
          ),
        ])));
  }
}

class SavePlaylistButton extends StatefulWidget {
  final VoidCallback? onTap; // Callback function parameter

  SavePlaylistButton({this.onTap});

  @override
  _SavePlaylistButtonState createState() => _SavePlaylistButtonState();
}

class _SavePlaylistButtonState extends State<SavePlaylistButton> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: _isChecked
          ? Column(
              key: ValueKey<bool>(_isChecked),
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isChecked = !_isChecked;
                    });
                    // Call the callback function if provided
                    if (widget.onTap != null) {
                      widget.onTap!();
                    }
                  },
                  child: Container(
                    key: ValueKey<bool>(_isChecked),
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              key: ValueKey<bool>(_isChecked),
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isChecked = !_isChecked;
                    });
                    // Call the callback function if provided
                    if (widget.onTap != null) {
                      widget.onTap!();
                    }

                    createPlaylist("Playlist Pursuit");
                  },
                  child: Container(
                    key: ValueKey<bool>(_isChecked),
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
