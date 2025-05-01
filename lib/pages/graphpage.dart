import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unm_stat/utils/ble_helper.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' show min;



// widget class
class GraphPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String rtia;
  // final bool fixedRtia;
  final String rload;
  final String technique;

  const GraphPage({
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
  _GraphPageState createState() => _GraphPageState(); 
}



class _GraphPageState extends State<GraphPage> {
  late String selectedTechnique; 
  bool isStreaming = false;
  StreamSubscription<List<int>>? _subscription;
  
  // Use a Map to store data points for different channels
  Map<int, List<FlSpot>> _channelDataPoints = {};
  
  // Colors for different channels
  final List<Color> _channelColors = [
    Colors.brown,     // Channel 6
    Colors.pink,      // Channel 7
    Colors.indigo,    // Channel 8
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];
  
  // Get min/max values for all channels combined
  double get minX {
    if (_channelDataPoints.isEmpty || _channelDataPoints.values.every((points) => points.isEmpty)) {
      return -500;
    }
    return _channelDataPoints.values
        .expand((points) => points)
        .map((spot) => spot.x)
        .reduce((a, b) => a < b ? a : b) - 50;
  }

  double get maxX {
    if (_channelDataPoints.isEmpty || _channelDataPoints.values.every((points) => points.isEmpty)) {
      return 500;
    }
    return _channelDataPoints.values
        .expand((points) => points)
        .map((spot) => spot.x)
        .reduce((a, b) => a > b ? a : b) + 50;
  }

  double get minY {
    if (_channelDataPoints.isEmpty || _channelDataPoints.values.every((points) => points.isEmpty)) {
      return -50;
    }
    return _channelDataPoints.values
        .expand((points) => points)
        .map((spot) => spot.y)
        .reduce((a, b) => a < b ? a : b) * 1.2;
  }

  double get maxY {
    if (_channelDataPoints.isEmpty || _channelDataPoints.values.every((points) => points.isEmpty)) {
      return 50;
    }
    return _channelDataPoints.values
        .expand((points) => points)
        .map((spot) => spot.y)
        .reduce((a, b) => a > b ? a : b) * 1.2;
  }

  String get xAxisLabel {
  switch (selectedTechnique.toLowerCase()) {
    case 'chronoamperometry':
      return 'Time (ms)';      
    case 'cyclic voltammetry':
    case 'linear sweep voltammetry':
    case 'differential pulse voltammetry':
    case 'square wave voltammetry':
      return 'Voltage (mV)';
    default:
      return 'X-Axis';
  }
}

String get yAxisLabel {
  switch (selectedTechnique.toLowerCase()) {
    case 'chronoamperometry':
    case 'cyclic voltammetry':
    case 'linear sweep voltammetry':
      return 'Current (µA)';
    case 'differential pulse voltammetry':
    case 'square wave voltammetry':
      return 'Differential Current (µA)';
    default:
      return 'Y-Axis';
  }
}

  @override
  void initState() {
    super.initState();
    selectedTechnique = widget.technique;
  }  

  Future<void> startDataStream() async {
    if (widget.characteristic == null) {
      print("⚠️ No characteristic found for listening!");
      return;
    }
    
    // Cancel any existing subscription first
    _subscription?.cancel();
    
    // Clear existing data points
    setState(() {
      _channelDataPoints.clear();
    });
    
    // Enable notifications
    await enableNotifications(
      characteristic: widget.characteristic!,
      onACKReceived: (char) {
        print("✅ ACK received in GraphPage!");
      },
    );

    void parseMultiChannelData(List<int> rawData) {
      _packetBuffer.addAll(rawData);
      print("Packet buffer: $_packetBuffer");

      while (_packetBuffer.length >= 6) {
        try {
          int channelCount = _packetBuffer[0];
          if (channelCount < 1 || channelCount > 3) {
            print("Invalid channel count: $channelCount, clearing buffer");
            _packetBuffer.clear();
            break;
          }
          int packetNumber = _packetBuffer[1];
          int channelMask = (_packetBuffer[3] << 8) | _packetBuffer[2];
          int expectedPacketSize = 6 + channelCount * 4;
          if (_packetBuffer.length < expectedPacketSize) break;

          ByteData xBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(4, 6)));
          double x = xBytes.getInt16(0, Endian.little).toDouble();

          int yStartIndex = 6;
          int channelsProcessed = 0;

          for (int channel = 0; channel < 9; channel++) {
            if ((channelMask & (1 << channel)) != 0) {
              if (channelsProcessed >= channelCount) break;
              ByteData yBytes = ByteData.sublistView(Uint8List.fromList(
                _packetBuffer.sublist(yStartIndex, yStartIndex + 4)
              ));
              double y = yBytes.getFloat32(0, Endian.little);
              setState(() {
                _channelDataPoints[channel] ??= [];
                _channelDataPoints[channel]!.add(FlSpot(x, y));
              });
              yStartIndex += 4;
              channelsProcessed++;
            }
          }
          _packetBuffer.removeRange(0, expectedPacketSize);
        } catch (e) {
          print("❌ Error parsing BLE packet: $e");
          _packetBuffer.clear();
          break;
        }
      }

      // Check for leftover "DONE" in buffer (edge case)
      if (_packetBuffer.length >= 4) {
        String bufferText = String.fromCharCodes(_packetBuffer).trim().toUpperCase();
        if (bufferText == "DONE") {
          print("✅ DONE found in buffer");
          setState(() {
            isStreaming = false;
            _packetBuffer.clear();
          });
          _subscription?.cancel();
          _subscription = null;
        }
      }
    }
    
    _subscription = widget.characteristic!.onValueReceived.listen((List<int> data) {
    if (data.isNotEmpty) {
      print("Raw data received: $data");
      String receivedText = String.fromCharCodes(data).trim().toUpperCase();
      print("Parsed text: '$receivedText'");

      // Check for "DONE" first
      if (receivedText == "DONE") {
        print("✅ DONE signal received from Arduino");
        setState(() {
          isStreaming = false;
          _packetBuffer.clear();
        });
        _subscription?.cancel(); // Optional: stop listening
        _subscription = null;
        return;
      }

      // If not "DONE", treat as data packet
      parseMultiChannelData(data);
    }
  });


    
    // Send start command
    List<int> startMessage = [3, 2];
    await sendData(
      characteristic: widget.characteristic,
      data: startMessage,
    );
    
    setState(() {
      isStreaming = true;
    });
    
    print("📡 Multi-channel data streaming started.");
  }
  
  // Add this buffer at the class level
  List<int> _packetBuffer = [];

  void parseMultiChannelData(List<int> rawData) {
    _packetBuffer.addAll(rawData);

    while (_packetBuffer.length >= 6) {
      try {
        // 1. Channel count (1 byte)
        int channelCount = _packetBuffer[0];
        if (channelCount < 1 || channelCount > 3) {
          throw Exception("Invalid channel count: $channelCount");
        }

        // 2. Packet number (1 byte)
        int packetNumber = _packetBuffer[1];

        // 3. Channel mask (2 bytes)
        int channelMask = (_packetBuffer[3] << 8) | _packetBuffer[2];

        // 4. Expected total packet size
        int expectedPacketSize = 6 + channelCount * 4;
        if (_packetBuffer.length < expectedPacketSize) break;

        // 5. Extract x (2 bytes)
        ByteData xBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(4, 6)));
        double x = xBytes.getInt16(0, Endian.little).toDouble();

        // 6. Extract y-values based on channelMask
        int yStartIndex = 6;
        int channelsProcessed = 0;

        for (int channel = 0; channel < 9; channel++) {
          if ((channelMask & (1 << channel)) != 0) {
            if (channelsProcessed >= channelCount) break; // Limit to count in this packet

            ByteData yBytes = ByteData.sublistView(Uint8List.fromList(
              _packetBuffer.sublist(yStartIndex, yStartIndex + 4)
            ));

            double y = yBytes.getFloat32(0, Endian.little);

            setState(() {
              _channelDataPoints[channel] ??= [];
              _channelDataPoints[channel]!.add(FlSpot(x, y));
            });

            yStartIndex += 4;
            channelsProcessed++;
          }
        }

        // 7. Remove processed packet
        _packetBuffer.removeRange(0, expectedPacketSize);
      } catch (e) {
        print("❌ Error parsing BLE packet: $e");
        _packetBuffer.clear();
        break;
      }
    }
  }
  
  void stopDataStream() {
    _subscription?.cancel();
    _subscription = null;
    
    setState(() {
      isStreaming = false;
    });
    
    print("⏹️ Multi-channel data streaming stopped.");
  }

  // Generate legend items for each channel
  Widget buildLegend() {
    return Wrap(
      spacing: 16,
      children: _channelDataPoints.keys.map((channel) {
        final colorIndex = channel % _channelColors.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              color: _channelColors[colorIndex],
            ),
            SizedBox(width: 4),
            Text(
              "Channel ${channel + 1}",
              style: TextStyle(
                color: Color.fromARGB(255, 224, 224, 224),
                fontSize: 14,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    stopDataStream();
    super.dispose();
  }
  
  // Added this method
  @override
  void didUpdateWidget(covariant GraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.technique != widget.technique) {
      setState(() {
        selectedTechnique = widget.technique; // Update if widget.technique changes
        print("Updated selectedTechnique: $selectedTechnique"); // Debug
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Channels with data: ${_channelDataPoints.keys}");
  _channelDataPoints.forEach((channel, points) {
    print("Channel $channel has ${points.length} points");
    if (points.isNotEmpty) {
      print("  First point: (${points.first.x}, ${points.first.y})");
      print("  Last point: (${points.last.x}, ${points.last.y})");
    }
  });
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 4),
      ),
      body: Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.technique,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          
          const SizedBox(height: 20),

          // Graph
          Container(
            height: 500,
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.white, // Ensure white background
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade300, // Light gray grid lines
                    strokeWidth: 0.5,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey.shade300, // Light gray grid lines
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                show: true,
                  
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // interval: 100,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      // Skip titles near minX and maxX to avoid overlap
                      double range = maxX - minX;
                      double margin = range * 0.02;
                      if (value <= minX + margin || value >= maxX - margin) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal, fontFamily: 'Arial'),
                        ),
                      );
                    },
                  ),
                ),
                  
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      double range = maxY - minY;
                      double margin = range * 0.02;

                      if (value <= minY + margin || value >= maxY - margin) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(left:5),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal,fontFamily: 'Arial'),
                        ),
                      );
                    },
                  ),
                  axisNameWidget: Padding(
                    padding: EdgeInsets.only(left: 2, right: 2),
                    child: Text(
                      yAxisLabel,
                      style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal, fontFamily: 'Arial'),
                    ),
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // Hide right Y-axis labels
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // Hide top X-axis labels
                ),
              ),
              
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.black, width: 1), // Black border like MATLAB
              ),
              
              minX: minX, // Auto-scale X-axis
              maxX: maxX,
              minY: minY, // Auto-scale Y-axis
              maxY: maxY,

              lineBarsData: _channelDataPoints.entries.map((entry) {
                final channel = entry.key;
                final dataPoints = entry.value;
                // Make sure we get a valid index in the color array
                final colorIndex = channel % _channelColors.length;
                
                return LineChartBarData(
                  spots: dataPoints,
                  isCurved: false,
                  barWidth: 2,
                  color: _channelColors[colorIndex], // Use the specific color from the array
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                );
              }).toList(),
              )
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: Text(
              xAxisLabel,
              style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal,fontFamily: 'Arial'),
            ),
          ),
          const SizedBox(height: 10), // Space between graph and button

          // Legend for channel colors
          if (_channelDataPoints.isNotEmpty) buildLegend(),

          const SizedBox(height: 10),

          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children:[
               // "Start" Button
              ElevatedButton(
                onPressed: isStreaming ? stopDataStream : startDataStream,
                style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: const Color.fromARGB(255, 177, 177, 177),
                    disabledForegroundColor: Colors.white70,
                  ),
                child: Text(isStreaming ? "Stop" : "Start",
                  style: const TextStyle(
                    color: Color.fromARGB(255, 18, 18, 18),
                    fontSize: 20,
                    fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ]
          ),

          const SizedBox(height: 20), // Add some spacing at the bottom
        
        ],
      ),
    ),
    );
  }
  
  // Back Button Widget
  Widget backIcon(BuildContext context, Function(int) updatePageIndex, int currentIndex) {
    return Container(
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 224, 224, 224)),
        onPressed: () async {
          print("Back button pressed. Sending '0' to Arduino...");
          List<int> backMessage = [0, 2];
          await sendData(
            characteristic: widget.characteristic, // Pass the characteristic
            data: backMessage,
          );
          setState(() {
            _channelDataPoints.clear();
          });
          updatePageIndex(currentIndex-1);
        },
      ),
    );
  }
}
