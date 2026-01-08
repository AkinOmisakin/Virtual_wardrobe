import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:virtual_wardrobe/components/imageclass_.dart';

class DBHelper {
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('images.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, fileName);
    return await openDatabase(dbPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertImage(ImageItem item) async {
    final db = await database;
    return await db.insert('images', item.toMap());
  }

  Future<List<ImageItem>> getAllImages() async {
    final db = await database;
    final rows = await db.query('images', orderBy: 'id DESC');
    return rows.map((r) => ImageItem.fromMap(r)).toList();
  }

  Future<int> deleteImage(int id) async {
    final db = await database;
    return await db.delete('images', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}