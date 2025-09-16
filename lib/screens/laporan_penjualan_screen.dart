import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class LaporanPenjualanPdfScreen extends StatefulWidget {
  const LaporanPenjualanPdfScreen({super.key});

  @override
  State<LaporanPenjualanPdfScreen> createState() =>
      _LaporanPenjualanPdfScreenState();
}

class _LaporanPenjualanPdfScreenState
    extends State<LaporanPenjualanPdfScreen> {
  List<Map<String, dynamic>> laporan = [];
  String filter = "harian"; // harian, bulanan, tahunan, custom
  DateTimeRange? customRange;

  // ====== AdMob Banner & Interstitial ======
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    _loadLaporan();
    _initBannerAd();
    _loadInterstitialAd();
  }

  // ================ Banner =================
  void _initBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-6043960664919055~8946073109',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {}),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('Banner gagal dimuat: $err');
        },
      ),
    )..load();
  }

  // ================ Interstitial ================
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-6043960664919055/4042883172',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial gagal dimuat: $err');
          _isInterstitialReady = false;
        },
      ),
    );
  }

  void _showInterstitial() {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitialAd(); // reload untuk penggunaan berikutnya
      }, onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitialAd();
      });

      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialReady = false;
    }
  }

  Future<void> _loadLaporan() async {
    DateTime now = DateTime.now();
    String where = "";
    List<dynamic> whereArgs = [];

    if (filter == "harian") {
      String today = DateFormat('yyyy-MM-dd').format(now);
      where = "DATE(p.tanggal) = ?";
      whereArgs = [today];
    } else if (filter == "bulanan") {
      String month = DateFormat('yyyy-MM').format(now);
      where = "strftime('%Y-%m', p.tanggal) = ?";
      whereArgs = [month];
    } else if (filter == "tahunan") {
      String year = DateFormat('yyyy').format(now);
      where = "strftime('%Y', p.tanggal) = ?";
      whereArgs = [year];
    } else if (filter == "custom" && customRange != null) {
      String start = DateFormat('yyyy-MM-dd').format(customRange!.start);
      String end = DateFormat('yyyy-MM-dd').format(customRange!.end);
      where = "DATE(p.tanggal) BETWEEN ? AND ?";
      whereArgs = [start, end];
    }

    final result = await DatabaseHelper.instance.rawQuery('''
      SELECT p.id, p.produk_id, pr.nama AS produk_nama, 
             p.jumlah, p.total, p.tanggal
      FROM penjualan p
      LEFT JOIN produk pr ON p.produk_id = pr.id
      ${where.isNotEmpty ? 'WHERE $where' : ''}
      ORDER BY p.tanggal DESC
    ''', whereArgs);

    setState(() {
      laporan = result;
    });
  }

  Future<void> _exportPDF() async {
    // Tampilkan interstitial saat export PDF
    _showInterstitial();

    final pdf = pw.Document();
    double totalSemua =
        laporan.fold(0, (sum, item) => sum + (item['total'] as num));

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("laporan_penjualan".tr,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              "nama_produk".tr,
              "jumlah".tr,
              "total_penjualan".tr,
              "tanggal".tr
            ],
            data: laporan.map((item) {
              return [
                item['produk_nama'] ?? "Produk",
                item['jumlah'].toString(),
                "Rp ${item['total']}",
                item['tanggal']
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text("${'total_penjualan'.tr}: Rp $totalSemua",
              style: pw.TextStyle(fontSize: 16)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/laporan_penjualan.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],
        text: "${'laporan_penjualan'.tr} (${filter.toUpperCase()})");
  }

  Future<void> _pickCustomRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customRange,
    );

    if (picked != null) {
      setState(() {
        filter = "custom";
        customRange = picked;
      });
      _loadLaporan();
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalSemua =
        laporan.fold(0, (sum, item) => sum + (item['total'] as num));

    return Scaffold(
      appBar: AppBar(
        title: Text("laporan_penjualan".tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPDF,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔽 Filter Dropdown
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: filter,
              items: [
                DropdownMenuItem(value: "harian", child: Text("filter_harian".tr)),
                DropdownMenuItem(value: "bulanan", child: Text("filter_bulanan".tr)),
                DropdownMenuItem(value: "tahunan", child: Text("filter_tahunan".tr)),
                DropdownMenuItem(value: "custom", child: Text("filter_custom".tr)),
              ],
              onChanged: (val) {
                if (val == "custom") {
                  _pickCustomRange();
                } else {
                  setState(() {
                    filter = val!;
                  });
                  _loadLaporan();
                }
              },
            ),
          ),
          // 🔽 List Penjualan
          Expanded(
            child: laporan.isEmpty
                ? Center(child: Text("tidak_ada_data_penjualan".tr))
                : ListView.builder(
                    itemCount: laporan.length,
                    itemBuilder: (context, index) {
                      final item = laporan[index];
                      return ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: Text(item['produk_nama'] ?? "Produk"),
                        subtitle: Text(
                            "${'jumlah'.tr}: ${item['jumlah']} | Rp ${item['total']}"),
                        trailing: Text(item['tanggal']),
                      );
                    },
                  ),
          ),
          // 🔽 Total Penjualan
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("total_penjualan".tr,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Rp $totalSemua",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // 🔽 Banner Ad
          if (_bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
