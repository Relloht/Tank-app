import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tank_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        country TEXT NOT NULL,
        trip_km REAL NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        total_cost REAL NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id)
      )
    ''');

    await db.insert('vehicles', {'name': 'Africa Twin'});
    await db.insert('vehicles', {'name': 'Honda Rebel'});
    await db.insert('vehicles', {'name': 'Auto / Daily'});
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await instance.database;
    return await db.query('vehicles');
  }

  Future<int> insertEntry(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('fuel_entries', row);
  }

  Future<List<Map<String, dynamic>>> getStatsByCountry(int vehicleId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT country, SUM(trip_km) as total_km, SUM(total_cost) as total_spent, SUM(liters) as total_liters
      FROM fuel_entries
      WHERE vehicle_id = ?
      GROUP BY country
    ''', [vehicleId]);
  }
}
