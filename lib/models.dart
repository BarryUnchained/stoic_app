import 'package:flutter/material.dart';

class Quote {
  final int id;
  final String english;
  final String chinese;
  final String author;
  final int commentCount; // 新增字段

  const Quote({
    required this.id, 
    required this.english, 
    required this.chinese, 
    required this.author,
    this.commentCount = 0, // 默认 0 条
  });

  Map<String, dynamic> toJson() => {'id': id, 'english': english, 'chinese': chinese, 'author': author};
  
  factory Quote.fromJson(Map<String, dynamic> j) {
    // 自动解析 Supabase 返回的评论统计
    int count = 0;
    if (j['comments'] != null && (j['comments'] as List).isNotEmpty) {
      count = j['comments'][0]['count'] ?? 0;
    }
    return Quote(
      id: j['id'], 
      english: j['english'], 
      chinese: j['chinese'], 
      author: j['author'],
      commentCount: count,
    );
  }
}

class AppCardTheme {
  final List<Color> gradient;
  final String name;
  const AppCardTheme({required this.gradient, required this.name});
}

const appCardThemes = [
  AppCardTheme(name: '深蓝', gradient: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]),
  AppCardTheme(name: '暗红', gradient: [Color(0xFF1a0000), Color(0xFF3d0000), Color(0xFF600000)]),
  AppCardTheme(name: '墨绿', gradient: [Color(0xFF0a1a0a), Color(0xFF0d2818), Color(0xFF04471C)]),
  AppCardTheme(name: '纯黑', gradient: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2a2a2a)]),
];