import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _filteredLinks = [];
  bool _isLoading = true;

  // 필터 상태
  final Set<String> _selectedContentTypes = {};
  final Set<String> _selectedTags = {};
  final Set<String> _availableTags = {}; // 실제 존재하는 태그 목록
  final Map<String, int> _tagCounts = {}; // 태그별 콘텐츠 개수

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

  Future<void> _loadLinks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('links')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _links = List<Map<String, dynamic>>.from(response);
          _extractTags();
          _applyFilters();
          _isLoading = false;
        });
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

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_links);

    // 검색어 필터링
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((link) {
        final title = (link['title'] ?? '').toLowerCase();
        final description = (link['description'] ?? '').toLowerCase();
        final memo = (link['memo'] ?? '').toLowerCase();
        final tags = (link['tags'] as List<dynamic>?)
                ?.map((e) => e.toString().toLowerCase())
                .join(' ') ??
            '';

        return title.contains(searchTerm) ||
            description.contains(searchTerm) ||
            memo.contains(searchTerm) ||
            tags.contains(searchTerm);
      }).toList();
    }

    // 콘텐츠 타입 필터링
    if (_selectedContentTypes.isNotEmpty) {
      filtered = filtered.where((link) {
        final url = link['url']?.toLowerCase() ?? '';
        if (_selectedContentTypes.contains('Video')) {
          if (url.contains('youtube.com') || url.contains('youtu.be')) {
            return true;
          }
        }
        if (_selectedContentTypes.contains('Images')) {
          if (url.contains('instagram.com') || url.contains('pinterest.com')) {
            return true;
          }
        }
        if (_selectedContentTypes.contains('Articles')) {
          if (!url.contains('youtube.com') && !url.contains('instagram.com')) {
            return true;
          }
        }
        return false;
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
        title: const Text(
          '카테고리',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 검색바
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '검색',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                  onChanged: (value) {
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 32),

                // FILTERS 섹션
                const Text(
                  'FILTERS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Articles'),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedContentTypes.add('Articles');
                          } else {
                            _selectedContentTypes.remove('Articles');
                          }
                          _applyFilters();
                        });
                      },
                      selected: _selectedContentTypes.contains('Articles'),
                      backgroundColor: Colors.grey[50],
                      selectedColor: Colors.black.withOpacity(0.1),
                      side: BorderSide(color: Colors.grey[300]!),
                      labelStyle: const TextStyle(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Images'),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedContentTypes.add('Images');
                          } else {
                            _selectedContentTypes.remove('Images');
                          }
                          _applyFilters();
                        });
                      },
                      selected: _selectedContentTypes.contains('Images'),
                      backgroundColor: Colors.grey[50],
                      selectedColor: Colors.black.withOpacity(0.1),
                      side: BorderSide(color: Colors.grey[300]!),
                      labelStyle: const TextStyle(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Video'),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedContentTypes.add('Video');
                          } else {
                            _selectedContentTypes.remove('Video');
                          }
                          _applyFilters();
                        });
                      },
                      selected: _selectedContentTypes.contains('Video'),
                      backgroundColor: Colors.grey[50],
                      selectedColor: Colors.black.withOpacity(0.1),
                      side: BorderSide(color: Colors.grey[300]!),
                      labelStyle: const TextStyle(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // TAGS 섹션
                const Text(
                  'TAGS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tag) {
                    final count = _tagCounts[tag] ?? 0;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedTags.contains(tag)) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                          _applyFilters();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTags.contains(tag)
                              ? Colors.black.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($count)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 필터링된 결과
                if (_filteredLinks.isEmpty &&
                    (_selectedContentTypes.isNotEmpty ||
                        _selectedTags.isNotEmpty ||
                        _searchController.text.isNotEmpty))
                  const Center(
                    child: Text(
                      '검색 결과가 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredLinks.isEmpty
                        ? _links.length
                        : _filteredLinks.length,
                    itemBuilder: (context, index) {
                      final link = _filteredLinks.isEmpty
                          ? _links[index]
                          : _filteredLinks[index];
                      return _buildContentCard(link);
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              link['title'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
            if ((link['tags'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: (link['tags'] as List<dynamic>)
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
