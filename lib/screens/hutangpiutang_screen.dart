import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';
import '../db/database_helper.dart';

class HutangPiutangScreen extends StatefulWidget {
  const HutangPiutangScreen({super.key});

  @override
  State<HutangPiutangScreen> createState() => _HutangPiutangScreenState();
}

class _HutangPiutangScreenState extends State<HutangPiutangScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // ===== AdMob Banner & Interstitial =====
  late BannerAd _bannerAd;
  bool _bannerLoaded = false;

  InterstitialAd? _interstitialAd;
  int _interstitialLoadCount = 0; // kontrol frekuensi

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _loadBannerAd();
    _loadInterstitial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // ================= AdMob ==================
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-6043960664919055~8946073109',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _bannerLoaded = true;
          });
        },
        onAdFailedToLoad: (_, err) {
          _bannerLoaded = false;
        },
      ),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-6043960664919055/4042883172',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitial() {
    if (_interstitialAd != null && _interstitialLoadCount == 0) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      }, onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitial();
      });

      _interstitialAd!.show();
      _interstitialLoadCount++;
    }
  }

  // ==========================================

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance.getHutangPiutang();
    setState(() {
      _data = rows;
      _loading = false;
    });
  }

  Future<void> _tambahAtauEdit(
      {Map<String, dynamic>? item, String? defaultTipe}) async {
    final formKey = GlobalKey<FormState>();
    final tipeCtrl = TextEditingController(
      text: item?['tipe'] ?? defaultTipe ?? 'hutang',
    );
    final namaCtrl = TextEditingController(text: item?['nama'] ?? '');
    final jumlahCtrl =
        TextEditingController(text: item?['jumlah']?.toString() ?? '');
    final tanggalCtrl = TextEditingController(
        text: item?['tanggal'] ??
            DateTime.now().toIso8601String().split('T').first);
    final jatuhTempoCtrl =
        TextEditingController(text: item?['jatuh_tempo'] ?? '');
    final keteranganCtrl =
        TextEditingController(text: item?['keterangan'] ?? '');
    String status = item?['status'] ?? 'belum_lunas';
    String? fotoPath = item?['foto'];

    Future<void> _pickImage(ImageSource source) async {
      final picked = await _picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        setState(() {
          fotoPath = picked.path;
        });
      }
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(item == null
              ? 'tambah_hutang_piutang'.tr
              : 'edit'.tr + " ${'hutang_piutang'.tr}"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: tipeCtrl.text,
                    decoration: InputDecoration(labelText: 'hutang'.tr),
                    items: [
                      DropdownMenuItem(
                          value: "hutang",
                          child: Text("hutang".tr + " (toko → supplier)")),
                      DropdownMenuItem(
                          value: "piutang",
                          child: Text("piutang".tr + " (pelanggan → toko)")),
                    ],
                    onChanged: (val) => tipeCtrl.text = val!,
                  ),
                  TextFormField(
                    controller: namaCtrl,
                    decoration: InputDecoration(
                        labelText: 'nama'.tr + " ${'supplier/pelanggan'.tr}"),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'wajib_diisi'.tr : null,
                  ),
                  TextFormField(
                    controller: jumlahCtrl,
                    decoration:
                        InputDecoration(labelText: 'jumlah'.tr),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'wajib_diisi'.tr : null,
                  ),
                  TextFormField(
                    controller: tanggalCtrl,
                    decoration:
                        InputDecoration(labelText: 'tanggal'.tr),
                  ),
                  TextFormField(
                    controller: jatuhTempoCtrl,
                    decoration:
                        InputDecoration(labelText: 'jatuh_tempo'.tr),
                  ),
                  TextFormField(
                    controller: keteranganCtrl,
                    decoration: InputDecoration(labelText: 'keterangan'.tr),
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(labelText: 'status'.tr),
                    items: [
                      DropdownMenuItem(
                          value: "belum_lunas", child: Text('belum_lunas'.tr)),
                      DropdownMenuItem(
                          value: "lunas", child: Text('lunas'.tr)),
                    ],
                    onChanged: (val) => status = val!,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera)
                            .then((_) => setStateDialog(() {})),
                        icon: const Icon(Icons.camera_alt),
                        label: Text('kamera'.tr),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery)
                            .then((_) => setStateDialog(() {})),
                        icon: const Icon(Icons.photo),
                        label: Text('galeri'.tr),
                      ),
                    ],
                  ),
                  if (fotoPath != null && File(fotoPath!).existsSync()) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openFullImage(fotoPath!),
                      child: Image.file(File(fotoPath!), height: 100),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('batal'.tr)),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final double jumlahParsed =
                      double.tryParse(jumlahCtrl.text) ?? 0.0;

                  final row = {
                    'tipe': tipeCtrl.text,
                    'nama': namaCtrl.text,
                    'jumlah': jumlahParsed,
                    'tanggal': tanggalCtrl.text,
                    'jatuh_tempo': jatuhTempoCtrl.text.isEmpty
                        ? null
                        : jatuhTempoCtrl.text,
                    'status': status,
                    'keterangan': keteranganCtrl.text,
                    'foto': fotoPath,
                  };

                  if (item == null) {
                    await DatabaseHelper.instance
                        .insert('hutang_piutang', row);
                  } else {
                    await DatabaseHelper.instance.update(
                      'hutang_piutang',
                      row,
                      "id = ?",
                      [item['id']],
                    );
                  }

                  Navigator.pop(context);
                  _loadData();

                  // tampilkan interstitial setelah save
                  _showInterstitial();
                }
              },
              child: Text('simpan'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tandaiLunas(Map<String, dynamic> item) async {
    await DatabaseHelper.instance
        .updateStatusHutangPiutang(item['id'], 'lunas');
    _loadData();
  }

  Future<void> _hapus(int id) async {
    await DatabaseHelper.instance.deleteHutangPiutang(id);
    _loadData();
  }

  void _openFullImage(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(File(path)),
            ),
          ),
        ),
      ),
    );
  }

  // 📤 Share PDF per item
  Future<void> _shareAsPdf(Map<String, dynamic> item) async {
    try {
      final pdf = pw.Document();

      Uint8List? imageBytes;
      if (item['foto'] != null) {
        final f = File(item['foto']);
        if (f.existsSync()) imageBytes = await f.readAsBytes();
      }

      final imageProvider =
          imageBytes != null ? pw.MemoryImage(imageBytes) : null;

      pdf.addPage(pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('hutang_piutang'.tr,
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text("${'hutang'.tr}: ${item['tipe']}"),
            pw.Text("${'nama'.tr}: ${item['nama']}"),
            pw.Text("${'jumlah'.tr}: Rp${item['jumlah']}"),
            pw.Text("${'tanggal'.tr}: ${item['tanggal']}"),
            pw.Text("${'jatuh_tempo'.tr}: ${item['jatuh_tempo'] ?? '-'}"),
            pw.Text("${'status'.tr}: ${item['status']}"),
            pw.Text("${'keterangan'.tr}: ${item['keterangan'] ?? '-'}"),
            if (imageProvider != null) ...[
              pw.SizedBox(height: 20),
              pw.Image(imageProvider, width: 200),
            ],
          ],
        ),
      ));

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/hutang_piutang_${item['id']}.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: "Data ${'hutang_piutang'.tr}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal export/share PDF: $e")),
      );
    }
  }

  // 📤 Share PDF seluruh data
  Future<void> _shareAllAsPdf() async {
    try {
      if (_data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('belum_ada_data'.tr)));
        return;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context ctx) => [
            pw.Text('laporan_hutang_piutang'.tr,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            ..._data.map((item) {
              pw.ImageProvider? imageProvider;
              if (item['foto'] != null) {
                final f = File(item['foto']);
                if (f.existsSync()) {
                  imageProvider = pw.MemoryImage(f.readAsBytesSync());
                }
              }
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      "${item['tipe'].toUpperCase()} - ${item['nama']} (Rp${item['jumlah']})",
                      style: pw.TextStyle(fontSize: 14)),
                  pw.Text("${'tanggal'.tr}: ${item['tanggal']}"),
                  pw.Text("${'jatuh_tempo'.tr}: ${item['jatuh_tempo'] ?? '-'}"),
                  pw.Text("${'status'.tr}: ${item['status']}"),
                  pw.Text("${'keterangan'.tr}: ${item['keterangan'] ?? '-'}"),
                  if (imageProvider != null) ...[
                    pw.SizedBox(height: 10),
                    pw.Image(imageProvider, width: 200),
                  ],
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/laporan_hutang_piutang.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: 'laporan_hutang_piutang'.tr);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal export semua: $e")),
      );
    }
  }

  Widget _buildList(String tipe) {
    final list = _data.where((e) => e['tipe'] == tipe).toList();

    if (list.isEmpty) return Center(child: Text('belum_ada_data'.tr));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final bool isLunas = item['status'] == 'lunas';
        final Color badgeColor = isLunas ? Colors.green : Colors.red;
        final String badgeText =
            isLunas ? 'lunas'.tr + " ✔" : 'belum_lunas'.tr + " ✖";

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: item['foto'] != null &&
                          File(item['foto']).existsSync()
                      ? GestureDetector(
                          onTap: () => _openFullImage(item['foto']),
                          child: Image.file(
                            File(item['foto']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          tipe == 'hutang'
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: tipe == 'hutang' ? Colors.red : Colors.green,
                        ),
                  title: Text("${item['nama']} - Rp${item['jumlah']}"),
                  subtitle: Text(
                    "${'tanggal'.tr}: ${item['tanggal']} | ${'jatuh_tempo'.tr}: ${item['jatuh_tempo'] ?? '-'}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Colors.blue),
                        tooltip: 'export_pdf'.tr,
                        onPressed: () => _shareAsPdf(item),
                      ),
                      if (!isLunas)
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          tooltip: 'lunas'.tr,
                          onPressed: () => _tandaiLunas(item),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _tambahAtauEdit(item: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _hapus(item['id']),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12, bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      border: Border.all(color: badgeColor, width: 1.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('laporan_hutang_piutang'.tr),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.grey,
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color.fromARGB(255, 35, 64, 226),
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'hutang'.tr),
                  Tab(text: 'piutang'.tr),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'export_pdf'.tr,
              onPressed: _shareAllAsPdf,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList('hutang'),
                        _buildList('piutang'),
                      ],
                    ),
            ),
            if (_bannerLoaded)
              SizedBox(
                height: _bannerAd.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd),
              ),
          ],
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isHutang = _tabController.index == 0;
            return FloatingActionButton(
              backgroundColor: isHutang ? Colors.red : Colors.green,
              onPressed: () => _tambahAtauEdit(
                  defaultTipe: isHutang ? "hutang" : "piutang"),
              child: const Icon(Icons.add, color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}
