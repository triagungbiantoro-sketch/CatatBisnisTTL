import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDatabaseChanged; // callback untuk update UI setelah restore/reset
  const SettingsScreen({super.key, this.onDatabaseChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _currency;
  String? _language;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final settings = await DatabaseHelper.instance.queryAll('pengaturan');
    final Map<String, String> map = {
      for (var s in settings) s['key'] as String: s['value'] as String? ?? ''
    };

    setState(() {
      _currency = map['currency'] ?? 'IDR';
      _language = map['language'] ?? 'id';
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    final existing = await DatabaseHelper.instance.rawQuery(
      "SELECT * FROM pengaturan WHERE key = ?",
      [key],
    );

    if (existing.isEmpty) {
      await DatabaseHelper.instance.insert('pengaturan', {
        'key': key,
        'value': value,
      });
    } else {
      await DatabaseHelper.instance.update(
        'pengaturan',
        {'value': value},
        'id = ?',
        [existing.first['id']],
      );
    }
  }

  /// ================= BACKUP =================
  Future<void> _backupDatabase() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      final dbPath = db.path;
      final imageDir = await dbHelper.getImagesDirectory();

      final archive = Archive();

      // Backup database
      if (await File(dbPath).exists()) {
        final dbBytes = await File(dbPath).readAsBytes();
        archive.addFile(ArchiveFile(p.basename(dbPath), dbBytes.length, dbBytes));
      }

      // Backup folder images
      if (await imageDir.exists()) {
        for (var file in imageDir.listSync(recursive: true)) {
          if (file is File) {
            final relativePath = p.relative(file.path, from: imageDir.parent.path);
            final fileBytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
          }
        }
      }

      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);
      if (zipData == null) throw Exception("Gagal membuat ZIP");

      final bytes = Uint8List.fromList(zipData);
      final backupName =
          "backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.zip";

      final savedPath = await FileSaver.instance.saveFile(
        name: backupName,
        bytes: bytes,
        ext: "zip",
        mimeType: MimeType.zip,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Backup berhasil: $backupName\n📂 Lokasi: $savedPath"),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Gagal backup: $e")),
      );
    }
  }

  /// ================= RESTORE =================
  Future<void> _restoreDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null) return;

      final zipFile = File(result.files.single.path!);
      final dbHelper = DatabaseHelper.instance;

      await dbHelper.resetDatabaseInstance();
      final dbPath = (await dbHelper.database).path;
      final imageDir = await dbHelper.getImagesDirectory();

      if (await File(dbPath).exists()) await File(dbPath).delete();
      if (await imageDir.exists()) await imageDir.delete(recursive: true);

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final outFilePath = file.name == p.basename(dbPath)
              ? dbPath
              : p.join(imageDir.path, file.name);
          final outFile = File(outFilePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          final dirPath = p.join(imageDir.path, file.name);
          await Directory(dirPath).create(recursive: true);
        }
      }

      await dbHelper.resetDatabaseInstance();
      await dbHelper.database;

      widget.onDatabaseChanged?.call(); // auto-refresh UI

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Restore database berhasil")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Gagal restore: $e")),
      );
    }
  }

  /// ================= RESET =================
  Future<void> _resetDatabase() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Reset"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ketik 'reset' untuk menghapus semua data."),
            TextField(controller: controller),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.toLowerCase() == "reset"),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dbHelper = DatabaseHelper.instance;

        await dbHelper.resetDatabaseInstance();
        final dbPath = (await dbHelper.database).path;
        final imageDir = await dbHelper.getImagesDirectory();

        if (await File(dbPath).exists()) await File(dbPath).delete();
        if (await imageDir.exists()) await imageDir.delete(recursive: true);

        await dbHelper.resetDatabaseInstance();
        await dbHelper.database;

        widget.onDatabaseChanged?.call(); // auto-refresh UI

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Database berhasil direset")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Gagal reset: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text("Mata Uang"),
            subtitle: Text(_currency ?? ''),
            trailing: DropdownButton<String>(
              value: _currency,
              items: const [
                DropdownMenuItem(value: 'IDR', child: Text("Rupiah (IDR)")),
                DropdownMenuItem(value: 'USD', child: Text("Dollar (USD)")),
                DropdownMenuItem(value: 'EUR', child: Text("Euro (EUR)")),
              ],
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _currency = val);
                  await _saveSetting('currency', val);
                  widget.onDatabaseChanged?.call();
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("Bahasa"),
            subtitle: Text(_language == 'id' ? "Indonesia" : "English"),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'id', child: Text("Indonesia")),
                DropdownMenuItem(value: 'en', child: Text("English")),
              ],
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _language = val);
                  await _saveSetting('language', val);
                  widget.onDatabaseChanged?.call();
                }
              },
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text("Manajemen Database"),
            subtitle: Text("Backup, restore, atau reset database"),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text("Backup"),
                onPressed: _backupDatabase,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text("Restore"),
                onPressed: _restoreDatabase,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text("Reset"),
                onPressed: _resetDatabase,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
