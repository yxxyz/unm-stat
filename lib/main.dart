import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'pages/homepage.dart';
import 'pages/blepage.dart';
import 'pages/hardwareconfigpage.dart';
import 'pages/techniqueconfigpage.dart';
import 'pages/graphpage.dart';

void main(){
  runApp(const InitApp());
}

class InitApp extends StatelessWidget{
   const InitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 224, 224, 224)),
          bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 224, 224, 224)),
          bodySmall: TextStyle(fontSize: 16, color: Color.fromARGB(255, 224, 224, 224)),
        )
        ),
      home: MainApp(),
    );
  }
}

class MainApp extends StatefulWidget{
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  String _RTIA = "0";
  // bool _fixedRTIA = false;
  String _RLOAD = "0";
  String _technique = "Cyclic Voltammetry";

  BluetoothDevice? _selectedDevice;
  BluetoothCharacteristic? _BLEcharacteristic;

  void updatePageIndex(int index, [BluetoothDevice? device, BluetoothCharacteristic? characteristic]){
    setState(() {
      _selectedIndex = index;
      if (device != null){
        _selectedDevice = device;
      }
    });
  }

  void updateHardwareConfig(String selectedRTIA, String selectedRLOAD, String selectedTechnique){
    _RTIA = selectedRTIA;
    // _fixedRTIA = fixedRTIA;
    _RLOAD = selectedRLOAD;
    _technique = selectedTechnique;
  }

  void updateCharacteristic(BluetoothCharacteristic characteristic) {
  setState(() {
    _BLEcharacteristic = characteristic;
  });
}

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
    HomePage(
      updatePageIndex: updatePageIndex,
    ),
    BlePage(
      updatePageIndex: updatePageIndex,
    ),
    HWConfigPage(
      updatePageIndex: updatePageIndex,
      updateHardwareConfig: updateHardwareConfig,
      updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
    ),
    TechConfigPage(
      updatePageIndex: updatePageIndex,
      updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      rtia: _RTIA,
      // fixedRtia: _fixedRTIA,
      rload: _RLOAD,
      technique: _technique,
    ),
    GraphPage(
      updatePageIndex: updatePageIndex,
      updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      rtia: _RTIA,
      // fixedRtia: _fixedRTIA,
      rload: _RLOAD,
      technique: _technique,
    )
  ];
    return IndexedStack(
      index: _selectedIndex,
      children: _pages,
    );
  }
}


