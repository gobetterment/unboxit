import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io' show Platform;
import 'save_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_screen.dart';
import 'package:unboxit/models/link.dart';
import 'package:unboxit/services/link_service.dart';
import 'package:unboxit/widgets/link_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LinkService _linkService = LinkService();
  List<Link> _links = [];
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
      for (var tag in link.tags) {
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
          _links = List<Link>.from(response.map((data) => Link.fromJson(data)));
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
    List<Link> filtered = List.from(_links);

    if (query.isNotEmpty) {
      filtered = filtered.where((link) {
        final title = link.title.toLowerCase();
        final searchQuery = query.toLowerCase();
        return title.contains(searchQuery) ||
            link.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
      }).toList();
    }

    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((link) {
        return _selectedTags.any((tag) => link.tags.contains(tag));
      }).toList();
    }

    setState(() {
      _links = filtered;
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _links.isEmpty
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
                          itemCount: _links.length,
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            return LinkCard(link: link);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
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
