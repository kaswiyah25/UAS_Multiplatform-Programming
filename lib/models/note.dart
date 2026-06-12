class Note {
  final String id;
  final String title;
  final String content;
  final String lastModified;
  final int imageCount; // Jumlah lampiran gambar (0–3)

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.lastModified,
    this.imageCount = 0,
  });

  // Getter praktis untuk mengecek apakah catatan memiliki lampiran
  bool get hasImage => imageCount > 0;
}