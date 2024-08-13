// global.dart
import 'package:flutter/material.dart';

class Global {
  static bool isKorean = true; // 기본 언어 설정
}

// 언어 변경을 위한 간단한 함수
void toggleLanguage() {
  Global.isKorean = !Global.isKorean;
}
