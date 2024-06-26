import 'package:flutter/material.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'package:queue_quandry/styles.dart';
import 'login.dart';

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
        Center(
          child: Text(
            "Welcome",
            style: TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
            child: Text("Create"),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LobbyPage(
                      init: true,
                    ),
                  ));
            })
      ]),
    );
  }
}
