import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

void main() {
  runApp(const IoTControllerApp());
}

class IoTControllerApp extends StatelessWidget {
  const IoTControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BluetoothConnectionScreen(),
    );
  }
}

class BluetoothConnectionScreen extends StatefulWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  State<BluetoothConnectionScreen> createState() => _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  // Bluetooth state variables
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  
  bool _isScanning = false;
  bool _isConnected = false;
  String _statusMessage = 'Not connected';
  
  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }
  
  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  // Initialize Bluetooth and check permissions
  Future<void> _initializeBluetooth() async {
    // Request permissions
    await _requestPermissions();
    
    // Get current Bluetooth state
    _bluetoothState = await _bluetooth.state;
    
    // Listen for Bluetooth state changes
    _bluetooth.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
      });
    });
    
    setState(() {});
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    bool allGranted = statuses.values.every((status) => status.isGranted);
    
    if (!allGranted) {
      _showMessage('Bluetooth permissions are required');
    }
  }

  // Scan for Bluetooth devices
  Future<void> _scanForDevices() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _devicesList.clear();
      _statusMessage = 'Scanning for devices...';
    });

    try {
      // Get bonded (paired) devices
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
      
      setState(() {
        _devicesList = bondedDevices;
        _isScanning = false;
        _statusMessage = 'Found ${bondedDevices.length} paired device(s)';
      });
      
      if (bondedDevices.isEmpty) {
        _showMessage('No paired devices found. Please pair your Bluetooth module in Android settings first.');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error scanning: $e';
      });
      _showMessage('Error scanning for devices: $e');
    }
  }

  // Connect to selected device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = 'Connecting to ${device.name ?? device.address}...';
    });

    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      
      setState(() {
        _connection = connection;
        _connectedDevice = device;
        _isConnected = true;
        _statusMessage = 'Connected to ${device.name ?? device.address}';
      });
      
      _showMessage('Successfully connected!');
      
      // Listen for incoming data
      _connection!.input!.listen(
        _onDataReceived,
        onDone: () {
          _disconnect();
        },
        onError: (error) {
          _showMessage('Connection error: $error');
          _disconnect();
        },
      );
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed';
      });
      _showMessage('Could not connect to device: $e');
    }
  }

  // Handle incoming data
  void _onDataReceived(Uint8List data) {
    String message = String.fromCharCodes(data);
    print('Received: $message');
    // For Week 1, we just log received data
    // In future weeks, we'll process commands here
  }

  // Disconnect from device
  void _disconnect() {
    _connection?.dispose();
    setState(() {
      _connection = null;
      _connectedDevice = null;
      _isConnected = false;
      _statusMessage = 'Disconnected';
    });
  }

  // Send test command
  Future<void> _sendCommand(String command) async {
    if (_connection == null || !_isConnected) {
      _showMessage('Not connected to any device');
      return;
    }

    try {
      _connection!.output.add(Uint8List.fromList('$command\n'.codeUnits));
      await _connection!.output.allSent;
      print('Sent: $command');
    } catch (e) {
      _showMessage('Error sending command: $e');
    }
  }

  // Show snackbar message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('IoT Controller - Week 1'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_connected),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            )
          else
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.cancel,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConnected ? 'Connected' : 'Not Connected',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _statusMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_connectedDevice != null)
                              Text(
                                _connectedDevice!.name ?? _connectedDevice!.address,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_bluetoothState != BluetoothState.STATE_ON)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Bluetooth is turned off. Please enable it.',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Scan button
          if (!_isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanForDevices,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          
          // Device list
          if (!_isConnected)
            Expanded(
              child: _devicesList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Scan for Devices" to start',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devicesList.length,
                      itemBuilder: (context, index) {
                        BluetoothDevice device = _devicesList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(device.name ?? 'Unknown Device'),
                            subtitle: Text(device.address),
                            trailing: ElevatedButton(
                              onPressed: () => _connectToDevice(device),
                              child: const Text('Connect'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          
          // Test controls (when connected)
          if (_isConnected)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Connection Test Commands',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _sendCommand('PING'),
                      icon: const Icon(Icons.send),
                      label: const Text('Send PING'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _sendCommand('STATUS'),
                      icon: const Icon(Icons.info),
                      label: const Text('Request STATUS'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
