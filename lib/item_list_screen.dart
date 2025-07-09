import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'main.dart'; // Access inventoryByLocation map

class ItemListScreen extends StatefulWidget {
  final String locationName;

  const ItemListScreen({super.key, required this.locationName});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  List<Map<String, String>> get items => inventoryByLocation[widget.locationName] ?? [];

  String scannedBarcode = "";

  @override
  void initState() {
    super.initState();
    _loadItemsFromFile();
  }

  Future<File> _getLocationFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${widget.locationName}.json';
    return File(path);
  }

  Future<void> _loadItemsFromFile() async {
    final file = await _getLocationFile();
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(contents);
      if (mounted) {
        setState(() {
          inventoryByLocation[widget.locationName] = decoded.map<Map<String, String>>((
            e,
          ) {
            return e.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            );
          }).toList();
        });
      }
    } else {
      inventoryByLocation[widget.locationName] = [];
    }
  }

  Future<void> _saveItemsToFile() async {
    final file = await _getLocationFile();
    final jsonData = jsonEncode(items);
    await file.writeAsString(jsonData);
  }

  void _showAddItemDialog({int? editIndex}) {
    final TextEditingController nameController = TextEditingController(
      text: editIndex != null ? items[editIndex]["name"] ?? '' : '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: editIndex != null ? items[editIndex]["description"] ?? '' : '',
    );

    // Set scannedBarcode to the current item's barcode if editing, else empty
    scannedBarcode = editIndex != null ? (items[editIndex]["barcode"] ?? '') : '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(editIndex != null ? "Edit Item" : "Add New Item"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Item Name"),
                  ),
                  TextButton(
                    onPressed: () async {
                      String? res = await SimpleBarcodeScanner.scanBarcode(
                        context,
                        barcodeAppBar: BarcodeAppBar(
                          appBarTitle: 'Test',
                          centerTitle: false,
                          enableBackButton: true,
                          backButtonIcon: Icon(Icons.arrow_back),
                        ),
                        isShowFlashIcon: true,
                        delayMillis: 500,
                        cameraFace: CameraFace.back,
                        scanFormat: ScanFormat.ONLY_BARCODE,
                      );
                      setStateDialog(() {
                        scannedBarcode = res ?? '';
                      });
                    },
                    child: const Text("Scan Barcode"),
                  ),
                  // Show the scanned barcode for feedback
                  if (scannedBarcode.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "Scanned: $scannedBarcode",
                        style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                      ),
                    ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Description (optional)",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text(editIndex != null ? "Update" : "Add"),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      setState(() {
                        if (editIndex != null) {
                          items[editIndex]["name"] = nameController.text;
                          items[editIndex]["description"] = descriptionController.text;
                          items[editIndex]["barcode"] = scannedBarcode;
                        } else {
                          items.add({
                            "name": nameController.text,
                            "description": descriptionController.text,
                            "barcode": scannedBarcode,
                          });
                        }
                      });
                      await _saveItemsToFile();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Item"),
          content: const Text("Are you sure you want to delete this item?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Delete"),
              onPressed: () async {
                setState(() {
                  items.removeAt(index);
                });
                await _saveItemsToFile();
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Items in ${widget.locationName}')),
      body: items.isEmpty
          ? const Center(
              child: Text(
                "No items added yet.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(items[index]['name'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[index]['description'] ?? ''),
                        Text("Barcode: ${items[index]['barcode'] ?? ''}"),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddItemDialog(editIndex: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmDelete(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
