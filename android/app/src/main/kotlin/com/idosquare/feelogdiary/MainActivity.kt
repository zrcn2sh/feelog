package com.idosquare.feelogdiary

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 15 edge-to-edge 기본 동작에 맞춰 시스템 바 인셋 레이아웃을 사용
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
