import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'save_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _filteredLinks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final Set<String> _availableTags = <String>{};
  final Map<String, int> _tagCounts = {};

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _extractTags() {
    _availableTags.clear();
    _tagCounts.clear();
    for (var link in _links) {
      final tags = (link['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      for (var tag in tags) {
        _availableTags.add(tag);
        _tagCounts[tag] = (_tagCounts[tag] ?? 0) + 1;
      }
    }
  }

  Future<void> _loadLinks() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _links = [];
        _filteredLinks = [];
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: const RouteSettings(name: '/login'),
            ),
            (route) => false,
          );
        }
        return;
      }

      final response = await Supabase.instance.client
          .from('links')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _links = List<Map<String, dynamic>>.from(response);
          _filteredLinks = _links;
          _isLoading = false;
        });
        _extractTags();
      }
    } catch (e) {
      print('링크 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterLinks(String query) {
    List<Map<String, dynamic>> filtered = List.from(_links);

    // 검색어 필터링
    if (query.isNotEmpty) {
      filtered = filtered.where((link) {
        final title = (link['title'] ?? '').toLowerCase();
        final description = (link['description'] ?? '').toLowerCase();
        final memo = (link['memo'] ?? '').toLowerCase();
        final tags = (link['tags'] as List<dynamic>?)
                ?.map((e) => e.toString().toLowerCase())
                .join(' ') ??
            '';
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) ||
            description.contains(searchQuery) ||
            memo.contains(searchQuery) ||
            tags.contains(searchQuery);
      }).toList();
    }

    // 태그 필터링
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((link) {
        final linkTags = (link['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        return _selectedTags.any((tag) => linkTags.contains(tag));
      }).toList();
    }

    setState(() {
      _filteredLinks = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '꺼내보기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 및 태그 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // 검색창
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '검색',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _filterLinks,
                ),
                const SizedBox(height: 12),

                // 태그 필터
                if (_availableTags.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              '$tag (${_tagCounts[tag] ?? 0})',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                                _filterLinks(_searchController.text);
                              });
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.black,
                            checkmarkColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // 링크 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLinks.isEmpty
                    ? const Center(
                        child: Text(
                          '저장된 링크가 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLinks.length,
                        itemBuilder: (context, index) {
                          return _buildContentCard(_filteredLinks[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaveScreen()),
          ).then((_) => _loadLinks());
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> link) {
    final formattedDate = DateTime.parse(link['created_at'])
        .toLocal()
        .toString()
        .split(' ')[0]
        .replaceAll('-', '.');

    return Slidable(
      key: Key(link['id'].toString()),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showEditDialog(link),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '수정',
          ),
          SlidableAction(
            onPressed: (context) => _showDeleteConfirmation(link),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '삭제',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: InkWell(
          onTap: () => _launchUrl(link['url']),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (link['memo']?.isNotEmpty ?? false) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '|',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          link['memo']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(link['image']),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link['title'] ?? '제목 없음',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (link['description']?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 4),
                            Text(
                              link['description']!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (link['site_name']?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (link['favicon']?.isNotEmpty ?? false)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      link['favicon']!,
                                      width: 16,
                                      height: 16,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox(),
                                    ),
                                  ),
                                if (link['favicon']?.isNotEmpty ?? false)
                                  const SizedBox(width: 4),
                                Text(
                                  link['site_name']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if ((link['tags'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (link['tags'] as List<dynamic>)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(
          Icons.link,
          color: Colors.grey,
          size: 40,
        ),
      );
    }

    if (imageUrl.toLowerCase().endsWith('.svg')) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[50],
        child: SvgPicture.network(
          imageUrl,
          width: 80,
          height: 80,
          placeholderBuilder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 80,
        height: 80,
        color: Colors.grey[50],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(
          Icons.error_outline,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('링크를 열 수 없습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('URL 실행 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 여는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> link) {
    final TextEditingController titleController =
        TextEditingController(text: link['title']);
    final TextEditingController descriptionController =
        TextEditingController(text: link['description']);
    final TextEditingController memoController =
        TextEditingController(text: link['memo']);
    final TextEditingController tagsController = TextEditingController(
      text: (link['tags'] as List<dynamic>?)?.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('콘텐츠 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '태그 (쉼표로 구분)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final tags = tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();

                await Supabase.instance.client.from('links').update({
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'memo': memoController.text,
                  'tags': tags,
                }).eq('id', link['id']);

                if (mounted) {
                  Navigator.pop(context);
                  _loadLinks();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('콘텐츠가 수정되었습니다')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('수정 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> link) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 콘텐츠를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await Supabase.instance.client
            .from('links')
            .delete()
            .eq('id', link['id']);

        if (mounted) {
          _loadLinks();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('콘텐츠가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
