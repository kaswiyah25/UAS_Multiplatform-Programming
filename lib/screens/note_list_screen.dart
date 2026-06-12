import 'package:flutter/material.dart';
import '../models/note.dart';
import '../helpers/file_helper.dart';
import 'note_editor_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final FileHelper _fileHelper = FileHelper();

  List<Note> _notes = [];
  bool _isLoading = true;

  static const List<String> _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final notes = await _fileHelper.getAllNotes();

    if (!mounted) return;
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  String _formatTanggal(String iso8601) {
    if (iso8601.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso8601).toLocal();
      final bulan = _namaBulan[dt.month - 1];
      final jam = dt.hour.toString().padLeft(2, '0');
      final menit = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $bulan ${dt.year}, $jam:$menit';
    } catch (_) {
      return '';
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text(
          'Catatan beserta seluruh gambar pendampingnya akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _fileHelper.deleteNote(noteId);
      _loadNotes();
    }
  }

  Future<void> _exportNote(String noteId) async {
    final exportPath = await _fileHelper.exportNote(noteId);

    if (!mounted) return;

    if (exportPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengekspor catatan: berkas tidak ditemukan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catatan berhasil diekspor ke:\n$exportPath'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Tutup',
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Future<void> _navigateToEditor({Note? note}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada catatan.\nTekan + untuk membuat catatan baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final tanggal = _formatTanggal(note.lastModified);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        // Ikon leading menunjukkan jumlah gambar
                        leading: note.imageCount > 0
                            ? Badge(
                                label: Text('${note.imageCount}'),
                                child: const Icon(Icons.image,
                                    color: Colors.blue),
                              )
                            : const Icon(Icons.article_outlined,
                                color: Colors.grey),
                        title: Text(
                          note.title.isEmpty
                              ? '(Tanpa judul)'
                              : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tanggal.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'Diubah: $tanggal',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              note.content.isEmpty
                                  ? '(Tidak ada isi)'
                                  : note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.upload_file,
                                  color: Colors.amber),
                              tooltip: 'Ekspor Catatan',
                              onPressed: () => _exportNote(note.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              tooltip: 'Hapus Catatan',
                              onPressed: () => _deleteNote(note.id),
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditor(note: note),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}