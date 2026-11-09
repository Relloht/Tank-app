import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'db/database_helper.dart';
import 'services/ocr_service.dart';
import 'services/location_service.dart';

void main() => runApp(const MaterialApp(home: TankTrackerApp(), debugShowCheckedModeBanner: false));

class TankTrackerApp extends StatefulWidget {
  const TankTrackerApp({super.key});
  @override
  State<TankTrackerApp> createState() => _TankTrackerAppState();
}

class _TankTrackerAppState extends State<TankTrackerApp> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();

  List> _vehicles = [];
  int? _selectedVehicleId;

  // Formular-Controller
  final _tripKmController = TextEditingController();
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalCostController = TextEditingController();
  String _detectedCountry = 'Ermittle...';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final list = await DatabaseHelper.instance.getVehicles();
    setState(() {
      _vehicles = list;
      if (list.isNotEmpty) _selectedVehicleId = list.first['id'] as int;
    });
  }

  Future<void> _snapDashboard() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _loading = true);
    String raw = await _ocrService.extractText(File(photo.path));
    double km = _ocrService.parseTripKm(raw);
    setState(() {
      _tripKmController.text = km > 0 ? km.toString() : '';
      _loading = false;
    });
  }

  Future<void> _snapReceipt() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _loading = true);
    // Text erkennen & GPS parallel abrufen
    String raw = await _ocrService.extractText(File(photo.path));
    Map<String, double> data = _ocrService.parseReceipt(raw);
    String country = await LocationService.getCurrentCountry();

    setState(() {
      _litersController.text = data['liters']! > 0 ? data['liters'].toString() : '';
      _priceController.text = data['pricePerLiter']! > 0 ? data['pricePerLiter'].toString() : '';
      _totalCostController.text = data['totalCost']! > 0 ? data['totalCost'].toString() : '';
      _detectedCountry = country;
      _loading = false;
    });
  }

  Future<void> _saveEntry() async {
    if (_selectedVehicleId == null) return;

    await DatabaseHelper.instance.insertEntry({
      'vehicle_id': _selectedVehicleId,
      'timestamp': DateTime.now().toIso8601String(),
      'country': _detectedCountry,
      'trip_km': double.tryParse(_tripKmController.text) ?? 0.0,
      'liters': double.tryParse(_litersController.text) ?? 0.0,
      'price_per_liter': double.tryParse(_priceController.text) ?? 0.0,
      'total_cost': double.tryParse(_totalCostController.text) ?? 0.0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tankeintrag erfolgreich gespeichert!')),
    );

    _tripKmController.clear();
    _litersController.clear();
    _priceController.clear();
    _totalCostController.clear();
  }

  void _showStats() async {
    if (_selectedVehicleId == null) return;
    final stats = await DatabaseHelper.instance.getStatsByCountry(_selectedVehicleId!);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kilometer & Ausgaben nach Land', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: stats.length,
                itemBuilder: (ctx, i) {
                  final row = stats[i];
                  return ListTile(
                    title: Text('${row['country']}'),
                    subtitle: Text('${row['total_km']} km | ${row['total_liters']} Liter'),
                    trailing: Text('${row['total_spent']} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tank & Trip Erfassung'),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: _showStats),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Fahrzeug wählen'),
                    items: _vehicles.map((v) {
                      return DropdownMenuItem<int>(
                        value: v['id'] as int,
                        child: Text(v['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedVehicleId = val),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _snapDashboard,
                          icon: const Icon(Icons.speed),
                          label: const Text('1. Tacho'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _snapReceipt,
                          icon: const Icon(Icons.receipt),
                          label: const Text('2. Beleg'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Erkanntes Land: $_detectedCountry', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(controller: _tripKmController, decoration: const InputDecoration(labelText: 'Trip-Kilometer (km)')),
                  TextField(controller: _litersController, decoration: const InputDecoration(labelText: 'Menge (Liter)')),
                  TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'Literpreis (€)')),
                  TextField(controller: _totalCostController, decoration: const InputDecoration(labelText: 'Gesamtpreis (€)')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: _saveEntry,
                      child: const Text('Eintrag Speichern'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}