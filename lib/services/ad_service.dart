import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 테스트 광고 ID
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  // 실제 광고 ID (주석 처리)
  // static const String _bannerAdUnitId = 'ca-app-pub-4555376722439841-8618376521';
  // static const String _rewardedAdUnitId = 'ca-app-pub-4555376722439841/4196153462';
  // static const String _nativeAdUnitId = 'ca-app-pub-4555376722439841/1569990120';

  RewardedAd? _rewardedAd;
  NativeAd? _nativeAd;
  int _savedCount = 0;
  int _maxSaves = 10;

  int get remainingSaves => _maxSaves - _savedCount;
  bool canSaveMore() => remainingSaves > 0;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          print('리워드 광고 로드 성공');
        },
        onAdFailedToLoad: (error) {
          print('리워드 광고 로드 실패: $error');
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      await loadRewardedAd();
      if (_rewardedAd == null) return false;
    }

    bool rewardGranted = false;
    await _rewardedAd!.show(
      onUserEarnedReward: (_, reward) async {
        rewardGranted = true;
        await _updateUserMaxSaves(_maxSaves + 10);
      },
    );

    _rewardedAd = null;
    await loadRewardedAd();
    return rewardGranted;
  }

  Future<void> _updateUserMaxSaves(int newMax) async {
    _maxSaves = newMax;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('user_settings')
          .upsert({'user_id': user.id, 'max_saves': newMax});
    }
  }

  Future<void> loadUserMaxSaves() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .single();

      _maxSaves = response['max_saves'] ?? 10;
    }
  }

  void incrementSavedCount() {
    _savedCount++;
  }

  Future<void> loadNativeAd() async {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          print('네이티브 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('네이티브 광고 로드 실패: $error');
          ad.dispose();
        },
        onAdOpened: (ad) => print('네이티브 광고 열림'),
        onAdClosed: (ad) => print('네이티브 광고 닫힘'),
      ),
    );

    await _nativeAd?.load();
  }

  String get bannerAdUnitId => _bannerAdUnitId;
  NativeAd? get nativeAd => _nativeAd;

  void disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _nativeAd?.dispose();
  }
}
