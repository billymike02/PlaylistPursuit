import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:queue_quandry/multiplayer.dart';
import 'package:queue_quandry/pages/home.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'pages/login.dart';
import 'styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

late FirestoreController firestoreService;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  firestoreService = FirestoreController();

  runApp(
    Provider.value(
      value: FirebaseFirestore.instance,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Gotham'),
      home: HomePage(),
      navigatorKey: navigatorKey,
    );
  }
}
