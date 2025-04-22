package com.example.unboxit

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad, null) as NativeAdView

        with(nativeAdView) {
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            val callToActionView = findViewById<Button>(R.id.ad_call_to_action)
            val iconView = findViewById<ImageView>(R.id.ad_icon)
            val advertiserView = findViewById<TextView>(R.id.ad_advertiser)

            headlineView.text = nativeAd.headline
            bodyView.text = nativeAd.body
            callToActionView.text = nativeAd.callToAction
            advertiserView.text = nativeAd.advertiser

            nativeAd.icon?.drawable?.let {
                iconView.setImageDrawable(it)
                iconView.visibility = View.VISIBLE
            } ?: run {
                iconView.visibility = View.GONE
            }

            this.headlineView = headlineView
            this.bodyView = bodyView
            this.callToActionView = callToActionView
            this.iconView = iconView
            this.advertiserView = advertiserView

            this.setNativeAd(nativeAd)
        }

        return nativeAdView
    }
} 