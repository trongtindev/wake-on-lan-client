import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:wakelock/wakelock.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './utils/wol.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  build(context) {
    return GetMaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SinglePage(),
    );
  }
}

class SinglePage extends StatefulWidget {
  const SinglePage({super.key});
  @override
  State<SinglePage> createState() => SinglePageState();
}

class SinglePageState extends State<SinglePage> {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final messasing = FirebaseMessaging.instance;

  final mac = new TextEditingController();
  final ipv4 = new TextEditingController();

  @override
  initState() {
    super.initState();

    Wakelock.enable();
    subscribeToTopic();
    if (auth.currentUser == null) signInAnonymously();
    auth.userChanges().listen((event) => loadDefaultSettings());
  }

  onPressedSave() async {
    await firestore.collection('wol').doc('settings').set({
      'mac': mac.text,
      'ipv4': ipv4.text,
    });
  }

  onPressedWake() async {
    try {
      await wake(mac.text, ipv4.text);
      Get.snackbar('Done', 'Wake successfully', duration: Duration(seconds: 3));
    } catch (error) {
      Get.snackbar('Error', error.toString(), duration: Duration(seconds: 3));
    }
  }

  subscribeToTopic() async {
    await FirebaseMessaging.instance.requestPermission(provisional: true, sound: false, alert: false);
    await messasing.subscribeToTopic('wol');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
    });
  }

  signInAnonymously() async {
    await auth.signInAnonymously();
    loadDefaultSettings();
  }

  loadDefaultSettings() async {
    var settings = await firestore.collection('wol').doc('settings').get();
    mac.text = settings.data()?['mac'];
    ipv4.text = settings.data()?['ipv4'];

    await firestore.collection('wol').doc('state').set({'value': false});
    firestore.collection('wol').doc('state').snapshots().listen((event) {
      if (event.data()!['value']) {
        event.reference.set({'value': false});
        onPressedWake();
      }
    });
  }

  @override
  build(context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake On Lan'),
        actions: [
          IconButton(
            onPressed: onPressedSave,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(left: 20, right: 20),
              children: [
                TextField(
                  controller: mac,
                  decoration: const InputDecoration(
                    labelText: 'MAC',
                    hintText: 'AA:BB:CC:DD:EE:FF',
                  ),
                ),
                TextField(
                  controller: ipv4,
                  decoration: const InputDecoration(
                    labelText: 'IPv4',
                    hintText: '0.0.0.0',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPressedWake,
                    child: const Text('Wake'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
