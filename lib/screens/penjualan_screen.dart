import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key});

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> penjualanList = [];
  List<Map<String, dynamic>> produkList = [];

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _initBannerAd();
    _loadInterstitialAd();
  }

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
        _loadInterstitialAd();
      }, onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitialAd();
      });

      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialReady = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final produk = await DatabaseHelper.instance.queryAll('produk');
    final penjualan = await DatabaseHelper.instance.rawQuery('''
      SELECT p.id, p.produk_id, pr.nama AS produk_nama, pr.gambar_path,
             p.jumlah, p.total, p.tanggal
      FROM penjualan p
      LEFT JOIN produk pr ON p.produk_id = pr.id
      ORDER BY p.tanggal DESC
    ''');

    if (mounted) {
      setState(() {
        produkList = produk;
        penjualanList = penjualan;
      });
    }
  }

  Future<void> _showPenjualanForm({Map<String, dynamic>? penjualan}) async {
    if (penjualan == null) _showInterstitial();

    if (produkList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tidak_ada_produk'.tr)),
      );
      return;
    }

    Map<String, dynamic>? selectedProduk;
    TextEditingController produkController =
        TextEditingController(text: penjualan?['produk_nama'] ?? '');
    TextEditingController jumlahController =
        TextEditingController(text: penjualan?['jumlah']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              penjualan == null
                  ? 'tambah_penjualan'.tr
                  : 'edit_penjualan'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ===== Autocomplete modern =====
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable.empty();
                      return produkList.where((p) => (p['nama'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (option) => option['nama'],
                    initialValue: selectedProduk != null
                        ? TextEditingValue(text: selectedProduk!['nama'])
                        : TextEditingValue(text: produkController.text),
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'pilih_produk'.tr,
                          border: const OutlineInputBorder(),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setDialogState(() {
                                      controller.clear();
                                      selectedProduk = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                    onSelected: (selection) {
                      setDialogState(() {
                        selectedProduk = selection;
                        produkController.text = selection['nama'];
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Input jumlah
                  TextField(
                    controller: jumlahController,
                    decoration: InputDecoration(
                      labelText: 'jumlah'.tr,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('batal'.tr)),
              ElevatedButton.icon(
                onPressed: () async {
                  if (selectedProduk == null || jumlahController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('produk_jumlah_wajib'.tr)),
                    );
                    return;
                  }

                  int jumlah = int.tryParse(jumlahController.text) ?? 0;
                  if (jumlah <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('jumlah_lebih_dari_0'.tr)),
                    );
                    return;
                  }

                  final produk = selectedProduk!;
                  if (penjualan == null && produk['stok'] < jumlah) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('stok_tidak_mencukupi'.tr)),
                    );
                    return;
                  }

                  double harga = produk['harga'];
                  double total = harga * jumlah;
                  String tanggal = DateTime.now().toIso8601String();

                  if (penjualan == null) {
                    await DatabaseHelper.instance.insert('penjualan', {
                      'produk_id': produk['id'],
                      'jumlah': jumlah,
                      'total': total,
                      'tanggal': tanggal,
                    });

                    await DatabaseHelper.instance.update(
                      'produk',
                      {'stok': produk['stok'] - jumlah},
                      'id = ?',
                      [produk['id']],
                    );
                  } else {
                    int jumlahLama = penjualan['jumlah'];
                    int selisih = jumlah - jumlahLama;

                    if (produk['stok'] < selisih) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('stok_tidak_mencukupi_update'.tr)),
                      );
                      return;
                    }

                    await DatabaseHelper.instance.update(
                      'penjualan',
                      {
                        'id': penjualan['id'],
                        'produk_id': produk['id'],
                        'jumlah': jumlah,
                        'total': total,
                        'tanggal': penjualan['tanggal'],
                      },
                      'id = ?',
                      [penjualan['id']],
                    );

                    await DatabaseHelper.instance.update(
                      'produk',
                      {'stok': produk['stok'] - selisih},
                      'id = ?',
                      [produk['id']],
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context, true);
                    _loadData();
                  }
                },
                icon: const Icon(Icons.save),
                label: Text('simpan'.tr),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _hapusPenjualan(Map<String, dynamic> penjualan) async {
    final produk = produkList.firstWhere(
        (p) => p['id'] == penjualan['produk_id'],
        orElse: () => {});
    if (produk.isNotEmpty) {
      final newStok = (produk['stok'] as int) + (penjualan['jumlah'] as int);
      await DatabaseHelper.instance.update(
        "produk",
        {'id': produk['id'], 'stok': newStok},
        "id = ?",
        [produk['id']],
      );
    }

    await DatabaseHelper.instance
        .delete('penjualan', 'id = ?', [penjualan['id']]);
    _loadData();
  }

  Future<void> _exportPDF({bool bulanan = false}) async {
    _showInterstitial();

    final pdf = pw.Document();
    final now = DateTime.now();

    List<Map<String, dynamic>> filtered = penjualanList.where((p) {
      final tanggal = DateTime.parse(p['tanggal']);
      if (bulanan) {
        return tanggal.month == now.month && tanggal.year == now.year;
      } else {
        return tanggal.day == now.day &&
            tanggal.month == now.month &&
            tanggal.year == now.year;
      }
    }).toList();

    double totalAll =
        filtered.fold(0.0, (sum, p) => sum + (p['total'] as double));

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Center(
              child: pw.Text(
                  bulanan
                      ? 'laporan_penjualan_bulanan'.tr
                      : 'laporan_penjualan_harian'.tr,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'tanggal'.tr,
              'produk'.tr,
              'jumlah'.tr,
              'total'.tr
            ],
            data: filtered
                .map((p) => [
                      DateFormat('dd/MM/yyyy')
                          .format(DateTime.parse(p['tanggal'])),
                      p['produk_nama'] ?? '',
                      p['jumlah'].toString(),
                      "Rp ${p['total']}"
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text("${'total_penjualan'.tr}: Rp $totalAll",
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file =
        File("${dir.path}/laporan_${bulanan ? 'bulanan' : 'harian'}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],
        text: bulanan
            ? 'laporan_penjualan_bulanan'.tr
            : 'laporan_penjualan_harian'.tr);
  }

  Widget _buildThumbnail(String? path) {
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2, size: 30, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('penjualan'.tr),
        actions: [
          IconButton(
              onPressed: () => _exportPDF(bulanan: false),
              icon: const Icon(Icons.picture_as_pdf)),
          IconButton(
              onPressed: () => _exportPDF(bulanan: true),
              icon: const Icon(Icons.calendar_month)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPenjualanForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: penjualanList.isEmpty
                ? Center(
                    child: Text(
                      'belum_ada_penjualan'.tr,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  )
                : ListView.builder(
                    itemCount: penjualanList.length,
                    itemBuilder: (context, index) {
                      final penjualan = penjualanList[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: _buildThumbnail(penjualan['gambar_path']),
                          title: Text(
                            penjualan['produk_nama'] ??
                                'produk_tidak_ditemukan'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'jumlah'.tr}: ${penjualan['jumlah']}'),
                              Text(
                                '${'total'.tr}: Rp ${penjualan['total'].toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.green),
                              ),
                              Text(
                                '${'tanggal'.tr}: ${penjualan['tanggal']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showPenjualanForm(penjualan: penjualan),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _hapusPenjualan(penjualan),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
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
}
