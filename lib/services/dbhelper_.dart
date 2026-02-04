// import 'package:path/path.dart' as p;
// import 'package:sqflite/sqflite.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:virtual_wardrobe/components/clothing_item.dart';

// class WardrobeDatabase {
//   WardrobeDatabase._privateConstructor();
//   static final WardrobeDatabase instance = WardrobeDatabase._privateConstructor();
//   static Database? _database;

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB('images.db');
//     return _database!;
//   }

//   Future<Database> _initDB(String fileName) async {
//     final docs = await getApplicationDocumentsDirectory();
//     final dbPath = p.join(docs.path, fileName);
//     return await openDatabase(
//       dbPath,
//       version: 2,
//       onCreate: _createDB,
//       onOpen: (db) async {
//         // ensure any newly added columns exist (safe on existing DBs)
//         await _ensureColumn(db, 'images', 'type', 'INTEGER NOT NULL DEFAULT 0');
//         await _ensureColumn(db, 'images', 'description', 'TEXT');
//       },
//     );
//   }

//   Future _createDB(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE images (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         path TEXT NOT NULL,
//         type INTEGER NOT NULL,
//         createdAt TEXT NOT NULL,
//         description TEXT
//       )
//     ''');
//   }

//   Future<void> _ensureColumn(Database db, String table, String column, String definition) async {
//     final info = await db.rawQuery("PRAGMA table_info($table)");
//     final exists = info.any((row) => row['name'] == column);
//     if (!exists) {
//       await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
//     }
//   }

//   // INSERT
//   Future<int> insertImage(ClothingItem item) async {
//     final db = await database;
//     return await db.insert(
//       'images',
//       item.toMap(),
//     );
//   }

//   // FETCH ALL
//   Future<List<ClothingItem>> getAllImages() async {
//     final db = await database;
//     final rows = await db.query('images', orderBy: 'id DESC');
//     return rows.map((r) => ClothingItem.fromMap(r)).toList();
//   }

//   // DELETE
//   Future<int> deleteImage(int id) async {
//     final db = await database;
//     return await db.delete('images', where: 'id = ?', whereArgs: [id]);
//   }
  
  
//   Future close() async {
//     final db = await database;
//     await db.close();
//     _database = null;
//   }

  
// }