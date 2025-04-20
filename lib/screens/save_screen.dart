import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';
import '../models/link.dart';

class SaveScreen extends StatefulWidget {
  final Link? link;
  final String? initialUrl;

  const SaveScreen({super.key, this.link, this.initialUrl});

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
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    if (widget.link != null) {
      _urlController.text = widget.link!.url;
      _tagsController.text = widget.link!.tags.join(', ');
      _memoController.text = widget.link!.memo ?? '';
    } else if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _updateAutoTags(widget.initialUrl!);
      _fetchMetadata(widget.initialUrl!).then((metadata) {
        if (mounted && metadata != null) {
          setState(() {
            _metadata = metadata;
          });
        }
      });
    }

    // URL 입력 시 자동으로 메타데이터와 태그 가져오기
    _urlController.addListener(() {
      final url = _urlController.text.trim();
      if (url.isNotEmpty && Uri.parse(url).isAbsolute) {
        _updateAutoTags(url);
        _fetchMetadata(url).then((metadata) {
          if (mounted && metadata != null) {
            setState(() {
              _metadata = metadata;
            });
          }
        });
      }
    });
  }

  void _updateAutoTags(String url) {
    final autoTags = _getAutoTags(url);
    if (autoTags.isNotEmpty) {
      setState(() {
        if (_tagsController.text.isEmpty) {
          _tagsController.text = autoTags.join(', ');
        } else {
          // 기존 태그와 자동 태그를 합치기
          final existingTags = _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet();
          final newTags = autoTags.where((tag) => !existingTags.contains(tag));
          if (newTags.isNotEmpty) {
            _tagsController.text = [...existingTags, ...newTags].join(', ');
          }
        }
      });
    }
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  List<String> _getAutoTags(String url) {
    final domain = _extractDomain(url).toLowerCase();
    final autoTags = <String>[];

    // 동영상 플랫폼
    if (domain.contains('youtube.com') || domain.contains('youtu.be')) {
      autoTags.add('유튜브');
      autoTags.add('동영상');
    } else if (domain.contains('tv.naver.com')) {
      autoTags.add('네이버TV');
      autoTags.add('동영상');
    } else if (domain.contains('tvcast.naver.com')) {
      autoTags.add('네이버TV');
      autoTags.add('동영상');
    }

    // SNS 플랫폼
    else if (domain.contains('instagram.com')) {
      autoTags.add('인스타그램');
      autoTags.add('SNS');
    } else if (domain.contains('threads.net')) {
      autoTags.add('쓰레드');
      autoTags.add('SNS');
    } else if (domain.contains('twitter.com') || domain.contains('x.com')) {
      autoTags.add('트위터');
      autoTags.add('SNS');
    } else if (domain.contains('facebook.com')) {
      autoTags.add('페이스북');
      autoTags.add('SNS');
    } else if (domain.contains('linkedin.com')) {
      autoTags.add('링크드인');
      autoTags.add('SNS');
    }

    // 블로그 플랫폼
    else if (domain.contains('blog.naver.com')) {
      autoTags.add('블로그');
      autoTags.add('네이버');
    } else if (domain.contains('tistory.com')) {
      autoTags.add('블로그');
      autoTags.add('티스토리');
    } else if (domain.contains('velog.io')) {
      autoTags.add('블로그');
      autoTags.add('벨로그');
    } else if (domain.contains('medium.com')) {
      autoTags.add('블로그');
      autoTags.add('미디엄');
    } else if (domain.contains('brunch.co.kr')) {
      autoTags.add('블로그');
      autoTags.add('브런치');
    }

    // 쇼핑몰
    else if (domain.contains('coupang.com')) {
      autoTags.add('쇼핑');
      autoTags.add('쿠팡');
    } else if (domain.contains('gmarket.co.kr')) {
      autoTags.add('쇼핑');
      autoTags.add('지마켓');
    } else if (domain.contains('auction.co.kr')) {
      autoTags.add('쇼핑');
      autoTags.add('옥션');
    } else if (domain.contains('11st.co.kr')) {
      autoTags.add('쇼핑');
      autoTags.add('11번가');
    } else if (domain.contains('musinsa.com')) {
      autoTags.add('쇼핑');
      autoTags.add('무신사');
    }

    // 뉴스/미디어
    else if (domain.contains('news.naver.com')) {
      autoTags.add('뉴스');
      autoTags.add('네이버뉴스');
    } else if (domain.contains('daum.net/news')) {
      autoTags.add('뉴스');
      autoTags.add('다음뉴스');
    } else if (domain.contains('chosun.com')) {
      autoTags.add('뉴스');
      autoTags.add('조선일보');
    } else if (domain.contains('joongang.co.kr')) {
      autoTags.add('뉴스');
      autoTags.add('중앙일보');
    } else if (domain.contains('donga.com')) {
      autoTags.add('뉴스');
      autoTags.add('동아일보');
    }

    // 지식/학습
    else if (domain.contains('github.com')) {
      autoTags.add('개발');
      autoTags.add('깃허브');
    } else if (domain.contains('notion.so')) {
      autoTags.add('문서');
      autoTags.add('노션');
    } else if (domain.contains('ridibooks.com')) {
      autoTags.add('도서');
      autoTags.add('리디북스');
    } else if (domain.contains('yes24.com')) {
      autoTags.add('도서');
      autoTags.add('예스24');
    } else if (domain.contains('aladin.co.kr')) {
      autoTags.add('도서');
      autoTags.add('알라딘');
    }

    return autoTags;
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
      final normalizedUrl = _normalizeYouTubeUrl(url);

      final strategy = MetadataParser.getStrategy(normalizedUrl);
      return strategy.parse(normalizedUrl);
    } catch (e) {
      print('메타데이터 가져오기 오류: $e');
      return null;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final data = {
        'url': _urlController.text.trim(),
        'title':
            _metadata?['title'] ?? _extractDomain(_urlController.text.trim()),
        'tags': tags,
        'memo': _memoController.text,
        'user_id': user.id,
        'image': _metadata?['image'],
        'favicon': _metadata?['favicon'],
        'description': _metadata?['description'],
        'created_at': DateTime.now().toLocal().toIso8601String(),
      };

      if (widget.link != null) {
        await Supabase.instance.client
            .from('links')
            .update(data)
            .eq('id', widget.link!.id);
      } else {
        await Supabase.instance.client.from('links').insert(data);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.link != null ? '링크 수정' : '링크 저장',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                labelStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'URL을 입력해주세요';
                }
                if (!Uri.parse(value).isAbsolute) {
                  return '올바른 URL을 입력해주세요';
                }
                return null;
              },
              onChanged: (url) {
                if (url.isNotEmpty && Uri.parse(url).isAbsolute) {
                  _updateAutoTags(url);
                }
              },
            ),
            if (_metadata != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_metadata!['title'] != null)
                      Text(
                        _metadata!['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_metadata!['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _metadata!['description']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: '태그',
                labelStyle: TextStyle(color: Colors.grey[600]),
                hintText: '예: 개발, Flutter, 프로그래밍',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: '메모',
                labelStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.link != null ? '수정' : '저장',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
