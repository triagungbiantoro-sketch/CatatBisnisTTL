import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLaporan();
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
    final pdf = pw.Document();
    double totalSemua =
        laporan.fold(0, (sum, item) => sum + (item['total'] as num));

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("Laporan Penjualan",
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["Produk", "Jumlah", "Total", "Tanggal"],
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
          pw.Text("Total Penjualan: Rp $totalSemua",
              style: pw.TextStyle(fontSize: 16)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/laporan_penjualan.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],
        text: 'Laporan Penjualan (${filter.toUpperCase()})');
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
        title: const Text("Laporan Penjualan"),
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
              items: const [
                DropdownMenuItem(value: "harian", child: Text("Harian")),
                DropdownMenuItem(value: "bulanan", child: Text("Bulanan")),
                DropdownMenuItem(value: "tahunan", child: Text("Tahunan")),
                DropdownMenuItem(value: "custom", child: Text("Custom Range")),
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
          Expanded(
            child: laporan.isEmpty
                ? const Center(child: Text("Tidak ada data penjualan"))
                : ListView.builder(
                    itemCount: laporan.length,
                    itemBuilder: (context, index) {
                      final item = laporan[index];
                      return ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: Text(item['produk_nama'] ?? "Produk"),
                        subtitle: Text(
                            "Jumlah: ${item['jumlah']} | Rp ${item['total']}"),
                        trailing: Text(item['tanggal']),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Penjualan",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Rp $totalSemua",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
