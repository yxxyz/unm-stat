import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Function to send data via BLE
Future<void> sendData({
  required BluetoothCharacteristic? characteristic,
  required List<int> data,
}) async {
  if (characteristic != null) {
    try {
      await characteristic.write(data, withoutResponse: false);
      print("Data sent: $data");
    } catch (e) {
      print("Error sending data: $e");
    }
  } else {
    print("Write characteristic not found!");
  }
}


Future<void> enableNotifications({
required BluetoothCharacteristic characteristic,
required Function(BluetoothCharacteristic) onACKReceived,
// required Function(List<int>) onDataReceived,
}) async {
  try {
    await characteristic.setNotifyValue(true);
    characteristic.lastValueStream.listen((value) {
      String received = String.fromCharCodes(value);
      print("Received: $received");

      // Check for ACK response
      if (received.trim() == "ACK") {
        print("✅ ACK received. Proceeding to the next page...");
        onACKReceived(characteristic);  // Call the provided callback for ACK
      }
    });

    print("✅ Notifications enabled for characteristic: ${characteristic.uuid}");
  } catch (e) {
    print("⚠️ Error enabling notifications: $e");
  }
}
