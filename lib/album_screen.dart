import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'models/photo_item.dart';

class CachedUrl {
  final String url;
  final DateTime expiry;
  CachedUrl(this.url, this.expiry);
}

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final ImagePicker _picker = ImagePicker();
  List<PhotoItem> photoList = [];
  final Map<String, CachedUrl> _signedUrlCache = {};
  bool _isPicking = false;
  bool _isSelectionMode = false;
  final Set<int> _selectedForAction = {};

  @override
  void initState() {
    super.initState();
    _initializePhotos();
  }

  Future<void> _initializePhotos() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final userId = user.id;

      final response = await Supabase.instance.client
          .from('user_photos')
          .select('path')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      photoList = (response as List<dynamic>).map((e) {
        return PhotoItem(filePath: e['path'] as String, createdAt: DateTime.now());
      }).toList();

      await Future.wait(photoList.map((photo) async {
        final url = await Supabase.instance.client
            .storage
            .from('user-photos')
            .createSignedUrl(photo.filePath, 300);
        _signedUrlCache[photo.filePath] =
            CachedUrl(url, DateTime.now().add(const Duration(minutes: 5)));
      }));

      setState(() {});
    } catch (e) {
      print('사진 불러오기 에러: $e');
    }
  }

  Future<String> _getSignedUrl(String filePath) async {
    final cached = _signedUrlCache[filePath];
    final now = DateTime.now();

    if (cached != null && now.isBefore(cached.expiry)) return cached.url;

    final newUrl = await Supabase.instance.client
        .storage
        .from('user-photos')
        .createSignedUrl(filePath, 300);
    _signedUrlCache[filePath] =
        CachedUrl(newUrl, now.add(const Duration(minutes: 5)));
    return newUrl;
  }

  Future<void> _pickAndUploadImages() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final userId = user.id;

      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) return;

      for (var pickedFile in pickedFiles) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        final filePath = '$userId/$fileName';

        await Supabase.instance.client
            .storage
            .from('user-photos')
            .upload(filePath, File(pickedFile.path));

        await Supabase.instance.client
            .from('user_photos')
            .insert({
              'user_id': userId,
              'path': filePath,
              'created_at': DateTime.now().toIso8601String()
            });

        await _getSignedUrl(filePath);

        photoList.add(PhotoItem(filePath: filePath, createdAt: DateTime.now()));
      }

      setState(() {});
    } catch (e) {
      print("사진 선택/업로드 에러: $e");
    } finally {
      _isPicking = false;
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedForAction.clear();
    });
  }

  void _selectForAction(int index) {
    setState(() {
      if (_selectedForAction.contains(index)) {
        _selectedForAction.remove(index);
      } else {
        _selectedForAction.add(index);
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final userId = user.id;

      for (var index in _selectedForAction.toList()..sort((a, b) => b.compareTo(a))) {
        final filePath = photoList[index].filePath;

        await Supabase.instance.client
            .storage
            .from('user-photos')
            .remove([filePath]);

        await Supabase.instance.client
            .from('user_photos')
            .delete()
            .eq('user_id', userId)
            .eq('path', filePath);

        photoList.removeAt(index);
        _signedUrlCache.remove(filePath);
      }

      _isSelectionMode = false;
      _selectedForAction.clear();
      setState(() {});
    } catch (e) {
      print('사진 삭제 에러: $e');
    }
  }

  /// 선택 사진 공유 (방법2: 로컬 다운로드 후 공유)
  Future<void> _shareSelectedImages() async {
    if (_selectedForAction.isEmpty) return;

    List<XFile> filesToShare = [];
    final tempDir = await getTemporaryDirectory();

    for (var i in _selectedForAction) {
      final url = await _getSignedUrl(photoList[i].filePath);
      final res = await http.get(Uri.parse(url));
      final file = File('${tempDir.path}/${photoList[i].filePath.split('/').last}');
      await file.writeAsBytes(res.bodyBytes);
      filesToShare.add(XFile(file.path));
    }

    await Share.shareXFiles(
      filesToShare,
      text: '공유할 사진입니다.',
    );
  }

  void _viewImageFullScreen(String filePath) async {
    final url = await _getSignedUrl(filePath);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("사진 보기")),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isSelectionMode) ...[
                ElevatedButton.icon(
                  onPressed: _pickAndUploadImages,
                  icon: const Icon(Icons.add),
                  label: const Text("추가"),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _toggleSelectionMode,
                icon: const Icon(Icons.select_all),
                label: Text(_isSelectionMode ? "취소" : "선택"),
              ),
              const SizedBox(width: 8),
              if (_isSelectionMode) ...[
                ElevatedButton.icon(
                  onPressed: _selectedForAction.isEmpty ? null : _deleteSelectedImages,
                  icon: const Icon(Icons.delete),
                  label: const Text("삭제"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _selectedForAction.isEmpty ? null : _shareSelectedImages,
                  icon: const Icon(Icons.share),
                  label: const Text("공유"),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: photoList.isEmpty
              ? const Center(child: Text("사진을 선택해주세요", style: TextStyle(fontSize: 20)))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ReorderableGridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: List.generate(photoList.length, (index) {
                      bool isSelected = _selectedForAction.contains(index);
                      final filePath = photoList[index].filePath;

                      return GestureDetector(
                        key: ValueKey(filePath),
                        onTap: () => _isSelectionMode
                            ? _selectForAction(index)
                            : _viewImageFullScreen(filePath),
                        child: Stack(
                          children: [
                            FutureBuilder<String>(
                              future: _getSignedUrl(filePath),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                } else if (snapshot.hasError || !snapshot.hasData) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    ),
                                  );
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    border: isSelected
                                        ? Border.all(color: Colors.red, width: 3)
                                        : null,
                                  ),
                                  child: Image.network(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                );
                              },
                            ),
                            if (_isSelectionMode)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final photo = photoList.removeAt(oldIndex);
                        photoList.insert(newIndex, photo);
                      });
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
