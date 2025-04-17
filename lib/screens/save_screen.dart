import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';

class SaveScreen extends StatefulWidget {
  final String? initialUrl;

  const SaveScreen({super.key, this.initialUrl});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class MetadataParser {
  static final Map<String, MetadataStrategy> _strategies = {
    'instagram.com': InstagramStrategy(),
    'blog.naver.com': NaverBlogStrategy(),
    'velog.io': VelogStrategy(),
  };

  static MetadataStrategy getStrategy(String url) {
    for (var domain in _strategies.keys) {
      if (url.contains(domain)) {
        return _strategies[domain]!;
      }
    }
    return DefaultStrategy();
  }
}

abstract class MetadataStrategy {
  Map<String, String> get headers;
  Future<Map<String, dynamic>?> parse(String url);

  // 공통 유틸리티 메서드
  String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    return Uri.parse(baseUrl).resolve(relativeUrl).toString();
  }

  String? _getMetaContent(dom.Document document, String property) {
    final metaTag = document.querySelector('meta[property="$property"]') ??
        document.querySelector('meta[name="$property"]');
    return metaTag?.attributes['content'];
  }

  String _getFavicon(dom.Document document, String baseUrl) {
    // 1. apple-touch-icon 확인
    final appleIcon = document
        .querySelector('link[rel="apple-touch-icon"]')
        ?.attributes['href'];
    if (appleIcon != null) {
      return _resolveUrl(baseUrl, appleIcon);
    }

    // 2. 일반 favicon 확인
    final standardIcon = document
            .querySelector('link[rel="icon"]')
            ?.attributes['href'] ??
        document.querySelector('link[rel="shortcut icon"]')?.attributes['href'];
    if (standardIcon != null) {
      return _resolveUrl(baseUrl, standardIcon);
    }

    // 3. 기본 /favicon.ico 시도
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}/favicon.ico';
  }
}

class InstagramStrategy extends MetadataStrategy {
  @override
  Map<String, String> get headers => {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      };

  @override
  Future<Map<String, dynamic>?> parse(String url) async {
    // URL을 모바일 버전으로 변환
    String mobileUrl = url;
    if (!url.contains('instagram.com/p/') && url.contains('instagram.com/')) {
      final match = RegExp(r'instagram\.com/([^/]+)/?$').firstMatch(url);
      if (match != null) {
        final username = match.group(1);
        mobileUrl = 'https://www.instagram.com/$username/';
      }
    }

    print('인스타그램 모바일 URL: $mobileUrl');
    final response = await http.get(Uri.parse(mobileUrl), headers: headers);
    print('인스타그램 응답 상태 코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);

      // JSON-LD 데이터 추출 시도
      final jsonLdScript =
          document.querySelector('script[type="application/ld+json"]');
      if (jsonLdScript != null) {
        try {
          final jsonData = json.decode(jsonLdScript.text);
          print('JSON-LD 데이터 발견: $jsonData');

          if (jsonData is Map) {
            return {
              'title': jsonData['name'] ??
                  jsonData['headline'] ??
                  jsonData['caption'],
              'description': jsonData['description'] ?? jsonData['articleBody'],
              'image': jsonData['image']?[0] ?? jsonData['thumbnailUrl'],
              'site_name': 'Instagram',
              'favicon': 'https://www.instagram.com/favicon.ico',
            };
          }
        } catch (e) {
          print('JSON-LD 파싱 오류: $e');
        }
      }

      // OG 태그 추출
      final title = _getMetaContent(document, 'og:title') ??
          document.querySelector('title')?.text ??
          '인스타그램 게시물';
      final description = _getMetaContent(document, 'og:description');
      final image = _getMetaContent(document, 'og:image');

      // 대체 이미지 URL 찾기
      String? alternativeImage;
      if (image == null || image.isEmpty) {
        final imgElements = document.querySelectorAll('img[src*="instagram"]');
        for (final img in imgElements) {
          final src = img.attributes['src'];
          if (src != null &&
              src.contains('instagram') &&
              !src.contains('favicon')) {
            alternativeImage = src;
            break;
          }
        }
      }

      return {
        'title': title,
        'description': description,
        'image': image ?? alternativeImage,
        'site_name': 'Instagram',
        'favicon': 'https://www.instagram.com/favicon.ico',
      };
    }
    return null;
  }
}

class NaverBlogStrategy extends MetadataStrategy {
  @override
  Map<String, String> get headers => {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      };

  @override
  Future<Map<String, dynamic>?> parse(String url) async {
    // 모바일 URL로 변환
    final blogMatch = RegExp(r'blog\.naver\.com/([^/]+)/(\d+)').firstMatch(url);
    if (blogMatch != null) {
      final userId = blogMatch.group(1);
      final postId = blogMatch.group(2);
      final mobileUrl =
          'https://m.blog.naver.com/PostView.naver?blogId=$userId&logNo=$postId';
      print('네이버 블로그 모바일 URL: $mobileUrl');

      final response = await http.get(Uri.parse(mobileUrl), headers: headers);
      print('네이버 블로그 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        final title = _getMetaContent(document, 'og:title') ??
            document.querySelector('title')?.text;
        final description = _getMetaContent(document, 'og:description');
        final image = _getMetaContent(document, 'og:image');

        return {
          'title': title,
          'description': description,
          'image': image,
          'site_name': 'Naver Blog',
          'favicon': 'https://blog.naver.com/favicon.ico',
        };
      }
    }
    return null;
  }
}

class VelogStrategy extends MetadataStrategy {
  @override
  Map<String, String> get headers => {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      };

  @override
  Future<Map<String, dynamic>?> parse(String url) async {
    final match = RegExp(r'https://velog\.io/@([^/]+)/([^/]+)').firstMatch(url);
    if (match != null) {
      final username = match.group(1);
      final slug = match.group(2);
      final apiUrl = 'https://v2.velog.io/api/posts/@$username/$slug';
      print('Velog API URL: $apiUrl');

      final apiResponse = await http.get(Uri.parse(apiUrl));
      if (apiResponse.statusCode == 200) {
        final postData = json.decode(apiResponse.body);
        print('Velog API 응답: $postData');

        return {
          'title': postData['title'],
          'description': postData['short_description'],
          'image': postData['thumbnail'],
          'site_name': 'velog',
          'favicon': 'https://static.velog.io/favicon.ico',
        };
      }
    }
    return null;
  }
}

class DefaultStrategy extends MetadataStrategy {
  @override
  Map<String, String> get headers => {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      };

  @override
  Future<Map<String, dynamic>?> parse(String url) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    print('HTTP 상태 코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);

      final title = _getMetaContent(document, 'og:title') ??
          document.querySelector('title')?.text;
      final description = _getMetaContent(document, 'og:description');
      final image = _getMetaContent(document, 'og:image');
      final siteName = _getMetaContent(document, 'og:site_name');
      final favicon = _getFavicon(document, url);

      return {
        'title': title,
        'description': description,
        'image': image,
        'site_name': siteName,
        'favicon': favicon,
      };
    }
    return null;
  }
}

class _SaveScreenState extends State<SaveScreen> {
  final _urlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _fetchMetadata(widget.initialUrl!).then((metadata) {
        if (mounted) {
          setState(() {
            _metadata = metadata;
          });
        }
      });
    }
  }

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return null;
    }
  }

  String _normalizeYouTubeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // youtu.be 단축 URL 처리
      if (uri.host == 'youtu.be') {
        final videoId = uri.path.replaceAll('/', '');
        return 'https://www.youtube.com/watch?v=$videoId';
      }

      // YouTube 공유 URL 처리 (youtube.com/shorts/...)
      if (uri.host.contains('youtube.com') && uri.path.contains('/shorts/')) {
        final videoId = uri.path.split('/shorts/')[1];
        return 'https://www.youtube.com/watch?v=$videoId';
      }

      return url;
    } catch (_) {
      return url;
    }
  }

  Future<Map<String, dynamic>?> _fetchMetadata(String url) async {
    try {
      print('URL 파싱 시작: $url');
      final strategy = MetadataParser.getStrategy(url);
      return await strategy.parse(url);
    } catch (e) {
      print('메타데이터 파싱 오류: $e');
      print('스택 트레이스: ${e is Error ? e.stackTrace : ''}');
      return null;
    }
  }

  String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    return Uri.parse(baseUrl).resolve(relativeUrl).toString();
  }

  String? _getMetaContent(dom.Document document, String property) {
    final metaTag = document.querySelector('meta[property="$property"]') ??
        document.querySelector('meta[name="$property"]');
    return metaTag?.attributes['content'];
  }

  String _getFavicon(dom.Document document, String baseUrl) {
    // 1. apple-touch-icon 확인
    final appleIcon = document
        .querySelector('link[rel="apple-touch-icon"]')
        ?.attributes['href'];
    if (appleIcon != null) {
      return _resolveUrl(baseUrl, appleIcon);
    }

    // 2. 일반 favicon 확인
    final standardIcon = document
            .querySelector('link[rel="icon"]')
            ?.attributes['href'] ??
        document.querySelector('link[rel="shortcut icon"]')?.attributes['href'];
    if (standardIcon != null) {
      return _resolveUrl(baseUrl, standardIcon);
    }

    // 3. 도메인별 기본 파비콘
    final uri = Uri.parse(baseUrl);
    if (uri.host.contains('blog.naver.com')) {
      return 'https://blog.naver.com/favicon.ico';
    } else if (uri.host.contains('velog.io')) {
      return 'https://static.velog.io/favicon.ico';
    }

    // 4. 기본 /favicon.ico 시도
    return '${uri.scheme}://${uri.host}/favicon.ico';
  }

  Future<void> _handleSave() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final metadata = await _fetchMetadata(_urlController.text);

      if (metadata == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메타데이터를 가져올 수 없습니다')),
        );
        return;
      }

      // 태그를 배열로 처리
      final tags = _tagsController.text.isNotEmpty
          ? _tagsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      await Supabase.instance.client.from('links').insert({
        'url': _urlController.text,
        'title': metadata['title'] ?? '',
        'description': metadata['description'] ?? '',
        'image': metadata['image'] ?? '',
        'site_name': metadata['site_name'] ?? '',
        'favicon': metadata['favicon'] ?? '',
        'tags': tags, // 배열로 저장
        'memo': _memoController.text,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크가 저장되었습니다')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('링크 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tagsController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domain = _urlController.text.isNotEmpty
        ? _extractDomain(_urlController.text)
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '저장',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'URL 입력',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _handleSave(),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_metadata != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_metadata?['image']?.isNotEmpty ?? false)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _metadata!['image']!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    if (_metadata?['title']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        _metadata!['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (_metadata?['description']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        _metadata!['description']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (domain != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        domain,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: '태그 입력 (쉼표로 구분)',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                hintText: '메모',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isLoading ? '저장 중...' : '저장',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
