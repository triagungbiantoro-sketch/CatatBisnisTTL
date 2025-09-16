import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// ====== Getter Database ======
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3, // dinaikkan ke 3 karena ada kolom foto
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE produk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        harga REAL NOT NULL,
        stok INTEGER NOT NULL,
        deskripsi TEXT,
        gambar_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE penjualan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produk_id INTEGER NOT NULL,
        jumlah INTEGER NOT NULL,
        total REAL NOT NULL,
        tanggal TEXT NOT NULL,
        FOREIGN KEY (produk_id) REFERENCES produk(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE laporan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        total_penjualan REAL,
        keterangan TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE info_toko (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_toko TEXT NOT NULL,
        alamat TEXT,
        telepon TEXT,
        email TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pengaturan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE hutang_piutang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipe TEXT NOT NULL,            -- hutang / piutang
        nama TEXT NOT NULL,            -- nama supplier / pelanggan
        jumlah REAL NOT NULL,
        tanggal TEXT NOT NULL,
        jatuh_tempo TEXT,
        status TEXT NOT NULL DEFAULT 'belum_lunas', -- belum_lunas / lunas
        keterangan TEXT,
        foto TEXT                       -- path foto (opsional)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE hutang_piutang (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tipe TEXT NOT NULL,
          nama TEXT NOT NULL,
          jumlah REAL NOT NULL,
          tanggal TEXT NOT NULL,
          jatuh_tempo TEXT,
          status TEXT NOT NULL DEFAULT 'belum_lunas',
          keterangan TEXT,
          foto TEXT
        )
      ''');
    } else if (oldVersion < 3) {
      // tambahkan kolom foto jika belum ada
      await db.execute("ALTER TABLE hutang_piutang ADD COLUMN foto TEXT");
    }
  }

  /// ====== CRUD Umum ======
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, row);
  }

  Future<int> update(String table, Map<String, dynamic> row, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future close() async {
    final db = await database;
    await db.close();
  }

  /// ====== Reset Database Instance ======
  Future<void> resetDatabaseInstance() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// ====== Restore Database dari File ======
  Future<void> restoreDatabase(File dbFile) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'app_database.db');

    await resetDatabaseInstance();
    await dbFile.copy(path);
    _database = await openDatabase(path);
  }

  /// ====== Folder Gambar ======
  Future<Directory> getImagesDirectory() async {
    final picturesDir = await getExternalStorageDirectories(type: StorageDirectory.pictures);
    final baseDir = picturesDir!.first;
    final appDir = Directory(p.join(baseDir.path, "MyApp"));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  Future<String> saveImageFile(File imageFile, String filename) async {
    final dir = await getImagesDirectory();
    final newPath = p.join(dir.path, filename);
    final newImage = await imageFile.copy(newPath);
    return newImage.path;
  }

  /// ====== Insert Produk dengan Gambar ======
  Future<int> insertProduk({
    required String nama,
    required double harga,
    required int stok,
    String? deskripsi,
    File? gambarFile,
  }) async {
    String? gambarPath;
    if (gambarFile != null) {
      final filename = "${DateTime.now().millisecondsSinceEpoch}_${p.basename(gambarFile.path)}";
      gambarPath = await saveImageFile(gambarFile, filename);
    }

    final row = {
      'nama': nama,
      'harga': harga,
      'stok': stok,
      'deskripsi': deskripsi,
      'gambar_path': gambarPath,
    };

    return await insert('produk', row);
  }

  /// ====== CRUD Hutang Piutang ======
  Future<int> insertHutangPiutang({
    required String tipe, // hutang/piutang
    required String nama,
    required double jumlah,
    required String tanggal,
    String? jatuhTempo,
    String status = "belum_lunas",
    String? keterangan,
    File? fotoFile,
  }) async {
    String? fotoPath;
    if (fotoFile != null) {
      final filename = "${DateTime.now().millisecondsSinceEpoch}_${p.basename(fotoFile.path)}";
      fotoPath = await saveImageFile(fotoFile, filename);
    }

    final row = {
      'tipe': tipe,
      'nama': nama,
      'jumlah': jumlah,
      'tanggal': tanggal,
      'jatuh_tempo': jatuhTempo,
      'status': status,
      'keterangan': keterangan,
      'foto': fotoPath,
    };
    return await insert('hutang_piutang', row);
  }

  Future<List<Map<String, dynamic>>> getHutangPiutang({String? tipe, String? status}) async {
    final db = await database;
    String? where;
    List<String> whereArgs = [];

    if (tipe != null) {
      where = (where == null ? '' : '$where AND ') + 'tipe = ?';
      whereArgs.add(tipe);
    }
    if (status != null) {
      where = (where == null ? '' : '$where AND ') + 'status = ?';
      whereArgs.add(status);
    }

    return await db.query('hutang_piutang', where: where, whereArgs: whereArgs);
  }

  Future<int> updateStatusHutangPiutang(int id, String status) async {
    final db = await database;
    return await db.update(
      'hutang_piutang',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateHutangPiutang(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'hutang_piutang',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteHutangPiutang(int id) async {
    final db = await database;
    return await db.delete('hutang_piutang', where: 'id = ?', whereArgs: [id]);
  }
}
