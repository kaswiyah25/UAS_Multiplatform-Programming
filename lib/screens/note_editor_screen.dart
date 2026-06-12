import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../helpers/file_helper.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final FileHelper _fileHelper = FileHelper();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isSaving = false;

  // Daftar slot gambar dengan panjang tetap maxImages (null = slot kosong)
  // Indeks list (0-based) berkorespondensi dengan indeks berkas (1-based)
  final List<File?> _imageSlots =
      List.filled(FileHelper.maxImages, null, growable: false);

  // Slot mana saja yang sudah tersimpan di disk (bukan gambar baru dari galeri)
  final List<bool> _isExistingImage =
      List.filled(FileHelper.maxImages, false, growable: false);

  bool get _isEditMode => widget.note != null;

  late final String _resolvedNoteId;

  @override
  void initState() {
    super.initState();

    _resolvedNoteId =
        widget.note?.id ?? _fileHelper.generateNoteId();

    if (_isEditMode) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _loadExistingImages();
    }
  }

  // Memuat semua gambar yang sudah tersimpan ke dalam slot
  Future<void> _loadExistingImages() async {
    final files = await _fileHelper.getAllNoteImageFiles(_resolvedNoteId);

    if (!mounted) return;

    setState(() {
      for (int i = 0; i < FileHelper.maxImages; i++) {
        _imageSlots[i] = files[i];
        _isExistingImage[i] = files[i] != null;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Jumlah slot yang sudah terisi (gambar existing + gambar baru)
  int get _filledCount =>
      _imageSlots.where((f) => f != null).length;

  // Ambil gambar dari galeri lalu isi slot pertama yang kosong
  Future<void> _pickImage() async {
    if (_filledCount >= FileHelper.maxImages) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (xFile == null || !mounted) return;

    // Temukan indeks slot kosong pertama
    final emptyIndex =
        _imageSlots.indexWhere((f) => f == null);

    if (emptyIndex == -1) return;

    setState(() {
      _imageSlots[emptyIndex] = File(xFile.path);
      _isExistingImage[emptyIndex] = false;
    });
  }

  // Hapus gambar pada slot tertentu
  Future<void> _removeImage(int slotIndex) async {
    setState(() {
      _imageSlots[slotIndex] = null;
      _isExistingImage[slotIndex] = false;
    });
  }

  // Simpan catatan beserta semua perubahan gambar
  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Judul atau isi catatan tidak boleh kosong.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Simpan teks catatan
      await _fileHelper.saveNote(
        _resolvedNoteId,
        _titleController.text.trim(),
        _contentController.text.trim(),
      );

      // Proses setiap slot gambar (indeks 1-based di FileHelper)
      for (int i = 0; i < FileHelper.maxImages; i++) {
        final fileInSlot = _imageSlots[i];
        final index = i + 1; // Konversi ke indeks 1-based

        if (fileInSlot == null) {
          // Slot kosong: hapus berkas gambar dari disk jika sebelumnya ada
          if (_isExistingImage[i]) {
            await _fileHelper.deleteNoteImage(_resolvedNoteId, index);
          }
        } else {
          // Slot terisi gambar baru (bukan dari disk): simpan dengan kompresi
          final isNewImage =
              !fileInSlot.path.contains(_resolvedNoteId);

          if (isNewImage) {
            await _fileHelper.saveNoteImage(
                _resolvedNoteId, index, fileInSlot.path);
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan catatan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canAddMore = _filledCount < FileHelper.maxImages;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Simpan',
                  onPressed: _saveNote,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input Judul
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Judul catatan',
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(),

            // Input Isi
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Tulis catatanmu di sini...',
                border: InputBorder.none,
              ),
              maxLines: null,
              minLines: 8,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 16),

            // Label jumlah lampiran
            Text(
              'Lampiran Foto ($_filledCount/${FileHelper.maxImages})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            // Baris horizontal yang dapat digulir untuk menampilkan gambar
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Tampilkan setiap slot gambar yang terisi
                  for (int i = 0; i < FileHelper.maxImages; i++)
                    if (_imageSlots[i] != null)
                      _buildImageTile(i),

                  // Tombol tambah gambar — hanya tampil jika kuota belum penuh
                  if (canAddMore)
                    _buildAddButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget satu thumbnail gambar dengan tombol hapus di pojok kanan atas
  Widget _buildImageTile(int slotIndex) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _imageSlots[slotIndex]!,
              fit: BoxFit.cover,
            ),
          ),
          // Tombol hapus di pojok kanan atas
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(slotIndex),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget tombol tambah gambar
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade100,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 36, color: Colors.grey),
            SizedBox(height: 6),
            Text(
              'Tambah Foto',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}