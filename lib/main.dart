import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'item_list_screen.dart';

Map<String, List<Map<String, String>>> inventoryByLocation = {
  "Server Room A": [
    {"name": "Laptop", "description": "Dell XPS 13", "barcode": "123456"},
    {"name": "Router", "description": "TP-Link AX50", "barcode": "234567"},
  ],
  "Lab 101": [
    {"name": "Monitor", "description": "Samsung 27\"", "barcode": "345678"},
  ],
  "Library Storage": [],
  "Admin Office": [],
};

DateTime? sessionStart;

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'University Inventory',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginScreen(),
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.amber],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: child,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final String _correctPassword = "admin123";
  String? _errorText;

  void _validateLogin() {
    if (_passwordController.text == _correctPassword) {
      sessionStart = DateTime.now();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      setState(() {
        _errorText = "Incorrect password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Enter password",
                      errorText: _errorText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _validateLogin, child: const Text("Login")),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<String> locations = inventoryByLocation.keys.toList();
  Timer? sessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSessionCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sessionTimer?.cancel();
    super.dispose();
  }

  void _startSessionCheck() {
    sessionTimer?.cancel();
    sessionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (sessionStart != null &&
          DateTime.now().difference(sessionStart!).inMinutes >= 5) {
        _endSession();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (sessionStart == null ||
          DateTime.now().difference(sessionStart!).inMinutes >= 5) {
        _endSession();
      }
    }
  }

  void _endSession() {
    sessionTimer?.cancel();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _addNewLocation() async {
    final TextEditingController nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Location"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "Location name"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Create"),
            onPressed: () async {
              final newLoc = nameCtrl.text.trim();
              if (newLoc.isNotEmpty && !locations.contains(newLoc)) {
                final dir = await getApplicationDocumentsDirectory();
                final file = File('${dir.path}/$newLoc.json');
                await file.writeAsString('[]');
                setState(() {
                  locations.add(newLoc);
                  inventoryByLocation[newLoc] = [];
                });
                Navigator.pop(context);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid or duplicate location.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameLocation(String oldName) async {
    final TextEditingController nameCtrl = TextEditingController(text: oldName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Location"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "New location name"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Rename"),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty &&
                  !locations.contains(newName) &&
                  inventoryByLocation.containsKey(oldName)) {
                final dir = await getApplicationDocumentsDirectory();
                final oldFile = File('${dir.path}/$oldName.json');
                final newFile = File('${dir.path}/$newName.json');
                if (await oldFile.exists()) {
                  await oldFile.rename(newFile.path);
                }
                setState(() {
                  final data = inventoryByLocation.remove(oldName)!;
                  inventoryByLocation[newName] = data;
                  locations[locations.indexOf(oldName)] = newName;
                });
                Navigator.pop(context);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid or duplicate new name.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(String location) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$location.json');
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      inventoryByLocation.remove(location);
      locations.remove(location);
    });
  }

  void _confirmDeleteLocation(String location) {
    final pwdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Enter admin password to delete '$location':"),
        actions: [
          TextField(
            controller: pwdCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                child: const Text("Delete"),
                onPressed: () {
                  if (pwdCtrl.text == "admin123") {
                    Navigator.pop(context);
                    _deleteLocation(location);
                  } else if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("Incorrect password.")));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: locations.isEmpty
            ? const Center(child: Text("No locations yet."))
            : GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: locations.map((loc) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemListScreen(locationName: loc),
                        ),
                      );
                    },
                    child: Card(
                      color: Colors.white.withOpacity(0.9),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 28,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: -6,
                            left: 4,
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                              onPressed: () => _renameLocation(loc),
                            ),
                          ),
                          Positioned(
                            bottom: -6,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _confirmDeleteLocation(loc),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewLocation,
        child: const Icon(Icons.add),
      ),
    );
  }
}
