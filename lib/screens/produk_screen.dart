import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import 'penjualan_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _produkList = [];

  // ====== AdMob Banner & Interstitial ======
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProduk();
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
      _loadProduk(); // ✅ Refresh otomatis setelah restore database
    }
  }

  Future<void> _loadProduk() async {
    final data = await DatabaseHelper.instance.queryAll("produk");
    if (mounted) {
      setState(() {
        _produkList = data;
      });
    }
  }

  Future<void> _addOrEditProduk({Map<String, dynamic>? produk}) async {
    final namaController = TextEditingController(text: produk?['nama'] ?? '');
    final hargaController =
        TextEditingController(text: produk?['harga']?.toString() ?? '');
    final stokController =
        TextEditingController(text: produk?['stok']?.toString() ?? '');
    final deskripsiController =
        TextEditingController(text: produk?['deskripsi'] ?? '');
    File? imageFile;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage(ImageSource source) async {
              final picked = await ImagePicker().pickImage(source: source);
              if (picked != null) {
                setDialogState(() {
                  imageFile = File(picked.path);
                });
              }
            }

            return AlertDialog(
              title: Text(
                  produk == null ? 'tambah_produk'.tr : 'edit_produk'.tr),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: namaController,
                      decoration: InputDecoration(
                        labelText: 'nama_produk'.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hargaController,
                      decoration: InputDecoration(
                        labelText: 'harga'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stokController,
                      decoration: InputDecoration(
                        labelText: 'stok'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: deskripsiController,
                      decoration: InputDecoration(
                        labelText: 'deskripsi'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    if (imageFile != null)
                      Image.file(imageFile!, height: 100)
                    else if (produk?['gambar_path'] != null)
                      Image.file(File(produk!['gambar_path']), height: 100)
                    else
                      Text('belum_ada_gambar'.tr),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo),
                          label: Text('galeri'.tr),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: Text('kamera'.tr),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('batal'.tr),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (namaController.text.isEmpty ||
                        hargaController.text.isEmpty ||
                        stokController.text.isEmpty) {
                      return;
                    }

                    if (produk == null) {
                      await DatabaseHelper.instance.insertProduk(
                        nama: namaController.text,
                        harga: double.parse(hargaController.text),
                        stok: int.parse(stokController.text),
                        deskripsi: deskripsiController.text,
                        gambarFile: imageFile,
                      );
                    } else {
                      String? gambarPath = produk['gambar_path'];
                      if (imageFile != null) {
                        final filename =
                            "${DateTime.now().millisecondsSinceEpoch}_${imageFile!.path.split('/').last}";
                        gambarPath = await DatabaseHelper.instance
                            .saveImageFile(imageFile!, filename);
                      }

                      final updatedRow = {
                        'id': produk['id'],
                        'nama': namaController.text,
                        'harga': double.parse(hargaController.text),
                        'stok': int.parse(stokController.text),
                        'deskripsi': deskripsiController.text,
                        'gambar_path': gambarPath,
                      };

                      await DatabaseHelper.instance.update(
                        'produk',
                        updatedRow,
                        'id = ?',
                        [produk['id']],
                      );
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadProduk();
                    }
                  },
                  child: Text('simpan'.tr),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduk(int id) async {
    await DatabaseHelper.instance.delete("produk", "id = ?", [id]);
    _loadProduk();
  }

  Future<void> _exportPDF() async {
    _showInterstitial();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text('laporan_daftar_produk'.tr,
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'nama_produk'.tr,
              'harga'.tr,
              'stok'.tr,
              'deskripsi'.tr
            ],
            data: _produkList
                .map((p) => [
                      p['nama'] ?? '',
                      "Rp ${p['harga']}",
                      p['stok'].toString(),
                      p['deskripsi'] ?? ''
                    ])
                .toList(),
          )
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/daftar_produk.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],
        text: 'laporan_daftar_produk'.tr);
  }

  Future<void> _openPenjualan() async {
    _showInterstitial();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PenjualanScreen()),
    );

    if (result == true) {
      _loadProduk();
    }
  }

  void _showImagePreview(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('manajemen_produk'.tr),
        actions: [
          IconButton(
            onPressed: _exportPDF,
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            onPressed: _openPenjualan,
            icon: const Icon(Icons.point_of_sale),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _produkList.isEmpty
                ? Center(child: Text('belum_ada_data'.tr))
                : ListView.builder(
                    itemCount: _produkList.length,
                    itemBuilder: (ctx, i) {
                      final produk = _produkList[i];
                      return Card(
                        child: ListTile(
                          leading: (produk['gambar_path'] != null &&
                                  produk['gambar_path'].toString().isNotEmpty)
                              ? GestureDetector(
                                  onTap: () =>
                                      _showImagePreview(produk['gambar_path']),
                                  child: Image.file(
                                    File(produk['gambar_path']),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.image),
                          title: Text(produk['nama']),
                          subtitle: Text(
                              "Rp ${produk['harga']} | ${'stok'.tr}: ${produk['stok']}\n${produk['deskripsi'] ?? ''}"),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _addOrEditProduk(produk: produk),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () => _deleteProduk(produk['id']),
                                icon: const Icon(Icons.delete),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditProduk(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
