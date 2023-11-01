import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wakelock/wakelock.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './utils/wol.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  print("Handling a message: ${message.data}");
  if (message.data['mac'] != null && message.data['ipv4'] != null) {
    wake(message.data['mac'], message.data['ipv4']);
  }
}

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingHandler);
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
      debugShowCheckedModeBanner: false,
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
  StreamSubscription? stream;

  @override
  initState() {
    super.initState();

    Wakelock.enable();
    auth.userChanges().listen((event) {
      subscribeToTopic();
      loadDefaultSettings();
    });
    if (auth.currentUser == null) signInWithCredential();
  }

  @override
  dispose() {
    super.dispose();
    stream?.cancel();
  }

  onPressedSave() async {
    await firestore.collection(getProfileRef()).doc('default').set({
      'mac': mac.text,
      'ipv4': ipv4.text,
    });
  }

  onPressedWake({String? customMac, String? customIPv4}) async {
    try {
      if (customMac != null) mac.text = customMac;
      if (customIPv4 != null) ipv4.text = customIPv4;

      Get.closeCurrentSnackbar();
      Get.snackbar('Wake', 'Starting wake device...', duration: const Duration(seconds: 5));
      await wake(mac.text, ipv4.text);

      Get.closeCurrentSnackbar();
      Get.snackbar('Done', 'Wake successfully', duration: const Duration(seconds: 3));
    } catch (error) {
      Get.snackbar('Error', error.toString(), duration: const Duration(seconds: 3));
    }
  }

  subscribeToTopic() async {
    if (auth.currentUser == null) return;
    await FirebaseMessaging.instance.requestPermission(provisional: true, sound: false, alert: false);
    await messasing.subscribeToTopic('wol.${auth.currentUser!.uid}');
    FirebaseMessaging.onMessage.listen((event) {
      onPressedWake();
      _firebaseMessagingHandler(event);
    });
  }

  signInWithCredential() async {
    var result = GoogleSignIn(
      clientId: '363179202701-20e1hjdvekmnmfq28nfp9e00arqdonun.apps.googleusercontent.com',
    );
    await result.signIn();

    var authentication = await result.currentUser!.authentication;
    var googleCredential = GoogleAuthProvider.credential(idToken: authentication.idToken, accessToken: authentication.accessToken);
    await auth.signInWithCredential(googleCredential);
  }

  loadDefaultSettings() async {
    if (auth.currentUser == null) return;
    var settings = await firestore.collection(getProfileRef()).doc('default').get();
    if (settings.data() != null) {
      mac.text = settings.data()?['mac'];
      ipv4.text = settings.data()?['ipv4'];
    }

    firestore.collection(getProfileRef()).doc('default').snapshots().listen((document) {
      var data = document.data();
      if (data != null) {
        mac.text = data['mac'];
        ipv4.text = data['ipv4'];
      }
    });
  }

  getProfileRef() {
    return 'wol/profiles/${auth.currentUser!.uid}';
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
                    hintText: '192.168.0.255',
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
