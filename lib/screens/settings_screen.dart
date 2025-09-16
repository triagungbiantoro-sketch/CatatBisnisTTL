import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../db/database_helper.dart';
import 'lang.dart'; // <-- pastikan file lang.dart berisi map terjemahan

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDatabaseChanged;
  const SettingsScreen({super.key, this.onDatabaseChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _currency;
  String? _language;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final settings = await DatabaseHelper.instance.queryAll('pengaturan');
    final Map<String, String> map = {
      for (var s in settings) s['key'] as String: s['value'] as String? ?? ''
    };

    setState(() {
      _currency = map['currency'] ?? 'IDR';
      _language = map['language'] ?? 'id';
      Get.updateLocale(Locale(_language ?? 'id'));
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    final existing = await DatabaseHelper.instance.rawQuery(
      "SELECT * FROM pengaturan WHERE key = ?",
      [key],
    );

    if (existing.isEmpty) {
      await DatabaseHelper.instance.insert('pengaturan', {'key': key, 'value': value});
    } else {
      await DatabaseHelper.instance.update(
        'pengaturan',
        {'value': value},
        'id = ?',
        [existing.first['id']],
      );
    }

    // Jika ganti bahasa, update GetX
    if (key == 'language') {
      Get.updateLocale(Locale(value));
    }
  }

  /// ========== ADS ==========
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-6043960664919055~8946073109'
          : '',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint("Banner gagal: $error");
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-6043960664919055/4042883172'
          : '',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint("Interstitial gagal: $error");
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
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

      if (await File(dbPath).exists()) {
        final dbBytes = await File(dbPath).readAsBytes();
        archive.addFile(ArchiveFile(p.basename(dbPath), dbBytes.length, dbBytes));
      }

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
          content: Text("${'backup_berhasil'.tr}: $backupName\n📂 ${'lokasi'.tr}: $savedPath"),
          duration: const Duration(seconds: 5),
        ),
      );

      _showInterstitial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'gagal_backup'.tr}: $e")),
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

      widget.onDatabaseChanged?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('restore_berhasil'.tr)),
      );

      _showInterstitial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'gagal_restore'.tr}: $e")),
      );
    }
  }

  /// ================= RESET =================
  Future<void> _resetDatabase() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('konfirmasi_reset'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ketik_reset_untuk_hapus'.tr),
            TextField(controller: controller),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('batal'.tr),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.toLowerCase() == "reset"),
            child: Text('ok'.tr),
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

        widget.onDatabaseChanged?.call();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reset_berhasil'.tr)),
        );

        _showInterstitial();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${'gagal_reset'.tr}: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pengaturan'.tr)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: Text('mata_uang'.tr),
                  subtitle: Text(_currency ?? ''),
                  trailing: DropdownButton<String>(
                    value: _currency,
                    items: [
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
                  title: Text('bahasa'.tr),
                  subtitle: Text(_language == 'id' ? "Indonesia" : "English"),
                  trailing: DropdownButton<String>(
                    value: _language,
                    items: [
                      DropdownMenuItem(value: 'id', child: Text("Indonesia")),
                      DropdownMenuItem(value: 'en', child: Text("English")),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _language = val);
                        await _saveSetting('language', val);
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text('manajemen_database'.tr),
                  subtitle:
                      Text("${'backup'.tr}, ${'restore'.tr}, atau ${'reset'.tr}"),
                ),
                OverflowBar(
                  alignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.backup),
                      label: Text('backup'.tr),
                      onPressed: _backupDatabase,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: Text('restore'.tr),
                      onPressed: _restoreDatabase,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: Text('reset'.tr),
                      onPressed: _resetDatabase,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_bannerAd != null)
            Container(
              color: Colors.transparent,
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
