import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import 'penjualan_screen.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _produkList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProduk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
              title: Text(produk == null ? "Tambah Produk" : "Edit Produk"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: namaController,
                      decoration:
                          const InputDecoration(labelText: "Nama Produk"),
                    ),
                    TextField(
                      controller: hargaController,
                      decoration: const InputDecoration(labelText: "Harga"),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: stokController,
                      decoration: const InputDecoration(labelText: "Stok"),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: deskripsiController,
                      decoration: const InputDecoration(labelText: "Deskripsi"),
                    ),
                    const SizedBox(height: 10),
                    if (imageFile != null)
                      Image.file(imageFile!, height: 100)
                    else if (produk?['gambar_path'] != null)
                      Image.file(File(produk!['gambar_path']), height: 100)
                    else
                      const Text("Belum ada gambar"),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo),
                          label: const Text("Galeri"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Kamera"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal"),
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
                  child: const Text("Simpan"),
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text("Daftar Produk",
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["Nama", "Harga", "Stok", "Deskripsi"],
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
        text: 'Laporan Daftar Produk');
  }

  Future<void> _openPenjualan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PenjualanScreen()),
    );

    if (result == true) {
      _loadProduk(); // refresh stok otomatis setelah transaksi
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
        title: const Text("Manajemen Produk"),
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
      body: _produkList.isEmpty
          ? const Center(child: Text("Belum ada produk"))
          : ListView.builder(
              itemCount: _produkList.length,
              itemBuilder: (ctx, i) {
                final produk = _produkList[i];
                return Card(
                  child: ListTile(
                    leading: (produk['gambar_path'] != null &&
                            produk['gambar_path'].toString().isNotEmpty)
                        ? GestureDetector(
                            onTap: () => _showImagePreview(produk['gambar_path']),
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
                        "Rp ${produk['harga']} | Stok: ${produk['stok']}\n${produk['deskripsi'] ?? ''}"),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _addOrEditProduk(produk: produk),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditProduk(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
