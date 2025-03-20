import 'dart:async';

import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

enum ScreenState {
  deviceList,
  control,
  loading,
  result,
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rüzgar Simülasyonu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BluetoothDevicesScreen(),
    );
  }
}

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  State<BluetoothDevicesScreen> createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen> {
  final _bluetoothClassicPlugin = BluetoothClassic();
  List<Device> devices = [];
  bool isLoading = false;
  bool isConnecting = false;
  Device? connectedDevice;
  String connectionStatus = '';
  Uint8List receivedData = Uint8List(0);

  ScreenState currentScreen = ScreenState.deviceList;

  String selectedDirection = 'K';
  int selectedSpeed = 5;

  double r1Value = 0.0;
  double r2Value = 0.0;
  double r3Value = 0.0;
  double r4Value = 0.0;

  double r1Max = 0.0;
  double r2Max = 0.0;
  double r3Max = 0.0;
  double r4Max = 0.0;

  double r1Initial = 0.0;
  double r2Initial = 0.0;
  double r3Initial = 0.0;
  double r4Initial = 0.0;

  double r1Delta = 0.0;
  double r2Delta = 0.0;
  double r3Delta = 0.0;
  double r4Delta = 0.0;

  List<String> dataHistory = [];
  bool isTestRunning = false;
  bool receivedEndSignal = false;

  List<double> r1Values = [];
  List<double> r2Values = [];
  List<double> r3Values = [];
  List<double> r4Values = [];

  final TextEditingController kuzeyController = TextEditingController();
  final TextEditingController karayelController = TextEditingController();
  final TextEditingController poyrazController = TextEditingController();
  final TextEditingController batiController = TextEditingController();
  final TextEditingController doguController = TextEditingController();
  final TextEditingController lodosController = TextEditingController();
  final TextEditingController kesislemeController = TextEditingController();
  final TextEditingController guneyController = TextEditingController();

  double _opacity = 1;
  TextEditingController? activeController;

  double _animationX = 80;
  double _animationY = 0; 
  double screenHeight = 0;
  double screenWidth = 0;

  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
    _setupBluetoothListeners();
  }

  @override
  void dispose() {
    kuzeyController.dispose();
    karayelController.dispose();
    poyrazController.dispose();
    batiController.dispose();
    doguController.dispose();
    lodosController.dispose();
    kesislemeController.dispose();
    guneyController.dispose();
    _disconnectDevice();
    super.dispose();
  }

  void _setupBluetoothListeners() {
    _bluetoothClassicPlugin.onDeviceDataReceived().listen((data) {
      setState(() {
        receivedData = Uint8List.fromList([...receivedData, ...data]);
        _processReceivedData();
      });
    });
  }

  void _processReceivedData() {
    final dataString = _getReceivedDataAsString();
    final lines = dataString.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line == "END") {
        setState(() {
          r1Value = r1Values.isNotEmpty ? _calculateAverage(r1Values) : 0.0;
          r2Value = r2Values.isNotEmpty ? _calculateAverage(r2Values) : 1.1;
          r3Value = r3Values.isNotEmpty ? _calculateAverage(r3Values) : 0.0;
          r4Value = r4Values.isNotEmpty ? _calculateAverage(r4Values) : 0.0;

          r1Delta = r1Value - r1Initial;
          r2Delta = r2Value - r2Initial;
          r3Delta = r3Value - r3Initial;
          r4Delta = r4Value - r4Initial;

          r1Delta = r1Delta < 0 ? 0 : r1Delta;
          r2Delta = r2Delta < 0 ? 0 : r2Delta;
          r3Delta = r3Delta < 0 ? 0 : r3Delta;
          r4Delta = r4Delta < 0 ? 0 : r4Delta;

          receivedEndSignal = true;
          currentScreen = ScreenState.result;
        });
        continue;
      }

      if (!dataHistory.contains(line)) {
        if (dataHistory.length >= 20) {
          dataHistory.removeAt(0);
        }
        dataHistory.add(line);

        double? tempR1, tempR2, tempR3, tempR4;

        final sensorReadings = line.split(',');
        for (var reading in sensorReadings) {
          reading = reading.trim();
          if (reading.startsWith('R1:')) {
            tempR1 = double.tryParse(reading.substring(3).trim());
          } else if (reading.startsWith('R2:')) {
            tempR2 = double.tryParse(reading.substring(3).trim());
          } else if (reading.startsWith('R3:')) {
            tempR3 = double.tryParse(reading.substring(3).trim());
          } else if (reading.startsWith('R4:')) {
            tempR4 = double.tryParse(reading.substring(3).trim());
          }
        }

        if (tempR1 != null &&
            tempR2 != null &&
            tempR3 != null &&
            tempR4 != null &&
            tempR1 != 0 &&
            tempR2 != 0 &&
            tempR3 != 0 &&
            tempR4 != 0) {
          r1Values.add(tempR1);
          r1Max = tempR1 > r1Max ? tempR1 : r1Max;
          if (!isTestRunning) {
            r1Initial = tempR1;
          }

          r2Values.add(tempR2);
          r2Max = tempR2 > r2Max ? tempR2 : r2Max;
          if (!isTestRunning) {
            r2Initial = tempR2;
          }

          r3Values.add(tempR3);
          r3Max = tempR3 > r3Max ? tempR3 : r3Max;
          if (!isTestRunning) {
            r3Initial = tempR3;
          }

          r4Values.add(tempR4);
          r4Max = tempR4 > r4Max ? tempR4 : r4Max;
          if (!isTestRunning) {
            r4Initial = tempR4;
            isTestRunning = true;
          }
        }
      }
    }
  }

  void _resetTest() {
    setState(() {
      _showAnimation = false;
      isTestRunning = false;
      receivedEndSignal = false;
      dataHistory.clear();
      receivedData = Uint8List(0);
      r1Value = 0.0;
      r2Value = 0.0;
      r3Value = 0.0;
      r4Value = 0.0;
      r1Delta = 0.0;
      r2Delta = 0.0;
      r3Delta = 0.0;
      r4Delta = 0.0;
      r1Max = 0.0;
      r2Max = 0.0;
      r3Max = 0.0;
      r4Max = 0.0;
      r1Values.clear();
      r2Values.clear();
      r3Values.clear();
      r4Values.clear();
      currentScreen = ScreenState.control;
    });
  }

  Future<void> _sendDirectionAndSpeed() async {
    final command = '$selectedDirection$selectedSpeed';
    try {
      await _bluetoothClassicPlugin.write(command);
      _showSnackBar('Komut gönderildi: $command');
      setState(() {
        isTestRunning = false;
        receivedEndSignal = false;
        dataHistory.clear();
        r1Max = 0.0;
        r2Max = 0.0;
        r3Max = 0.0;
        r4Max = 0.0;
        r1Values.clear();
        r2Values.clear();
        r3Values.clear();
        r4Values.clear();
        currentScreen = ScreenState.loading;
      });
    } catch (e) {
      _showSnackBar('Veri gönderme hatası: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _checkPermissionsAndScan() async {
    if (await Permission.bluetooth.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted) {
      _startScan();
    }
  }

  Future<void> _startScan() async {
    setState(() {
      isLoading = true;
      devices.clear();
    });

    try {
      await _bluetoothClassicPlugin.initPermissions();
      final pairedDevices = await _bluetoothClassicPlugin.getPairedDevices();

      setState(() {
        devices = pairedDevices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        _showSnackBar('Hata: $e');
      }
    }
  }

  Future<void> _connectToDevice(Device device) async {
    if (connectedDevice != null) {
      await _disconnectDevice();
    }

    setState(() {
      isConnecting = true;
      connectionStatus = '${device.name} cihazına bağlanıyor...';
    });

    try {
      const String uuid = "00001101-0000-1000-8000-00805f9b34fb";

      await _bluetoothClassicPlugin.connect(device.address, uuid);

      setState(() {
        connectedDevice = device;
        connectionStatus = 'Bağlandı: ${device.name}';
        isConnecting = false;

        r1Initial = 0.0;
        r2Initial = 0.0;
        r3Initial = 0.0;
        r4Initial = 0.0;
        r1Delta = 0.0;
        r2Delta = 0.0;
        r3Delta = 0.0;
        r4Delta = 0.0;
        dataHistory.clear();
        receivedData = Uint8List(0);
      });

      _showSnackBar('Cihaza bağlandı: ${device.name}');
    } catch (e) {
      setState(() {
        isConnecting = false;
        connectionStatus = 'Bağlantı hatası: $e';
      });
      _showSnackBar('Bağlantı hatası: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await _bluetoothClassicPlugin.disconnect();
        setState(() {
          connectedDevice = null;
          connectionStatus = 'Bağlantı kesildi';
        });
      } catch (e) {
        _showSnackBar('Bağlantı kesme hatası: $e');
      }
    }
  }

  String _getReceivedDataAsString() {
    try {
      return String.fromCharCodes(receivedData);
    } catch (e) {
      return "Veri dönüştürme hatası: $e";
    }
  }

  Color _getSensorDeltaColor(double delta) {
    delta = delta < 0 ? 0 : delta;

    if (delta < 5) {
      return Colors.grey.shade400; 
    } else if (delta < 15) {
      return Colors.blue.shade300;
    } else if (delta < 30) {
      return Colors.orange; 
    } else {
      return Colors.red;
    }
  }

  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = (MediaQuery.of(context).size.height / 2).round() * 2;
    screenWidth = (MediaQuery.of(context).size.width / 2).round() * 2;
    _animationY == 0 ? MediaQuery.of(context).size.height / 5.5 : _animationY;
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          if (currentScreen == ScreenState.deviceList)
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
          if (currentScreen != ScreenState.deviceList &&
              currentScreen != ScreenState.control)
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: _resetTest,
              tooltip: 'Yeni Test',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(child: _buildCurrentScreen()),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (currentScreen) {
      case ScreenState.deviceList:
        return 'Bluetooth Cihazları';
      case ScreenState.control:
        return 'Rüzgar Kontrolü';
      case ScreenState.loading:
        return 'Test Devam Ediyor';
      case ScreenState.result:
        return 'Test Sonuçları';
    }
  }

  Widget _buildCurrentScreen() {
    switch (currentScreen) {
      case ScreenState.deviceList:
      return _buildDeviceList();
      case ScreenState.control:
        return _buildControlScreen();
      case ScreenState.loading:
        return _buildLoadingScreen();
      case ScreenState.result:
        return _buildResultScreen();
    }
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      color:
          connectedDevice != null
              ? Colors.green.shade100
              : Colors.grey.shade200,
      child: Row(
        children: [
          Icon(
            connectedDevice != null
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: connectedDevice != null ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connectionStatus.isEmpty ? 'Bağlı değil' : connectionStatus,
              style: TextStyle(
                color:
                    connectedDevice != null
                        ? Colors.green.shade800
                        : Colors.grey.shade800,
              ),
            ),
          ),
          if (connectedDevice != null &&
              currentScreen == ScreenState.deviceList)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentScreen = ScreenState.control;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Kontrole Geç'),
            ),
          if (connectedDevice != null) const SizedBox(width: 8),
          if (connectedDevice != null)
            ElevatedButton(
              onPressed: _disconnectDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade800,
              ),
              child: const Text('Bağlantıyı Kes'),
            ),
        ],
      ),
    );
  }

  String _getDirectionCode(TextEditingController controller) {
    if (controller == kuzeyController) return "KY";
    if (controller == karayelController) return "KL";
    if (controller == poyrazController) return "PZ";
    if (controller == batiController) return "BT";
    if (controller == doguController) return "DG";
    if (controller == lodosController) return "LS";
    if (controller == kesislemeController) return "KE";
    if (controller == guneyController) return "GY";
    return "";
  }

  Widget _buildControlScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_windInputs("KUZEY", 0)],
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [_windInputs("KARAYEL", 7), _windInputs("POYRAZ", 1)],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _windInputs("BATI", 6),
                  SizedBox(width: 10),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.brown[300],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.brown, width: 2),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.brown[700],
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 5,
                          left: 35,
                          right: 35,
                          child: Stack(
                            children: [
                              Container(
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Positioned(
                                bottom: 15,
                                left: 5,
                                child: Container(
                                  height: 5,
                                  width: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        for (int j = 0; j < 2; j++)
                          Positioned(
                            top: 20,
                            left: 10 + (j * 50),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.blue[200],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  _windInputs("DOĞU", 2),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _windInputs("LODOS", 5),
                  _windInputs("KEŞİŞLEME", 3),
                ],
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_windInputs("GÜNEY", 4)],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (activeController != null &&
                  activeController!.text.isNotEmpty) {
                final speed = int.tryParse(activeController!.text) ?? 0;
                final direction = _getDirectionCode(activeController!);
                if (direction.isNotEmpty) {
                  setState(() {
                    selectedDirection = direction;
                    selectedSpeed = speed;
                    switch (selectedDirection) {
                      case "KY":
                        _animationX =
                            MediaQuery.of(context).size.width / 2 - 40;
                        _animationY = screenHeight * 0.05;
                        break;
                      case "KL":
                        _animationX = screenWidth * 0.2 + 25;
                        _animationY = screenHeight * 0.08;
                        break;
                      case "PZ":
                        _animationX = screenWidth * 0.5;
                        _animationY = screenHeight * 0.08;
                        break;
                      case "BT":
                        _animationX = screenWidth * 0.2;
                        _animationY = screenHeight * 0.1;
                        break;
                      case "DG":
                        _animationX = screenWidth * 0.6;
                        _animationY = screenHeight * 0.1;
                        break;
                      case "LS":
                        _animationX = screenWidth * 0.2 + 25;
                        _animationY = screenHeight * 0.14;
                        break;
                      case "KE":
                        _animationX = screenWidth * 0.5;
                        _animationY = screenHeight * 0.14;
                        break;
                      case "GY":
                        _animationX =
                            MediaQuery.of(context).size.width / 2 - 40;
                        _animationY = screenHeight * 0.17;
                        break;
                    }
                  });
                  _sendDirectionAndSpeed();
                } else {
                  _showSnackBar('Lütfen bir yön seçin');
                }
              } else {
                _showSnackBar('Lütfen bir yön ve hız değeri girin');
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: Text('Testi Başlat', style: const TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDirectionArrow(String direction) {
    switch (direction) {
      case "KY":
        return Icons.arrow_downward;
      case "GY":
        return Icons.arrow_upward;
      case "DG":
        return Icons.arrow_back;
      case "BT":
        return Icons.arrow_forward;
      case "KL":
        return Icons.south_east;
      case "PZ":
        return Icons.south_west;
      case "LS":
        return Icons.north_east;
      case "KE":
        return Icons.north_west;
      default:
        return Icons.arrow_forward;
    }
  }

  Widget _buildLoadingScreen() {
    if (!_showAnimation) {
      setState(() {
        _showAnimation = true;
      });
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (currentScreen != ScreenState.loading) {
          timer.cancel();
          return;
        }
        setState(() {
          switch (selectedDirection) {
            case "KY":
              _animationX = MediaQuery.of(context).size.width / 2 - 40;
              _animationY =
                  _animationY >= screenHeight * 0.17
                      ? screenHeight * 0.05
                      : _animationY + screenHeight * 0.04;
              break;
            case "KL":
              _animationX =
                  _animationX >= screenWidth * 0.5
                      ? screenWidth * 0.2 + 25
                      : _animationX + screenWidth * 0.1;
              _animationY =
                  _animationY >= screenHeight * 0.17
                      ? screenHeight * 0.08
                      : _animationY + screenHeight * 0.03;
              break;
            case "PZ":
              _animationX =
                  _animationX <= screenWidth * 0.2
                      ? screenWidth * 0.5
                      : _animationX - screenWidth * 0.1;
              _animationY =
                  _animationY >= screenHeight * 0.17
                      ? screenHeight * 0.08
                      : _animationY + screenHeight * 0.03;
              break;
            case "BT":
              _animationX =
                  _animationX >= screenWidth * 0.5
                      ? screenWidth * 0.2
                      : _animationX + screenWidth * 0.133334;
              _animationY = screenHeight * 0.1;
              break;
            case "DG":
              _animationX =
                  _animationX <= screenWidth * 0.3
                      ? screenWidth * 0.6
                      : _animationX - screenWidth * 0.133334;
              _animationY = screenHeight * 0.1;
              break;
            case "LS":
              _animationX =
                  _animationX >= screenWidth * 0.5
                      ? screenWidth * 0.2 + 25
                      : _animationX + screenWidth * 0.1;
              _animationY =
                  _animationY <= screenHeight * 0.08
                      ? screenHeight * 0.14
                      : _animationY - screenHeight * 0.03;
              break;
            case "KE":
              _animationX =
                  _animationX <= screenWidth * 0.2
                      ? screenWidth * 0.5
                      : _animationX - screenWidth * 0.1;
              _animationY =
                  _animationY <= screenHeight * 0.08
                      ? screenHeight * 0.14
                      : _animationY - screenHeight * 0.03;
              break;
            case "GY":
              _animationX = MediaQuery.of(context).size.width / 2 - 40;
              _animationY =
                  _animationY <= screenHeight * 0.05
                      ? screenHeight * 0.17
                      : _animationY - screenHeight * 0.04;
              break;
          }
        });
      });
    }

    return Column(
      children: [
        SizedBox(height: 150),
        Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_windInputs("KUZEY", 0)],
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _windInputs("KARAYEL", 7),
                        _windInputs("POYRAZ", 1),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _windInputs("BATI", 6),
                        SizedBox(width: 10),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.brown[300],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.brown, width: 2),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -20,
                                left: 10,
                                right: 10,
                                child: Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.brown[700],
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),

                              Positioned(
                                bottom: 5,
                                left: 35,
                                right: 35,
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 15,
                                      left: 5,
                                      child: Container(
                                        height: 5,
                                        width: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              for (int j = 0; j < 2; j++)
                                Positioned(
                                  top: 20,
                                  left: 10 + (j * 50),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[200],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        _windInputs("DOĞU", 2),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _windInputs("LODOS", 5),
                        _windInputs("KEŞİŞLEME", 3),
                      ],
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_windInputs("GÜNEY", 4)],
                    ),
                  ],
                ),
              ],
            ),
            if (_showAnimation)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                left: _animationX,
                top: _animationY,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _opacity,
                  child: Row(
                    children: List.generate(2, (index) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              _getDirectionArrow(selectedDirection),
                              size: 30,
                              color: Colors.blue,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              _getDirectionArrow(selectedDirection),
                              size: 30,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 50),
        const Expanded(
          flex: 1,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 6),
                SizedBox(height: 24),
                Text(
                  'Test Devam Ediyor...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Veriler toplanıyor',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Test Sonuçları',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Uygulanan Komut: $selectedDirection$selectedSpeed',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [_windInputs("KUZEY", 0)],
                          ),
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _windInputs("KARAYEL", 7),
                              Text(
                                '%${r2Delta.toStringAsFixed(2)}' "\neğim",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                              _windInputs("POYRAZ", 1),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _windInputs("BATI", 6),
                              SizedBox(width: 10),
                              Text(
                                '%${r1Delta.toStringAsFixed(2)}' "\neğim",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.brown[300],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.brown,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: -20,
                                      left: 10,
                                      right: 10,
                                      child: Container(
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.brown[700],
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),

                                    Positioned(
                                      bottom: 5,
                                      left: 35,
                                      right: 35,
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 15,
                                            left: 5,
                                            child: Container(
                                              height: 5,
                                              width: 5,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    for (int j = 0; j < 2; j++)
                                      Positioned(
                                        top: 20,
                                        left: 10 + (j * 50),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.blue[200],
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '%${r3Delta.toStringAsFixed(2)}' "\neğim",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                              SizedBox(width: 10),
                              _windInputs("DOĞU", 2),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _windInputs("LODOS", 5),
                              Text(
                                '%${r4Delta.toStringAsFixed(2)}' "\neğim",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                              _windInputs("KEŞİŞLEME", 3),
                            ],
                          ),
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [_windInputs("GÜNEY", 4)],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sensör İstatistikleri',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                      4: FlexColumnWidth(2),
                    },
                    children: [
                      _buildSensorTableHeader(),
                      _buildSensorTableRow(
                        'R1 (Doğu)',
                        r1Initial,
                        r1Value,
                        r1Delta,
                        r1Max,
                      ),
                      _buildSensorTableRow(
                        'R2 (Güney)',
                        r2Initial,
                        r2Value,
                        r2Delta,
                        r2Max,
                      ),
                      _buildSensorTableRow(
                        'R3 (Batı)',
                        r3Initial,
                        r3Value,
                        r3Delta,
                        r3Max,
                      ),
                      _buildSensorTableRow(
                        'R4 (Kuzey)',
                        r4Initial,
                        r4Value,
                        r4Delta,
                        r4Max,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _resetTest,
            icon: const Icon(Icons.replay),
            label: const Text(
              'Yeni Test Başlat',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildSensorTableRow(
    String name,
    double initial,
    double current,
    double delta,
    double max,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(initial.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(current.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getSensorDeltaColor(delta).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _getSensorDeltaColor(delta)),
            ),
            child: Text(
              delta.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getSensorDeltaColor(delta),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            max.toStringAsFixed(2),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildSensorTableHeader() {
    return const TableRow(
      decoration: BoxDecoration(color: Colors.blue),
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Sensör',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Başlangıç',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Ortalama',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Değişim',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'En Yüksek',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _windInputs(String direction, int arrowDirection) {
    TextEditingController controller = getController(direction);
    bool isLoadingScreen = currentScreen == ScreenState.loading;

    return Column(
      children: [
        arrowDirection > 3
            ? Row(
              children: [
                Text(direction, style: TextStyle(fontWeight: FontWeight.bold)),
                Transform.rotate(
                  angle: arrowDirection * 3.14 / 4,
                  child: Icon(Icons.arrow_downward, color: Colors.blue),
                ),
              ],
            )
            : Row(
              children: [
                Transform.rotate(
                  angle: arrowDirection * 3.14 / 4,
                  child: Icon(Icons.arrow_downward, color: Colors.blue),
                ),
                Text(direction, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
        if ((isLoadingScreen || currentScreen == ScreenState.result) &&
            selectedDirection == _getDirectionCode(controller))
          Text(
            "$selectedSpeed km/saat",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          )
        else if (!isLoadingScreen && currentScreen != ScreenState.result)
          Column(
            children: [
              SizedBox(
                width: 30,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense: true,
                    enabled:
                        activeController == null ||
                        activeController == controller,
                  ),
                  style: TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      int? number = int.tryParse(value);
                      if (number != null && number > 100) {
                        controller.text = '100';
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      }
                      setState(() {
                        activeController = controller;
                      });
                    } else if (controller == activeController) {
                      setState(() {
                        activeController = null;
                      });
                    }
                  },
                ),
              ),
              Text(" km/saat"),
            ],
          ),
      ],
    );
  }

  TextEditingController getController(String direction) {
    switch (direction) {
      case "KUZEY":
        return kuzeyController;
      case "KARAYEL":
        return karayelController;
      case "POYRAZ":
        return poyrazController;
      case "BATI":
        return batiController;
      case "DOĞU":
        return doguController;
      case "LODOS":
        return lodosController;
      case "KEŞİŞLEME":
        return kesislemeController;
      case "GÜNEY":
        return guneyController;
      default:
        return TextEditingController();
    }
  }

  Widget _buildDeviceList() {
    return isLoading
              ? const Center(child: CircularProgressIndicator())
        : devices.isEmpty
        ? const Center(child: Text('Eşleşmiş cihaz bulunamadı'))
              : ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
            final isConnected = connectedDevice?.address == device.address;

                  return ListTile(
              leading: Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: isConnected ? Colors.green : Colors.blue,
              ),
                    title: Text(device.name ?? 'İsimsiz Cihaz'),
                    subtitle: Text(device.address),
              trailing:
                  isConnected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                    onTap: () {
                if (!isConnected && !isConnecting) {
                  _showConnectionDialog(device);
                }
              },
            );
          },
        );
  }

  void _showConnectionDialog(Device device) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(device.name ?? 'İsimsiz Cihaz'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adres: ${device.address}'),
                const SizedBox(height: 16),
                Text('Bu cihaza bağlanmak istiyor musunuz?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _connectToDevice(device);
                },
                child: const Text('Bağlan'),
              ),
            ],
              ),
    );
  }
}
