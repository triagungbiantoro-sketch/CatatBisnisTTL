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

  final Color tomato = const Color(0xFFFF6347); // 🎨 Warna Tomato

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
      _namaToko = tokoList.isNotEmpty ? (tokoList.first['nama_toko'] ?? "-") : "-";
      _logoPath = tokoList.isNotEmpty ? tokoList.first['logo'] : null;
      _totalProduk = produkList.isNotEmpty ? produkList.length : 0;
      _stokHabis =
          produkList.where((p) => ((p['stok'] ?? 0) as int) <= 0).length;
      _totalPenjualanHariIni = totalPenjualan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_DashboardMenu> menuItems = [
      _DashboardMenu(
        title: 'Produk',
        icon: Icons.storefront,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProdukScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'Penjualan',
        icon: Icons.point_of_sale,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PenjualanScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'Info Toko',
        icon: Icons.info_outline,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InfoTokoScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'Laporan',
        icon: Icons.bar_chart,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LaporanPenjualanPdfScreen()),
          ).then((_) => _loadData());
        },
      ),
     _DashboardMenu(
        title: 'Hutang Piutang',
        icon: Icons.account_balance_wallet, // ganti ikon lebih cocok
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HutangPiutangScreen()),
          ).then((_) => _loadData());
        },
      ),
      _DashboardMenu(
        title: 'Pengaturan',
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
        title: 'Tentang',
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // KPI Section
              Row(
                children: [
                  _buildKpiCard(
                      'Total Produk', _totalProduk.toString(),
                      Icons.store, tomato),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                      'Stok Habis', _stokHabis.toString(),
                      Icons.warning_amber, Colors.redAccent),
                  const SizedBox(width: 12),
                ],
              ),
              Row(
                children: [
                  _buildKpiCard(
                      'Penjualan Hari Ini',
                      'Rp ${_totalPenjualanHariIni.toStringAsFixed(0)}',
                      Icons.attach_money,
                      Colors.green),
                ],
              ),
              const SizedBox(height: 28),

              // Shopee-style Menu Grid
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
    );
  }

  Widget _buildKpiCard(
      String title, String value, IconData icon, Color color) {
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
                title,
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

// Shopee-style Menu Item
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
