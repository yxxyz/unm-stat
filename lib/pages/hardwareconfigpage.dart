import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'package:unm_stat/utils/ble_helper.dart'; 

/////// Hardware Configuration Page of the app ///////
// Page for configurign RTIA, RLOAD, and channel

class HWConfigPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  final Function(String, String, String) updateHardwareConfig; // need modify
  final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  const HWConfigPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateHardwareConfig,
    required this.updateCharacteristic,
    required this.device,
  });

  @override
  _HWConfigPageState createState() => _HWConfigPageState();
}

class _HWConfigPageState extends State<HWConfigPage> {
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  bool _isConnected = false;

  String selectedRTIA = "2750"; // Default RTIA value
  String selectedRLOAD = "10"; // Default RLOAD value
  String selectedTechnique = "Cyclic Voltammetry"; // Default technique
  // bool fixedRTIA = false; // Checkbox for Fixed RTIA

  Map<String, bool> channelConfig = {};
  
  final List<String> rtiaOptions = [
      "2750",
      "3500",
      "7000",
      "14000",
      "35000",
      "120000",
      "350000"
  ];

  final List<String> rloadOptions = [
      "10",
      "33",
      "50",
      "100"
  ];

  final List<String> techniqueOptions = [
      "Cyclic Voltammetry",
      "Chronoamperometry",
      "Square Wave Voltammetry",
      "Differential Pulse Voltammetry",
      "Linear Sweep Voltammetry"
  ];


  @override
  void initState() {
    super.initState();
  }
  
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

     for (BluetoothService service in services) {
      print("Service UUID: ${service.uuid}");
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        print("Characteristic UUID: ${characteristic.uuid}");
        if (service.uuid.toString().toLowerCase().contains("ffe0") &&
            characteristic.uuid.toString().toLowerCase().contains("ffe1")) {
          setState(() {
            _writeCharacteristic = characteristic;
          });
          print("HM10 characteristic found: ${characteristic.uuid}");

          // wait for ACK
          await enableNotifications(
            characteristic: characteristic,
            onACKReceived: (char) {
              widget.updateCharacteristic(_writeCharacteristic!);
              widget.updatePageIndex(3, widget.device);
            },
          );
        }
      }
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("Checking device connection state...");
      BluetoothConnectionState currentState = await device.connectionState.first;
      if (currentState != BluetoothConnectionState.connected) {
        print("Device not connected, connecting now...");
        await device.connect();
        // Allow some time for the connection to establish
        await Future.delayed(Duration(seconds: 2));
      } else {
        print("Device already connected, re-running service discovery...");
      }
      await discoverServices(device);
      setState(() {
        _isConnected = true;
      });
      print("Connected and services discovered.");
    } catch (e) {
      print("Connection failed: $e");
    }
  }
 
  void disconnectBLE() async {
    if (widget.device != null) {
      try {
        await widget.device!.disconnect();
        print("Device disconnected.");
        setState(() {
          _isConnected = false;
        });
      } catch (e) {
        print("Error disconnecting device: $e");
      }
    }
  }

  //////////////////////////////////////////// -> pack data
  Future<void> packHardwareConfig() async {
    await connectToDevice(widget.device!);
    // Determine the number of active channels.
    int activeChannels = channelConfig.entries.where((entry) => entry.value).length;
    
    int totalBytes = 1 + 1 + 1 + 1 + 1 + 1 + activeChannels;
    ByteData byteData = ByteData(totalBytes);
    
    byteData.setUint8(0, 1); // Mode indicator for hardware configuration
    byteData.setUint8(1, totalBytes);
    
    int rtiaIndex = rtiaOptions.indexOf(selectedRTIA);

    byteData.setUint8(2, rtiaIndex);

    // byteData.setUint8(3, fixedRTIA ? 1 : 0);

    int rloadIndex = rloadOptions.indexOf(selectedRLOAD);
    byteData.setUint8(3, rloadIndex);

    Map<String, int> techniqueMapping = {
      "Cyclic Voltammetry": 1,
      "Chronoamperometry": 2,
      "Square Wave Voltammetry": 3,
      "Differential Pulse Voltammetry": 4,
      "Linear Sweep Voltammetry" : 5,
    };

    int techniqueCode = techniqueMapping[selectedTechnique] ?? 1;
    byteData.setUint8(4, techniqueCode);

    int offset = 5;

    // Encode each active channel.
    channelConfig.forEach((channelName, isActive) {
      if (isActive) {
        // Assuming channel name is in the format "Channel X".
        int channelNumber = int.tryParse(channelName.split(" ")[1]) ?? 0;
        byteData.setUint8(offset, channelNumber);
        offset++;
      }
    });

    // Convert ByteData to a list of bytes.
    List<int> payload = byteData.buffer.asUint8List();

    // Send the byte payload.
    await sendData(
      characteristic: _writeCharacteristic, // Pass the characteristic
      data: payload,);
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 2),
      ),
      
     body: SafeArea(  // prevent overlap with system UI
        child: Column(
          children: [
            Expanded(
              child:Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      configurationParameters(),
                    ]
                  )
                )
              )
          ]
        )
      ),
    );
  }

   Widget backIcon(BuildContext context, Function(int) updatePageIndex, int currentIndex) {
    return Container(
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 224, 224, 224)),
        onPressed: () async {
          print("Back button pressed. Sending '0' to Arduino...");
          List<int> backMessage = [0, 2];
          await sendData(
            characteristic: _writeCharacteristic, // Pass the characteristic
            data: backMessage,
          ); // Send '0' to Arduino
          updatePageIndex(currentIndex-1); // Navigate back
        },
      ),
    );
  }

  /////////////////////////////////////// Widgets /////////////////////////////////////////////////
  SizedBox configurationParameters(){
  List<String> channels = List.generate(9, (index) => "Channel ${index + 1}");
  int half = (channels.length / 2).ceil();
  List<String> firstColumn = channels.sublist(0, half);
  List<String> secondColumn = channels.sublist(half);
  
  // sized box to wrap all configurations
  return SizedBox(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Title
        Text(
          "Hardware Configuration",
          style: Theme.of(context).textTheme.bodyLarge,
        ),

        const SizedBox(height: 10),

        // Divider Line
        Divider(
          color: Colors.grey.shade200,
          thickness: 1, // Line thickness
          height: 10, // Space around the divider
        ),

        const SizedBox(height: 20),

        // RTIA Dropdown
        const Text("RTIA (Ohm):"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedRTIA,
          onChanged: (String? newValue) {
            setState(() {
              selectedRTIA = newValue!;
            });
          },
          items: rtiaOptions.map<DropdownMenuItem<String>>((String value)  {
            return DropdownMenuItem<String>(
              value: value,
              alignment: Alignment.center,
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          dropdownColor: Color.fromARGB(255, 18, 18, 18), // Change dropdown color
          icon: const Icon( // Custom arrow icon
            Icons.arrow_drop_down,
            color: Colors.white, 
            size: 30, 
          ),
        ),

        // Fixed RTIA Checkbox
        // Row(
        //   children: [
        //     Checkbox(
        //       value: fixedRTIA,
        //       onChanged: (bool? newValue) {
        //         setState(() {
        //           fixedRTIA = newValue!;
        //         });
        //       },
        //       activeColor: Colors.grey.shade700,

        //     ),
        //     Text(
        //       "Fixed RTIA",
        //       style: Theme.of(context).textTheme.bodySmall),
        //   ],
        // ),

        const SizedBox(height: 20),

        // RLOAD Dropdown
        const Text("RLOAD (Ohm):"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedRLOAD,
          onChanged: (String? newValue) {
            setState(() {
              selectedRLOAD = newValue!;
            });
          },
          items: rloadOptions.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              alignment: Alignment.center, 
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          dropdownColor: Color.fromARGB(255, 18, 18, 18),
          icon: const Icon( 
                  Icons.arrow_drop_down,
                  color: Colors.white, 
                  size: 30, 
                ),
        ),

        const SizedBox(height: 20),

        // Technique Configuration 
        Text(
          "Technique Configuration:",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: DropdownButton<String>(
            value: selectedTechnique,
            onChanged: (String? newValue) {
              setState(() {
                selectedTechnique= newValue!;
              });
            },
            items: techniqueOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                alignment: Alignment.center,
                child: Text(value,
                    style: Theme.of(context).textTheme.bodySmall),
              );
            }).toList(),
            dropdownColor: Color.fromARGB(255, 18, 18, 18),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      
       const SizedBox(height: 20),

       // Channel Configuration
       Text( 
          "Channel Configuration:",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0),
                  child: Column(
                  children: firstColumn.map((channelName) {
                    return CheckboxListTile(
                      title: Text(
                        channelName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: channelConfig[channelName] ?? false,
                      onChanged: (bool? newValue) {
                        setState(() {
                          channelConfig[channelName] = newValue!;
                        });
                      },
                      activeColor: Colors.grey.shade700,
                      visualDensity: const VisualDensity(vertical: -4.0),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              )
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15.0),
                child: Column(
                  children: secondColumn.map((channelName) {
                    return CheckboxListTile(
                      title: Text(
                        channelName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: channelConfig[channelName] ?? false,
                      onChanged: (bool? newValue) {
                        setState(() {
                          channelConfig[channelName] = newValue!;
                        });
                      },
                      activeColor: Colors.grey.shade700,
                      visualDensity: const VisualDensity(vertical: -4.0),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              )
            ),
          ],
        ),

        const SizedBox(height: 20),

        //Next Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
            onPressed: () async {
              // Handle next button press
              _connectedDevice = widget.device;
              
              widget.updateHardwareConfig(selectedRTIA, selectedRLOAD, selectedTechnique);
              // widget.updatePageIndex(3, widget.device);
              
              print("RTIA: $selectedRTIA");
              // print("Fixed RTIA: $fixedRTIA");
              print("RLOAD: $selectedRLOAD");
              print("Selected Channels: ${channelConfig.entries.where((entry) => entry.value).map((entry) => entry.key).toList()}");
              print("Selected Technique: $selectedTechnique");
              
              packHardwareConfig();
              print("Send hardware configuration. Waiting for ACK...");
            },
            style: ElevatedButton.styleFrom(
                disabledBackgroundColor: const Color.fromARGB(255, 177, 177, 177),
                disabledForegroundColor: Colors.white70,
              ),
            child: const Text("Next",
              style: TextStyle(
                color: Color.fromARGB(255, 18, 18, 18),
                fontSize: 18,
                fontWeight: FontWeight.w600
              ),
            ),
          ),
          ],
        ),

        const SizedBox(height: 35),

    ],
   ),
  );
  
}
}




