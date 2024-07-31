import 'package:flutter/material.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'package:queue_quandry/spotify-api.dart';
import 'package:queue_quandry/styles.dart';
import 'login.dart';
import 'package:flutter/cupertino.dart';
import 'package:queue_quandry/multiplayer.dart';

class HomePage extends StatefulWidget {
  HomePage({
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _attemptLogin() async {
    bool result = await authenticateUser();

    // in the event of a login failure, show the login page
    if (result == false) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ));
    }

    local_client_id = await getLocalUserID();
  }

  @override
  void initState() {
    super.initState();

    _attemptLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: spotifyBlack,
      body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Gamemode(
            gamePage: LobbyPage,
            name: "Queue Quandary",
            player_count: "2-8",
            description: "Guess who queued each song."),
      ]),
    );
  }
}

class Gamemode extends StatefulWidget {
  final Type gamePage;
  final String name;
  final String player_count;
  final String description;

  Gamemode({
    Key? key,
    required this.gamePage,
    required this.name,
    required this.player_count,
    required this.description,
  }) : super(key: key);

  @override
  _GamemodeState createState() => _GamemodeState();
}

class _GamemodeState extends State<Gamemode> {
  TextEditingController _textController = TextEditingController();
  String _inputText = '';

  void _showTextFieldDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: spotifyGrey,
          surfaceTintColor: Colors.transparent,
          contentPadding: EdgeInsets.only(top: 15, left: 15, right: 15),
          actionsPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          content: SizedBox(
            height: 45,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  // Update any state related to the text field here
                });
              },
              textAlignVertical: TextAlignVertical.bottom,
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                hintText: 'Game code',
                hintStyle:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
                fillColor: Colors.white,
                filled: true,
              ),
              style: TextStyle(color: Colors.black),
            ),
          ),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () async {
                      await ensureTokenIsValid();

                      String gameCode;

                      try {
                        gameCode = server_id;
                      } catch (e) {
                        gameCode = generateGameCode();
                      }

                      navigatorKey.currentState!.push(
                        MaterialPageRoute(
                            builder: (context) => LobbyPage(
                                  gameCode: gameCode,
                                  init: true,
                                )),
                      );
                    },
                    color: Colors.white,
                    child: Container(
                      child: Row(
                        children: [
                          Text(
                            "Create",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Icon(
                            Icons.cast_rounded,
                            size: 22,
                            color: Colors.black,
                          ),
                        ],
                        mainAxisAlignment: MainAxisAlignment.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      color: spotifyGreen,
                      child: Container(
                        child: Row(
                          children: [
                            Text(
                              "Join",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Icon(
                              Icons.connect_without_contact_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ],
                          mainAxisAlignment: MainAxisAlignment.center,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _inputText = _textController.text;
                          _textController.clear();
                          _attemptJoinGame(_inputText);
                        });

                        Navigator.of(context).pop();
                      }),
                )
              ],
            )
          ],
        );
      },
    );
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
    navigatorKey.currentState!.push(
      MaterialPageRoute(
          builder: (context) => LobbyPage(
                gameCode: code,
                init: false,
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Container(
      height: MediaQuery.of(context).size.height * 0.13,
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
          color: spotifyGrey,
          borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 25,
          ),
          child: Row(children: [
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  Text(widget.description,
                      style: TextStyle(color: Colors.grey)),
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text(widget.player_count,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600))
                    ],
                  )
                ]),
            Spacer(),
            CupertinoButton(
                padding: EdgeInsets.all(0),
                onPressed: () {
                  _showTextFieldDialog(context);
                },
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: spotifyGreen,
                  size: 80,
                )),
          ])),
    ));
  }
}
