import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:path/path.dart' as path;
import '../models/item.dart';

// Conditional import for FFI
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static dynamic _database;

  DatabaseHelper._init() {
    //  if not on web
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ffi.sqfliteFfiInit();
      mobile.databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  Future<dynamic> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory.db');
    return _database!;
  }

  Future<dynamic> _initDB(String filePath) async {
    if (kIsWeb) {
      // For web, return a mock database
      return _createWebMockDB();
    } else {
      // For mobile/desktop
      final dbPath = await mobile.getDatabasesPath();
      final db = path.join(dbPath, filePath);

      return await mobile.openDatabase(
        db,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  // Simple mock database for web
  dynamic _createWebMockDB() {
    return {
      'items': [],
      'insert': (String table, Map<String, dynamic> values) async {
        final items = _database['items'] as List;
        final id = items.length + 1;
        items.add({...values, 'id': id});
        return id;
      },
      'query': (String table, {String? orderBy}) async {
        final items = _database['items'] as List;
        if (orderBy != null) {
          items.sort((a, b) => (a[orderBy] as String).compareTo(b[orderBy] as String));
        }
        return items;
      },
      'update': (String table, Map<String, dynamic> values,
          {String? where, List<Object?>? whereArgs}) async {
        final items = _database['items'] as List;
        final id = values['id'];
        final index = items.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          items[index] = values;
          return 1;
        }
        return 0;
      },
      'delete': (String table, {String? where, List<Object?>? whereArgs}) async {
        final items = _database['items'] as List;
        final id = whereArgs?.first;
        final initialLength = items.length;
        items.removeWhere((item) => item['id'] == id);
        return initialLength - items.length;
      },
      // ADD THIS for web mock
      'deleteAll': (String table) async {
        final items = _database['items'] as List;
        final count = items.length;
        items.clear();
        return count;
      },
      'close': () async {
        // Nothing to close for web mock
      },
    };
  }

  Future _createDB(dynamic db, int version) async {
    if (kIsWeb) return; // No table creation on web mock

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // CRUD Operations - updated to work with both real and mock DB
  Future<int> createItem(Item item) async {
    final db = await database;
    if (kIsWeb) {
      return await db['insert']('items', item.toMap());
    } else {
      return await db.insert('items', item.toMap());
    }
  }

  Future<List<Item>> getAllItems() async {
    try {
      final db = await database;
      dynamic result;

      if (kIsWeb) {
        result = await db['query']('items', orderBy: 'name');
      } else {
        result = await db.query('items', orderBy: 'name');
      }

      return result.map<Item>((map) => Item.fromMap(Map<String, dynamic>.from(map))).toList();
    } catch (e) {
      print('Error in getAllItems: $e');
      return [];
    }
  }

  Future<Item?> getItem(int id) async {
    final items = await getAllItems();
    return items.firstWhere((item) => item.id == id);
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    if (kIsWeb) {
      return await db['update']('items', item.toMap(),
          where: 'id = ?', whereArgs: [item.id]);
    } else {
      return await db.update(
        'items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    if (kIsWeb) {
      return await db['delete']('items', where: 'id = ?', whereArgs: [id]);
    } else {
      return await db.delete(
        'items',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ADD THIS NEW METHOD - Delete all items
  Future<int> deleteAllItems() async {
    final db = await database;
    if (kIsWeb) {
      return await db['deleteAll']('items');
    } else {
      return await db.delete('items'); // No where clause = delete all
    }
  }

  Future<void> close() async {
    final db = await database;
    if (kIsWeb) {
      await db['close']();
    } else {
      db.close();
    }
  }
}