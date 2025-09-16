import 'dart:io';
import 'dart:typed_data'; // untuk Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

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
              ? "Tambah Hutang/Piutang"
              : "Edit Hutang/Piutang"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: tipeCtrl.text,
                    decoration: const InputDecoration(labelText: "Tipe"),
                    items: const [
                      DropdownMenuItem(
                          value: "hutang",
                          child: Text("Hutang (toko ke supplier)")),
                      DropdownMenuItem(
                          value: "piutang",
                          child: Text("Piutang (pelanggan ke toko)")),
                    ],
                    onChanged: (val) => tipeCtrl.text = val!,
                  ),
                  TextFormField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(
                        labelText: "Nama Supplier/Pelanggan"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Wajib diisi" : null,
                  ),
                  TextFormField(
                    controller: jumlahCtrl,
                    decoration: const InputDecoration(labelText: "Jumlah"),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? "Wajib diisi" : null,
                  ),
                  TextFormField(
                    controller: tanggalCtrl,
                    decoration: const InputDecoration(
                        labelText: "Tanggal (YYYY-MM-DD)"),
                  ),
                  TextFormField(
                    controller: jatuhTempoCtrl,
                    decoration:
                        const InputDecoration(labelText: "Jatuh Tempo (opsional)"),
                  ),
                  TextFormField(
                    controller: keteranganCtrl,
                    decoration: const InputDecoration(labelText: "Keterangan"),
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: "Status"),
                    items: const [
                      DropdownMenuItem(
                          value: "belum_lunas", child: Text("Belum Lunas")),
                      DropdownMenuItem(value: "lunas", child: Text("Lunas")),
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
                        label: const Text("Kamera"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery)
                            .then((_) => setStateDialog(() {})),
                        icon: const Icon(Icons.photo),
                        label: const Text("Galeri"),
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
                child: const Text("Batal")),
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
                }
              },
              child: const Text("Simpan"),
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

  /// 🔍 Preview full image dengan zoom
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

  /// 📤 Share 1 item sebagai PDF
  Future<void> _shareAsPdf(Map<String, dynamic> item) async {
    try {
      final pdf = pw.Document();

      Uint8List? imageBytes;
      if (item['foto'] != null) {
        final f = File(item['foto']);
        if (f.existsSync()) {
          imageBytes = await f.readAsBytes();
        }
      }

      final pw.ImageProvider? imageProvider =
          imageBytes != null ? pw.MemoryImage(imageBytes) : null;

      pdf.addPage(
        pw.Page(
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Hutang/Piutang",
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text("Tipe: ${item['tipe']}"),
              pw.Text("Nama: ${item['nama']}"),
              pw.Text("Jumlah: Rp${item['jumlah']}"),
              pw.Text("Tanggal: ${item['tanggal']}"),
              pw.Text("Jatuh Tempo: ${item['jatuh_tempo'] ?? '-'}"),
              pw.Text("Status: ${item['status']}"),
              pw.Text("Keterangan: ${item['keterangan'] ?? '-'}"),
              if (imageProvider != null) ...[
                pw.SizedBox(height: 20),
                pw.Image(imageProvider, width: 200),
              ],
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/hutang_piutang_${item['id']}.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: "Data Hutang/Piutang");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal export/share PDF: $e")),
      );
    }
  }

  /// 📤 Share seluruh data (hutang/piutang) sebagai 1 PDF
  Future<void> _shareAllAsPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context ctx) => [
            pw.Text("Laporan Hutang & Piutang",
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            ..._data.map((item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        "${item['tipe'].toUpperCase()} - ${item['nama']} (Rp${item['jumlah']})",
                        style: pw.TextStyle(fontSize: 14)),
                    pw.Text("Tanggal: ${item['tanggal']}"),
                    pw.Text("Jatuh Tempo: ${item['jatuh_tempo'] ?? '-'}"),
                    pw.Text("Status: ${item['status']}"),
                    pw.Text("Keterangan: ${item['keterangan'] ?? '-'}"),
                    pw.Divider(),
                  ],
                )),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/laporan_hutang_piutang.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: "Laporan seluruh Hutang & Piutang");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal export semua: $e")),
      );
    }
  }

  Widget _buildList(String tipe) {
    final list = _data.where((e) => e['tipe'] == tipe).toList();

    if (list.isEmpty) {
      return const Center(child: Text("Belum ada data"));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final bool isLunas = item['status'] == 'lunas';
        final Color badgeColor = isLunas ? Colors.green : Colors.red;
        final String badgeText = isLunas ? "Lunas ✔" : "Belum Lunas ✖";

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
                    "Tanggal: ${item['tanggal']} | Jatuh Tempo: ${item['jatuh_tempo'] ?? '-'}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Colors.blue),
                        tooltip: "Export/Share PDF",
                        onPressed: () => _shareAsPdf(item),
                      ),
                      if (!isLunas)
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          tooltip: "Tandai Lunas",
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
          title: const Text("Hutang & Piutang"),
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
                tabs: const [
                  Tab(text: "Hutang"),
                  Tab(text: "Piutang"),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: "Export semua Hutang & Piutang",
              onPressed: _shareAllAsPdf,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList('hutang'),
                  _buildList('piutang'),
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
