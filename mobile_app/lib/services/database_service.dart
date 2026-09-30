import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vetri_vehicle_data.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Registered User & Device Binding Table
        await db.execute('''
          CREATE TABLE user_devices (
            device_id TEXT PRIMARY KEY,
            user_identifier TEXT NOT NULL,
            display_name TEXT,
            email TEXT,
            phone TEXT,
            vehicle_name TEXT,
            vehicle_vin TEXT,
            odometer_km INTEGER,
            subscription_tier TEXT,
            created_at TEXT
          )
        ''');

        // Telemetry Logs Table (Auto-pruned FIFO)
        await db.execute('''
          CREATE TABLE telemetry_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            rpm REAL NOT NULL,
            speed REAL NOT NULL,
            coolant_temp REAL NOT NULL,
            battery_voltage REAL NOT NULL,
            fuel_trim REAL NOT NULL,
            triage_level TEXT NOT NULL,
            failure_probability REAL NOT NULL
          )
        ''');

        // DTC Fault Code History
        await db.execute('''
          CREATE TABLE dtc_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            dtc_code TEXT NOT NULL,
            description TEXT NOT NULL,
            severity TEXT NOT NULL,
            resolved INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // ==========================================
  // User & Device Binding Methods
  // ==========================================

  Future<void> bindDeviceUser({
    required String deviceId,
    required String userIdentifier,
    String? displayName,
    String? email,
    String? phone,
    String? vehicleName,
    String? vehicleVin,
    int? odometerKm,
    String? subscriptionTier,
  }) async {
    try {
      final db = await database;
      await db.insert(
        'user_devices',
        {
          'device_id': deviceId,
          'user_identifier': userIdentifier,
          'display_name': displayName ?? 'VETRI Driver',
          'email': email ?? '',
          'phone': phone ?? '',
          'vehicle_name': vehicleName ?? 'KTM Duke 390',
          'vehicle_vin': vehicleVin ?? 'MD2A1234567890VIN',
          'odometer_km': odometerKm ?? 14250,
          'subscription_tier': subscriptionTier ?? '1-MONTH STARTER',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Database bindDeviceUser fallback: ');
    }
  }

  Future<Map<String, dynamic>?> getDeviceBinding(String deviceId) async {
    try {
      final db = await database;
      final results = await db.query(
        'user_devices',
        where: 'device_id = ?',
        whereArgs: [deviceId],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (e) {
      debugPrint('Database getDeviceBinding error: ');
    }
    return null;
  }

  Future<void> updateStoredProfile({
    required String deviceId,
    String? displayName,
    String? email,
    String? phone,
    String? vehicleName,
    String? vehicleVin,
    int? odometerKm,
    String? subscriptionTier,
  }) async {
    try {
      final db = await database;
      final Map<String, dynamic> values = {};
      if (displayName != null) values['display_name'] = displayName;
      if (email != null) values['email'] = email;
      if (phone != null) values['phone'] = phone;
      if (vehicleName != null) values['vehicle_name'] = vehicleName;
      if (vehicleVin != null) values['vehicle_vin'] = vehicleVin;
      if (odometerKm != null) values['odometer_km'] = odometerKm;
      if (subscriptionTier != null) values['subscription_tier'] = subscriptionTier;

      if (values.isNotEmpty) {
        await db.update(
          'user_devices',
          values,
          where: 'device_id = ?',
          whereArgs: [deviceId],
        );
      }
    } catch (e) {
      debugPrint('Database updateStoredProfile error: ');
    }
  }

  // ==========================================
  // Telemetry Logging & FIFO Auto-Pruning Cleaner
  // ==========================================

  Future<void> insertTelemetryPoint({
    required double rpm,
    required double speed,
    required double coolantTemp,
    required double batteryVoltage,
    required double fuelTrim,
    required String triageLevel,
    required double failureProbability,
    int maxRowsToRetain = 5000,
  }) async {
    try {
      final db = await database;
      await db.insert('telemetry_logs', {
        'timestamp': DateTime.now().toIso8601String(),
        'rpm': rpm,
        'speed': speed,
        'coolant_temp': coolantTemp,
        'battery_voltage': batteryVoltage,
        'fuel_trim': fuelTrim,
        'triage_level': triageLevel,
        'failure_probability': failureProbability,
      });

      // Periodic FIFO pruning
      if (DateTime.now().second % 15 == 0) {
        await pruneOldestTelemetry(maxRowsToRetain);
      }
    } catch (e) {
      debugPrint('Database insertTelemetryPoint fallback: ');
    }
  }

  Future<void> pruneOldestTelemetry(int maxRetainedRows) async {
    try {
      final db = await database;
      await db.rawDelete('''
        DELETE FROM telemetry_logs 
        WHERE id NOT IN (
          SELECT id FROM telemetry_logs 
          ORDER BY id DESC 
          LIMIT ?
        )
      ''', [maxRetainedRows]);
    } catch (e) {
      debugPrint('FIFO Pruning error: ');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentTelemetryLogs({int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        'telemetry_logs',
        orderBy: 'id DESC',
        limit: limit,
      );
    } catch (e) {
      debugPrint('Database getRecentTelemetryLogs error: ');
      return [];
    }
  }
}
