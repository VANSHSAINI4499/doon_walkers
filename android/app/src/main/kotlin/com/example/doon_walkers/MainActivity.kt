package com.example.doon_walkers

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity — required by the health
// package's Health Connect permission flow on Android 14+, which uses
// registerForActivityResult and needs to cast Activity to ComponentActivity.
class MainActivity : FlutterFragmentActivity()
