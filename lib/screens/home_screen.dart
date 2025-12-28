import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'package:file_picker/file_picker.dart';

import '../theme.dart';
import '../services/bluetooth_service.dart';
import '../services/user_preferences.dart'; 
import '../widgets/device_info_card.dart';
import '../widgets/app_drawer.dart'; 
// import 'monitor_screen.dart';
import 'login_screen.dart'; 
import 'schedules_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final String userName; 
  final String phoneNumber;

  const HomeScreen({
    super.key, 
    required this.userName,
    required this.phoneNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); 
  
  String connectionStatus = "Disconnected";
  bool isMotorOn = false; 
  String deviceTime = "--:--"; 
  DateTime? _lastCommandTime;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    
    SevakBluetoothService.instance.statusStream.listen((status) {
      if (mounted) setState(() => connectionStatus = status);
    });
    
    SevakBluetoothService.instance.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          bool recentlyClicked = _lastCommandTime != null && 
              DateTime.now().difference(_lastCommandTime!).inSeconds < 2;

          if (!recentlyClicked && data.containsKey('relayState')) {
            isMotorOn = data['relayState']; 
          }
          
          if (data.containsKey('deviceTime')) {
             deviceTime = data['deviceTime'].toString();
          }
          
          if (data.containsKey('deviceConnected') && data['deviceConnected'] == true) {
             connectionStatus = "Connected";
          }
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan, 
      Permission.bluetoothConnect, 
      Permission.location, 
      Permission.storage
    ].request();
  }

  void _logout() async {
    await UserPreferences().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, 
    );
  }

  void _showDeviceList() {
    SevakBluetoothService.instance.startScan();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              const Text("Select Sevak Device", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white10, height: 20),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: SevakBluetoothService.instance.scanResults,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Scanning for devices...", style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final r = snapshot.data![index];
                        return ListTile(
                          title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : "Unknown Device", style: const TextStyle(color: Colors.white)),
                          trailing: ElevatedButton(
                            onPressed: () { 
                              Navigator.pop(context); 
                              SevakBluetoothService.instance.connectToDevice(r.device); 
                            },
                            child: const Text("Connect"),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => SevakBluetoothService.instance.stopScan());
  }

  Future<void> _pickAndUploadFirmware() async {
    if (!SevakBluetoothService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connect to device first!")));
      return;
    }
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['bin']);
    
    if (result == null) return; 
    if (!mounted) return;       

    File file = File(result.files.single.path!);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text("Updating Firmware...", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [LinearProgressIndicator(color: AppTheme.primaryPlum), SizedBox(height: 15), Text("Uploading...", style: TextStyle(color: Colors.grey))]),
      ),
    );
    
    try {
      await SevakBluetoothService.instance.uploadFirmware(file, (progress) { debugPrint("Upload: $progress"); });
      
      if (mounted) Navigator.pop(context); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update Successful!")));
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update Failed: $e")));
    }
  }

  void _togglePower() async {
    HapticFeedback.mediumImpact();
    if (SevakBluetoothService.instance.isConnected) {
      _lastCommandTime = DateTime.now();
      setState(() => isMotorOn = !isMotorOn);
      await SevakBluetoothService.instance.toggleMotor(isMotorOn);
    } else {
      _showDeviceList();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = SevakBluetoothService.instance.isConnected; 

    return Scaffold(
      key: _scaffoldKey,
      drawer: SevakDrawer(
        userName: widget.userName,
        phoneNumber: widget.phoneNumber,
      ), 
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu), 
          onPressed: () => _scaffoldKey.currentState?.openDrawer()
        ),
        // REMOVED: Title and CenterTitle
        actions: [
          IconButton(icon: const Icon(Icons.cloud_upload), onPressed: _pickAndUploadFirmware),
          // REMOVED: Console/Monitor Icon
          IconButton(
            icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled), 
            onPressed: isConnected ? SevakBluetoothService.instance.disconnect : _showDeviceList,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.errorRed), 
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DeviceInfoCard(status: connectionStatus, isConnected: isConnected, deviceTime: deviceTime),
              const SizedBox(height: 30),
              
              // --- 1. SEVAK DEVICE IMAGE ---
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'Assets/sevak_img.jpeg',
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[900],
                      child: const Center(child: Text("Image not found", style: TextStyle(color: Colors.grey))),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 50), 
              
              // --- 2. SCHEDULES BUTTON ---
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const SchedulesScreen())
                  );
                },
                child: Container(
                  width: 280, 
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor, 
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(
                      color: Colors.white24, 
                      width: 2
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month, color: Colors.white, size: 32),
                      SizedBox(width: 15),
                      Text(
                        "Schedules",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 24)
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30), 

              // --- 3. POWER BUTTON ---
              GestureDetector(
                onTap: _togglePower, 
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 240, 
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: isMotorOn 
                        ? AppTheme.accentGreen.withValues(alpha: 0.1) 
                        : AppTheme.cardColor, 
                    border: Border.all(
                      color: isMotorOn 
                          ? AppTheme.accentGreen 
                          : AppTheme.errorRed.withValues(alpha: 0.5), 
                      width: 3
                    ),
                    boxShadow: [
                      if (isMotorOn) 
                        BoxShadow(
                          color: AppTheme.accentGreen.withValues(alpha: 0.4), 
                          blurRadius: 30,
                          spreadRadius: 2
                        )
                    ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.power_settings_new, 
                        size: 36, 
                        color: isMotorOn ? AppTheme.accentGreen : AppTheme.errorRed
                      ),
                      const SizedBox(width: 15),
                      Text(
                        isMotorOn ? "SYSTEM ON" : "SYSTEM OFF", 
                        style: const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        )
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}