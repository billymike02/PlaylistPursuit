import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: HomePage(),
      navigatorKey: navigatorKey,
    );
  }
}

// Utility class to check equality of two maps
class MapEquality {
  bool equals(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    return map1.entries.every((entry) =>
        map2.containsKey(entry.key) && map2[entry.key] == entry.value);
  }
}

bool areListsOfMapsEqual(List<dynamic> list1, List<dynamic> list2) {
  // Check if both lists are actually lists of maps
  if (!list1.every((item) => item is Map<String, dynamic>) ||
      !list2.every((item) => item is Map<String, dynamic>)) {
    throw ArgumentError(
        'Both lists must contain maps of type Map<String, dynamic>');
  }

  List<Map<String, dynamic>> maps1 = List<Map<String, dynamic>>.from(list1);
  List<Map<String, dynamic>> maps2 = List<Map<String, dynamic>>.from(list2);

  if (maps1.length != maps2.length) return false;

  // Sort the lists to make the comparison order-independent
  maps1.sort((a, b) => a.toString().compareTo(b.toString()));
  maps2.sort((a, b) => a.toString().compareTo(b.toString()));

  for (int i = 0; i < maps1.length; i++) {
    if (!MapEquality().equals(maps1[i], maps2[i])) {
      return false;
    }
  }

  return true;
}
