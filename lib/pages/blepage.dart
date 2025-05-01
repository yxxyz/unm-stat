import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/////// BLE Page of the app ///////
// For scanning and connecting to device

class BlePage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  const BlePage({
    super.key, 
    required this.updatePageIndex});

  @override
  _BlePageState createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    listenToBluetoothState(); // Ensures Bluetooth state is monitored
  }
  
  ///// Function for requesting permissions /////
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  ///// Function for scanning bluetooth devices /////
  Future<void> scanDevices() async {
    // Request necessary permissions
    if (!await _requestPermissions()) return;

    // Ensure Bluetooth is ON
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      print("Bluetooth is off. Please enable it.");
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Collect scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!_scanResults.any((existing) => existing.device.remoteId == result.device.remoteId)) {
          setState(() {
            _scanResults.add(result);
          });
          print("Found device: ${result.advertisementData.advName} (${result.device.remoteId})");
        }
      }
    });

    // Stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () async {
      if (mounted) {
        await FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  ///// Function for connecting to device /////
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("connecting to device");
      await device.connect(timeout: const Duration(seconds: 10));

      device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          FlutterBluePlus.stopScan();
          List<BluetoothService> services = await device.discoverServices();
          print("Discovered ${services.length} services on device.");
          print("Connected to ${device.platformName}");

          setState(() {
            _connectedDevice = device;
            widget.updatePageIndex(2, device);
          });
        } else if (state == BluetoothConnectionState.disconnected) {
          print("Disconnected from ${device.platformName}");
        }
      });
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  @override
  void dispose() {
    _connectedDevice?.disconnect(); // only call disconnect if _connectedDevice is not null
    super.dispose();
  }

  void listenToBluetoothState() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        print("Bluetooth is OFF! Please enable it.");
        // Optionally, show an alert dialog to the user.
      } else if (state == BluetoothAdapterState.on) {
        print("Bluetooth is ON!");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 1),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isScanning ? null : scanDevices,
            style: ElevatedButton.styleFrom(
              foregroundColor: Color.fromARGB(255, 236, 236, 241),
              backgroundColor: Color.fromARGB(255, 236, 236, 241),
              disabledBackgroundColor: Color.fromARGB(255, 103, 103, 103),
              disabledForegroundColor: const Color.fromARGB(179, 237, 237, 237),
            ),
            child: Text(_isScanning ? "Scanning..." : "Scan for Devices",
              style: const TextStyle(
                color: Color.fromARGB(255, 18, 18, 18),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                return ListTile(
                  title: Text(
                    result.device.platformName.isNotEmpty
                        ? result.device.platformName
                        : "Unknown Device",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    result.device.remoteId.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(result.device),
                    child: const Text(
                      "Connect",
                      style: TextStyle(
                        color: Color.fromARGB(255, 18, 18, 18),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Container backIcon(BuildContext context, Function(int) updatePageIndex, int currentIndex) {
  return Container(
    color: Colors.transparent,
    child: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 236, 236, 241)),
      onPressed: () => updatePageIndex(currentIndex-1),
    ),
  );
}
