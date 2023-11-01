import 'dart:io';
import 'package:wake_on_lan/wake_on_lan.dart';

Future<void> wake(String mac, String ipv4) async {
  MACAddress macAddress = MACAddress(mac, delimiter: '-');
  IPAddress ipAddress = IPAddress(ipv4, type: InternetAddressType.IPv4);
  WakeOnLAN wakeOnLan = WakeOnLAN(ipAddress, macAddress);

  print('waking $mac $ipv4');
  await wakeOnLan.wake(
    repeat: 5,
    repeatDelay: const Duration(milliseconds: 500),
  );

  print('done');
}
