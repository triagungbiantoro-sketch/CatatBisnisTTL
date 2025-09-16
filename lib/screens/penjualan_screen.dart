import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key});

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> penjualanList = [];
  List<Map<String, dynamic>> produkList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ Refresh otomatis setelah restore database / kembali ke foreground
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
    int? selectedProdukId = penjualan?['produk_id'];
    String jumlahStr = penjualan?['jumlah']?.toString() ?? '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                penjualan == null ? 'Tambah Penjualan' : 'Edit Penjualan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedProdukId,
                      items: produkList.map((produk) {
                        return DropdownMenuItem<int>(
                          value: produk['id'],
                          child: Text(
                              '${produk['nama']} (Stok: ${produk['stok']})'),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedProdukId = value),
                      decoration: const InputDecoration(
                        labelText: 'Pilih Produk',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: jumlahStr),
                      onChanged: (value) => jumlahStr = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (selectedProdukId == null || jumlahStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produk dan jumlah wajib diisi'),
                        ),
                      );
                      return;
                    }

                    int jumlah = int.tryParse(jumlahStr) ?? 0;
                    if (jumlah <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Jumlah harus lebih dari 0'),
                        ),
                      );
                      return;
                    }

                    final produk = produkList
                        .firstWhere((p) => p['id'] == selectedProdukId);

                    if (penjualan == null && produk['stok'] < jumlah) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stok produk tidak mencukupi'),
                        ),
                      );
                      return;
                    }

                    double harga = produk['harga'];
                    double total = harga * jumlah;
                    String tanggal = DateTime.now().toIso8601String();

                    if (penjualan == null) {
                      // Tambah penjualan baru
                      await DatabaseHelper.instance.insert('penjualan', {
                        'produk_id': selectedProdukId,
                        'jumlah': jumlah,
                        'total': total,
                        'tanggal': tanggal,
                      });

                      // Kurangi stok produk
                      await DatabaseHelper.instance.update(
                        'produk',
                        {'stok': produk['stok'] - jumlah},
                        'id = ?',
                        [produk['id']],
                      );
                    } else {
                      // Update penjualan
                      int jumlahLama = penjualan['jumlah'];
                      int selisih = jumlah - jumlahLama;

                      if (produk['stok'] < selisih) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stok tidak mencukupi untuk update'),
                          ),
                        );
                        return;
                      }

                      await DatabaseHelper.instance.update(
                        'penjualan',
                        {
                          'id': penjualan['id'],
                          'produk_id': selectedProdukId,
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
                  label: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _hapusPenjualan(Map<String, dynamic> penjualan) async {
    final produk = produkList
        .firstWhere((p) => p['id'] == penjualan['produk_id'], orElse: () => {});
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
                      ? "Laporan Penjualan Bulanan"
                      : "Laporan Penjualan Harian",
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["Tanggal", "Produk", "Jumlah", "Total"],
            data: filtered
                .map((p) => [
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(p['tanggal'])),
                      p['produk_nama'] ?? '',
                      p['jumlah'].toString(),
                      "Rp ${p['total']}"
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text("Total Penjualan: Rp $totalAll",
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
            ? 'Laporan Penjualan Bulanan'
            : 'Laporan Penjualan Harian');
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
        title: const Text('Penjualan'),
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
      body: penjualanList.isEmpty
          ? const Center(
              child: Text(
                'Belum ada penjualan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
          : ListView.builder(
              itemCount: penjualanList.length,
              itemBuilder: (context, index) {
                final penjualan = penjualanList[index];
                return Card(
                  elevation: 3,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: _buildThumbnail(penjualan['gambar_path']),
                    title: Text(
                      penjualan['produk_nama'] ?? 'Produk tidak ditemukan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jumlah: ${penjualan['jumlah']}'),
                        Text(
                          'Total: Rp ${penjualan['total'].toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        Text(
                          'Tanggal: ${penjualan['tanggal']}',
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
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _hapusPenjualan(penjualan),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
