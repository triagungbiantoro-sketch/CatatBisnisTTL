import 'dart:io';
import 'package:flutter/material.dart';
import 'produk_screen.dart';
import 'penjualan_screen.dart';
import 'infotoko_screen.dart';
import 'laporan_penjualan_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'hutangpiutang_screen.dart';
import '../db/database_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _namaToko = "-";
  String? _logoPath;
  int _totalProduk = 0;
  int _stokHabis = 0;
  double _totalPenjualanHariIni = 0;

  final Color tomato = const Color(0xFFFF6347);

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initBannerAd();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final tokoList = await DatabaseHelper.instance.queryAll('info_toko');
      final produkList = await DatabaseHelper.instance.queryAll('produk');
      final penjualanList = await DatabaseHelper.instance.queryAll('penjualan');

      final today = DateTime.now();
      double totalPenjualan = 0;

      for (var s in penjualanList) {
        final tglString = s['tanggal']?.toString();
        final tgl = DateTime.tryParse(tglString ?? "");

        if (tgl != null &&
            tgl.year == today.year &&
            tgl.month == today.month &&
            tgl.day == today.day) {
          final totalValue = s['total'];
          if (totalValue is int) {
            totalPenjualan += totalValue.toDouble();
          } else if (totalValue is double) {
            totalPenjualan += totalValue;
          } else if (totalValue is String) {
            totalPenjualan += double.tryParse(totalValue) ?? 0;
          }
        }
      }

      setState(() {
        _namaToko =
            tokoList.isNotEmpty ? (tokoList.first['nama_toko'] ?? "-") : "-";
        _logoPath = tokoList.isNotEmpty ? tokoList.first['logo'] : null;
        _totalProduk = produkList.isNotEmpty ? produkList.length : 0;
        _stokHabis =
            produkList.where((p) => ((p['stok'] ?? 0) as int) <= 0).length;
        _totalPenjualanHariIni = totalPenjualan;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("gagal_load_data".tr + ": $e")),
      );
    }
  }

  // Banner Ad
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

  // Interstitial
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
  Widget build(BuildContext context) {
    final List<_DashboardMenu> menuItems = [
      _DashboardMenu(
        title: 'produk'.tr,
        icon: Icons.storefront,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProdukScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'penjualan'.tr,
        icon: Icons.point_of_sale,
        onTap: () {
          _showInterstitial();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PenjualanScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'info_toko'.tr,
        icon: Icons.info_outline,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InfoTokoScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'laporan'.tr,
        icon: Icons.bar_chart,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LaporanPenjualanPdfScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'hutang_piutang'.tr,
        icon: Icons.account_balance_wallet,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HutangPiutangScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'pengaturan'.tr,
        icon: Icons.settings,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(onDatabaseChanged: _loadData),
            ),
          );
        },
      ),
      _DashboardMenu(
        title: 'tentang'.tr,
        icon: Icons.info_outline,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ).then((_) => _loadData());
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: tomato,
        title: Row(
          children: [
            _logoPath != null && _logoPath!.isNotEmpty
                ? CircleAvatar(
                    backgroundImage: FileImage(File(_logoPath!)),
                    radius: 20,
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.store, size: 22, color: tomato),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _namaToko,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildKpiCard(
                            'total_produk', _totalProduk.toString(), Icons.store, tomato),
                        const SizedBox(width: 12),
                        _buildKpiCard(
                            'stok_habis', _stokHabis.toString(), Icons.warning_amber, Colors.redAccent),
                        const SizedBox(width: 12),
                      ],
                    ),
                    Row(
                      children: [
                        _buildKpiCard(
                            'penjualan_hari_ini',
                            'Rp ${_totalPenjualanHariIni.toStringAsFixed(0)}',
                            Icons.attach_money,
                            Colors.green),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menuItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (_, index) {
                        final item = menuItems[index];
                        return _ShopeeMenuItem(item: item, tomato: tomato);
                      },
                    ),
                  ],
                ),
              ),
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

  Widget _buildKpiCard(String titleKey, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 5,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                titleKey.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopeeMenuItem extends StatelessWidget {
  final _DashboardMenu item;
  final Color tomato;

  const _ShopeeMenuItem({required this.item, required this.tomato});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: tomato.withOpacity(0.15),
                child: Icon(item.icon, size: 28, color: tomato),
              ),
              if (item.badge != null && item.badge!.isNotEmpty)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardMenu {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  _DashboardMenu({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badge,
  });
}
