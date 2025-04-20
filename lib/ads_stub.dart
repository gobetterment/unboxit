import 'package:flutter/material.dart';

// 광고 관련 스텁 클래스들
class MobileAds {
  static MobileAds get instance => MobileAds();
  Future<void> initialize() async {}
}

class NativeAd {
  NativeAd({
    required String adUnitId,
    required String factoryId,
    required dynamic request,
    required dynamic listener,
  });

  void load() {}
  void dispose() {}
}

class AdRequest {
  const AdRequest();
}

class NativeAdListener {
  const NativeAdListener({
    Function(dynamic)? onAdLoaded,
    Function(dynamic, dynamic)? onAdFailedToLoad,
  });
}

class AdWidget extends StatelessWidget {
  const AdWidget({super.key, required dynamic ad});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
