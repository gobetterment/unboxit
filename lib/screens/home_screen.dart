import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'save_screen.dart';
import 'settings_screen.dart';
import 'package:unboxit/models/link.dart';
import 'package:unboxit/widgets/link_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Link> _allLinks = [];
  List<Link> _filteredLinks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final Set<String> _availableTags = <String>{};
  final Map<String, int> _tagCounts = {};
  String? _error;
  final _supabase = Supabase.instance.client;

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
    for (var link in _allLinks) {
      for (var tag in link.tags) {
        _availableTags.add(tag);
        _tagCounts[tag] = (_tagCounts[tag] ?? 0) + 1;
      }
    }
  }

  Future<void> _loadLinks() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('links')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _allLinks = data.map((json) => Link.fromJson(json)).toList();
        _filterLinks(_searchController.text);
        _extractTags();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 불러오는데 실패했습니다.')),
        );
      }
    }
  }

  void _filterLinks(String query) {
    setState(() {
      _filteredLinks = _allLinks.where((link) {
        bool matchesQuery = true;
        if (query.isNotEmpty) {
          final searchQuery = query.toLowerCase();
          matchesQuery = link.title.toLowerCase().contains(searchQuery) ||
              link.tags.any((tag) => tag.toLowerCase().contains(searchQuery)) ||
              (link.description?.toLowerCase().contains(searchQuery) ??
                  false) ||
              (link.memo?.toLowerCase().contains(searchQuery) ?? false);
        }

        bool matchesTags = true;
        if (_selectedTags.isNotEmpty) {
          matchesTags = _selectedTags.every((tag) => link.tags.contains(tag));
        }

        return matchesQuery && matchesTags;
      }).toList();
    });
  }

  Future<void> _handleDelete(Link link) async {
    try {
      await _supabase.from('links').delete().eq('id', link.id);
      setState(() {
        _allLinks.remove(link);
        _filterLinks(_searchController.text);
        _extractTags();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크가 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크 삭제에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _handleLaunch(Link link) async {
    final url = Uri.parse(link.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL을 열 수 없습니다')),
        );
      }
    }
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
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
                if (_availableTags.isNotEmpty)
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableTags.length,
                      itemBuilder: (context, index) {
                        final tag = _availableTags.elementAt(index);
                        final isSelected = _selectedTags.contains(tag);
                        return Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 8,
                            right: index == _availableTags.length - 1 ? 0 : 0,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                                _filterLinks(_searchController.text);
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$tag (${_tagCounts[tag] ?? 0})',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
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
                        : RefreshIndicator(
                            onRefresh: _loadLinks,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredLinks.length,
                              itemBuilder: (context, index) {
                                final link = _filteredLinks[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: LinkCard(
                                    link: link,
                                    onDelete: _handleDelete,
                                    onLaunch: _handleLaunch,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const SaveScreen(),
            ),
          );
          if (result == true) {
            _loadLinks();
          }
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
