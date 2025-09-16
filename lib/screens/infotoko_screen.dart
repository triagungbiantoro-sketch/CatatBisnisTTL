import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class InfoTokoScreen extends StatefulWidget {
  const InfoTokoScreen({super.key});

  @override
  State<InfoTokoScreen> createState() => _InfoTokoScreenState();
}

class _InfoTokoScreenState extends State<InfoTokoScreen> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final alamatController = TextEditingController();
  final teleponController = TextEditingController();
  final emailController = TextEditingController();

  Map<String, dynamic>? tokoData;
  bool _loading = true; // indikator loading awal

  // ===== AdMob Banner & Interstitial =====
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    _loadInfoToko();
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

  Future<void> _loadInfoToko() async {
    final data = await DatabaseHelper.instance.queryAll('info_toko');
    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          tokoData = data.first;
          namaController.text = tokoData?['nama_toko'] ?? '';
          alamatController.text = tokoData?['alamat'] ?? '';
          teleponController.text = tokoData?['telepon'] ?? '';
          emailController.text = tokoData?['email'] ?? '';
        }
        _loading = false; // selesai loading
      });
    }
  }

  Future<void> _saveInfoToko() async {
    if (!_formKey.currentState!.validate()) return;

    final row = {
      'nama_toko': namaController.text,
      'alamat': alamatController.text,
      'telepon': teleponController.text,
      'email': emailController.text,
    };

    if (tokoData == null) {
      final id = await DatabaseHelper.instance.insert('info_toko', row);
      tokoData = {'id': id, ...row};
    } else {
      await DatabaseHelper.instance.update(
        'info_toko',
        row,
        'id = ?',
        [tokoData!['id']],
      );
      tokoData = {'id': tokoData!['id'], ...row};
    }

    // Tampilkan interstitial saat menyimpan info toko
    _showInterstitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('info_toko_berhasil_disimpan'.tr)),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('info_toko'.tr),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          TextFormField(
                            controller: namaController,
                            decoration: InputDecoration(
                              labelText: 'nama_toko'.tr,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'nama_toko_wajib_diisi'.tr
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: alamatController,
                            decoration: InputDecoration(
                              labelText: 'alamat'.tr,
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: teleponController,
                            decoration: InputDecoration(
                              labelText: 'telepon'.tr,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'email'.tr,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final regex =
                                    RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                if (!regex.hasMatch(value)) {
                                  return 'format_email_tidak_valid'.tr;
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saveInfoToko,
                            child: Text('simpan'.tr),
                          ),
                        ],
                      ),
                    ),
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
    namaController.dispose();
    alamatController.dispose();
    teleponController.dispose();
    emailController.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
