import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'save_screen.dart';
import 'category_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CategoryScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SaveScreen()),
        ).then((_) => _loadLinks());
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
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

    // SVG 이미지 처리
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

    // 일반 이미지 처리
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '꺼내보기',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _links.length,
                  itemBuilder: (context, index) {
                    final link = _links[index];
                    return _buildContentCard(link);
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: '카테고리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: '저장',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> link) {
    final DateTime createdAt = DateTime.parse(link['created_at']);
    final String formattedDate =
        '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(link['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('삭제 확인'),
              content: const Text('이 링크를 정말 삭제하시겠습니까?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    '삭제',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) async {
        final deletedLink = link;
        final deletedIndex = _links.indexOf(link);

        // UI에서 즉시 제거
        setState(() {
          _links.removeAt(deletedIndex);
        });

        try {
          await Supabase.instance.client
              .from('links')
              .delete()
              .eq('id', deletedLink['id']);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('링크가 삭제되었습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // 삭제 실패 시 되돌리기
          if (mounted) {
            setState(() {
              _links.insert(deletedIndex, deletedLink);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('삭제 실패: $e'),
                duration: const Duration(seconds: 2),
                action: SnackBarAction(
                  label: '확인',
                  onPressed: () {},
                ),
              ),
            );
          }
        }
      },
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
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnail(link['image']),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (link['url']?.isNotEmpty ?? false) ...[
                            Row(
                              children: [
                                if (link['favicon']?.isNotEmpty ?? false)
                                  CachedNetworkImage(
                                    imageUrl: link['favicon'],
                                    width: 16,
                                    height: 16,
                                    errorWidget: (context, url, error) =>
                                        const SizedBox.shrink(),
                                  ),
                                if (link['favicon']?.isNotEmpty ?? false)
                                  const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    link['url'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  link['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(link);
                                  } else if (value == 'delete') {
                                    _showDeleteConfirmation(link);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('수정'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('삭제'),
                                  ),
                                ],
                              ),
                            ],
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
                          if (link['memo']?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Text(
                              link['memo']!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if ((link['tags'] as List?)?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: (link['tags'] as List)
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> link) {
    final TextEditingController titleController =
        TextEditingController(text: link['title']);
    final TextEditingController descriptionController =
        TextEditingController(text: link['description']);
    final TextEditingController tagsController = TextEditingController(
      text: (link['tags'] as List?)?.join(', ') ?? '',
    );
    final TextEditingController memoController =
        TextEditingController(text: link['memo']);

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
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '태그 (쉼표로 구분)',
                  border: OutlineInputBorder(),
                ),
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
                  'tags': tags,
                  'memo': memoController.text,
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

  void _showDeleteConfirmation(Map<String, dynamic> link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 콘텐츠를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('links')
                    .delete()
                    .eq('id', link['id']);

                if (mounted) {
                  Navigator.pop(context);
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
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
