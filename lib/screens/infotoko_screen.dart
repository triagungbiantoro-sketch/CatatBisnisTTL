import 'package:flutter/material.dart';
import '../db/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInfoToko();
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Info Toko berhasil disimpan')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Toko'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Toko',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Nama toko wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: alamatController,
                      decoration: const InputDecoration(
                        labelText: 'Alamat',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: teleponController,
                      decoration: const InputDecoration(
                        labelText: 'Telepon',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!regex.hasMatch(value)) {
                            return 'Format email tidak valid';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveInfoToko,
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
