import 'dart:convert'; // Required for parsing JSON
import 'dart:async';   // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- ADDED THIS IMPORT
import '../theme.dart';

// IMPORTANT: Ensure this matches the file name of your service
import '../services/bluetooth_service.dart'; 

class GlobalTimersScreen extends StatefulWidget {
  const GlobalTimersScreen({super.key});

  @override
  State<GlobalTimersScreen> createState() => _GlobalTimersScreenState();
}

class _GlobalTimersScreenState extends State<GlobalTimersScreen> {
  // Stream Subscription to listen to data
  StreamSubscription? _dataSubscription;

  // --- 1. TIMER VALUES ---
  // Initialized with defaults, but will be overwritten by _loadSavedSettings()
  int _waterFlowCheck_mins = 5;
  int _tankFullInterval_mins = 2;
  int _dryRunCheck_mins = 10;

  // --- 2. THRESHOLD VALUES ---
  int _tankThreshold = 2000;
  int _flowThreshold = 2000;

  // 3. PIN VALUES (Mutable so they update live)
  int _tankStatePin = 0; 
  int _waterFlowStatePin = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings(); // <--- Load saved values from phone memory immediately
    _startListeningToDevice();
  }

  @override
  void dispose() {
    // Cancel the listener when leaving this screen to prevent memory leaks
    _dataSubscription?.cancel();
    super.dispose();
  }

  // --- NEW: LOAD SAVED SETTINGS ---
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    setState(() {
      // Load from phone memory, or use SevakService defaults if memory is empty
      _waterFlowCheck_mins = prefs.getInt('water_flow_local') ?? SevakBluetoothService.instance.memWaterInterval;
      _tankFullInterval_mins = prefs.getInt('tank_full_local') ?? SevakBluetoothService.instance.memTankInterval;
      _dryRunCheck_mins = prefs.getInt('dry_run_local') ?? SevakBluetoothService.instance.memDryRunInterval;
      
      _tankThreshold = prefs.getInt('tank_thresh_local') ?? SevakBluetoothService.instance.memTankThreshold;
      _flowThreshold = prefs.getInt('flow_thresh_local') ?? SevakBluetoothService.instance.memFlowThreshold;
    });
  }

  // --- BLUETOOTH LISTENER ---
  void _startListeningToDevice() {
    // We use .instance to share the connection with Home Screen
    // We listen to 'deviceDataStream' which gives us the Raw JSON String
    _dataSubscription = SevakBluetoothService.instance.deviceDataStream.listen((data) {
      _updateUIFromData(data);
    }, onError: (error) {
      print("Error receiving data: $error");
    });
  }

  // --- DATA PARSING LOGIC ---
  void _updateUIFromData(String receivedData) {
    if (!mounted) return; // Don't update if screen is closed

    try {
      String cleanData = receivedData.trim();
      // Skip if it's not JSON (e.g. simple status messages like "Connected")
      if (!cleanData.startsWith('{')) return;

      Map<String, dynamic> data = jsonDecode(cleanData);

      setState(() {
        // We use '??' to keep the current value if the JSON is missing that key
        // Note: We prioritize the UI sliders if the user is dragging them, 
        // but typically we want the device feedback to update the UI.
        // For configuration screens, sometimes it is better NOT to overwrite 
        // user input with device data unless it's an initial read.
        // However, I will keep your logic here:
        
        // _waterFlowCheck_mins = data['waterFlowCheckingInterval_mins'] ?? _waterFlowCheck_mins;
        // _tankFullInterval_mins = data['tankFullStateInterval_mins'] ?? _tankFullInterval_mins;
        // _dryRunCheck_mins = data['dryRunCheckInterval_mins'] ?? _dryRunCheck_mins;
        
        // _tankThreshold = data['tankStateThreshold'] ?? _tankThreshold;
        // _flowThreshold = data['waterFlowStateThreshold'] ?? _flowThreshold;

        _tankStatePin = data['tankStatePin'] ?? _tankStatePin;
        _waterFlowStatePin = data['waterFlowStatePin'] ?? _waterFlowStatePin;
      });
    } catch (e) {
      // It is normal to get occasional parse errors with Bluetooth strings
      print("Error parsing JSON in GlobalTimers: $e");
    }
  }

  // --- SEND DATA LOGIC ---
  void _sendConfigToDevice() {
    // Format: "CFG,WaterInterval,TankInterval,DryInterval,TankThresh,FlowThresh"
    String command = "CFG,$_waterFlowCheck_mins,$_tankFullInterval_mins,$_dryRunCheck_mins,$_tankThreshold,$_flowThreshold";
    
    // Send via the active Singleton connection
    SevakBluetoothService.instance.sendCommand(command);
    print("Sent Config: $command");
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("System Configuration"),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white), // Back button color
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryBlue,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.timer), text: "Timers"),
              Tab(icon: Icon(Icons.tune), text: "Thresholds"),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  // --- TAB 1: TIMERS (Minutes) ---
                  _buildScrollablePage([
                    _buildSectionHeader("System Safety Timers", "Set intervals in non-negative minutes."),
                    _buildTimerSlider(
                        label: "Water Flow Check",
                        value: _waterFlowCheck_mins.toDouble(),
                        unit: "mins",
                        max: 60,
                        onChanged: (val) => setState(() => _waterFlowCheck_mins = val.toInt())),
                    _buildTimerSlider(
                        label: "Tank Full Interval",
                        value: _tankFullInterval_mins.toDouble(),
                        unit: "mins",
                        max: 30,
                        onChanged: (val) => setState(() => _tankFullInterval_mins = val.toInt())),
                    _buildTimerSlider(
                        label: "Dry Run Check",
                        value: _dryRunCheck_mins.toDouble(),
                        unit: "mins",
                        max: 120,
                        onChanged: (val) => setState(() => _dryRunCheck_mins = val.toInt())),
                  ]),

                  // --- TAB 2: THRESHOLDS & PINS ---
                  _buildScrollablePage([
                    _buildSectionHeader("Threshold Config", "Integer values from 0 to 4095."),
                    _buildThresholdSlider(
                        label: "Tank State Threshold",
                        value: _tankThreshold.toDouble(),
                        onChanged: (val) => setState(() => _tankThreshold = val.toInt())),
                    _buildThresholdSlider(
                        label: "Flow State Threshold",
                        value: _flowThreshold.toDouble(),
                        onChanged: (val) => setState(() => _flowThreshold = val.toInt())),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader("Troubleshooting Pins", "Current Pin vs Threshold Status."),
                    _buildPinStatusCard("Tank State Pin", _tankStatePin, _tankThreshold),
                    _buildPinStatusCard("Flow State Pin", _waterFlowStatePin, _flowThreshold),
                  ]),
                ],
              ),
            ),

            // GLOBAL SAVE BUTTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () async {
                  // --- 1. SAVE TO PHONE MEMORY FIRST ---
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('water_flow_local', _waterFlowCheck_mins);
                  await prefs.setInt('tank_full_local', _tankFullInterval_mins);
                  await prefs.setInt('dry_run_local', _dryRunCheck_mins);
                  await prefs.setInt('tank_thresh_local', _tankThreshold);
                  await prefs.setInt('flow_thresh_local', _flowThreshold);

                  // --- 2. CHECK CONNECTION & SEND ---
                  // IMPORTANT: Make sure your SevakBluetoothService has an 'isConnected' boolean getter.
                  // If not, simply use: bool isConnected = true; (but this risks crashes if really offline)
                  bool isConnected = SevakBluetoothService.instance.isConnected; 

                  if (isConnected) {
                    _sendConfigToDevice();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Configuration Sent & Saved!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // --- 3. OFFLINE FEEDBACK ---
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Device Offline: Settings Saved to App Only"),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Apply All Changes", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildScrollablePage(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 25),
    ]);
  }

  Widget _buildTimerSlider({required String label, required double value, required String unit, required double max, required Function(double) onChanged}) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text("${value.toInt()} $unit", style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: value, min: 0, max: max, activeColor: AppTheme.primaryBlue, onChanged: onChanged),
      const SizedBox(height: 15),
    ]);
  }

  Widget _buildThresholdSlider({required String label, required double value, required Function(double) onChanged}) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(value.toInt().toString(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: value, min: 0, max: 4095, activeColor: Colors.amber, onChanged: onChanged),
      const SizedBox(height: 15),
    ]);
  }

  Widget _buildPinStatusCard(String label, int pinValue, int threshold) {
    // Logic: If Pin Value < Threshold, it usually means 'ON' for active-low sensors.
    bool isOn = pinValue < threshold; 
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("Current: $pinValue", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // Using withOpacity for broader compatibility if withValues isn't available in your Flutter SDK yet
              color: isOn ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isOn ? "STATE: ON" : "STATE: OFF", 
              style: TextStyle(color: isOn ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}