import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:unm_stat/utils/ble_helper.dart';
import 'dart:typed_data';


class TechConfigPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String rtia;
  // final bool fixedRtia;
  final String rload;
  final String technique;

  const TechConfigPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.rtia,
    // required this.fixedRtia,
    required this.rload,
    required this.technique,
  });

  @override
  _TechConfigPageState createState() => _TechConfigPageState();
  
}

class _TechConfigPageState extends State<TechConfigPage> {

  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? device;

  late String selectedTechnique; 

  // Technique Parameters Mapping
  final Map<String, List<String>> techniqueParameters = {
    "Cyclic Voltammetry": ["V Max:", "V Min:", "Scan Rate:", "V Start:", "V End:", "Step Increase:", "Stop Crossing:"],
    "Chronoamperometry": ["Sampling Rate:", "V Start:", "V Step:", "V End:", "T Start:", "T Step:", "T End:", "CA Unit:"],
    "Square Wave Voltammetry": ["Sampling Rate:", "V Start:", "V End:", "E Step:", "E Pulse:", "Period:", "T Quiet:", "T Relax:"],
    "Differential Pulse Voltammetry": ["Sampling Rate:", "V Start:", "V End:", "E Step:", "E Pulse:", "Pwidth:", "Period:", "T Quiet:", "T Relax:"],
    "Linear Sweep Voltammetry": ["V Start:", "V End:", "Scan Rate:", "Step Increase:"],
  };

  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void initState() {
    super.initState();
    selectedTechnique = widget.technique;
    _writeCharacteristic = widget.characteristic; 
    _initializeControllers();
  }  

  void _initializeControllers() {
    // Clear any existing controllers.
    _paramControllers.clear();
    List<String>? params = techniqueParameters[selectedTechnique];
    if (params != null) {
      for (String param in params) {
        _paramControllers[param] = TextEditingController();
      }
    }
  }

  @override
  void didUpdateWidget(covariant TechConfigPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.technique != widget.technique) {
      selectedTechnique = widget.technique;
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _paramControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  // Function to gather input values and send configuration over BLE
  Future<void> packTechniqueConfig() async {

    if (widget.characteristic != null) {
    enableNotifications(
      characteristic: widget.characteristic!,
      onACKReceived: (char) {
        print("✅ ACK received in TechniqueConfigPage!");
        widget.updateCharacteristic(widget.characteristic!);
        widget.updatePageIndex(4, widget.device);
      },
      );
    } else {
      print("⚠️ No characteristic found for enabling notifications!");
    }

    // Collect parameter values from controllers into a Map
    Map<String, int> parameterValues = {};
    _paramControllers.forEach((param, controller) {
      int value = int.tryParse(controller.text) ?? 0;
      parameterValues[param] = value;
    });
    print("Collected Parameter Values: $parameterValues");

    // 1 byte: number of parameters,
    // Followed by each parameter as a 2-byte integer (little-endian)
    int numberOfParameters = parameterValues.length;
    int payloadLength = 1 + 1 + numberOfParameters*2;
    
    ByteData byteData = ByteData(payloadLength);
    byteData.setUint8(0, 2); // Mode for technique configuration
    byteData.setUint8(1, payloadLength);
    // byteData.setUint8(2, numberOfParameters);
    int offset = 2;
    parameterValues.forEach((param, value) {
      byteData.setInt16(offset, value, Endian.little);
      offset += 2;
    });
    List<int> payload = byteData.buffer.asUint8List();
    print("Payload to send: $payload");

    await sendData(
      characteristic: widget.characteristic, // Pass the characteristic
      data: payload,
    );
  }

  // Function to build an input field with its associated controller.
  Widget _buildInputField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 120,
            height: 40,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              cursorColor: Colors.grey.shade200,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 2.0),
                ),
                filled: true,
                fillColor: Colors.transparent,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  } 

  @override
  Widget build(BuildContext context) {
    print("✅ Received Hardware Config in TechConfigPage:");
    print("RTIA: ${widget.rtia}");
    // print("Fixed RTIA: ${widget.fixedRtia}");
    print("RLOAD: ${widget.rload}");
    print("Technique Config: ${widget.technique}");
    
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18), // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 3),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // ✅ Smooth Scrolling
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ Prevents infinite height issue
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              Text(
                "Technique Configuration",
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 10),

              // Divider
              Divider(
                color: Colors.grey.shade200, // ✅ Light Divider for Separation
                thickness: 1, 
                height: 10,
              ),

              const SizedBox(height: 20),

              Text(
                widget.technique,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              // 🔹 Dynamically Display Input Fields Based on Selected Technique
              if (techniqueParameters[selectedTechnique] != null)
                ...techniqueParameters[selectedTechnique]!.map((param) {
                  return _buildInputField(param, _paramControllers[param]!);
                }).toList()
              else
                Text("No parameters defined for $selectedTechnique",
                    style: Theme.of(context).textTheme.bodySmall),
              
              const SizedBox(height: 30),

              Row(
                
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                onPressed: () async {
                    await packTechniqueConfig();
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
            ],
          ),
        ),
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
}

 
