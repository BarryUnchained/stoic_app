import 'package:flutter/material.dart';

// 标签英文 → 中文映射
const Map<String, String> tagLabels = {
  'action': '行动',
  'mindset': '心智',
  'self-mastery': '自律',
  'time': '时间',
  'relationships': '人际',
  'virtue': '美德',
  'desire': '欲望',
  'resilience': '坚韧',
  'happiness': '幸福',
  'fear': '恐惧',
  'acceptance': '接纳',
  'death': '死亡',
  'anger': '愤怒',
  'freedom': '自由',
  'wisdom': '智慧',
};

class Quote {
  final int id;
  final String english;
  final String chinese;
  final String author;
  final int commentCount;
  final List<String> tags; // ✅ 新增

  const Quote({
    required this.id, 
    required this.english, 
    required this.chinese, 
    required this.author,
    this.commentCount = 0,
    this.tags = const [], // ✅ 默认空列表
  });

  Map<String, dynamic> toJson() => {
    'id': id, 
    'english': english, 
    'chinese': chinese, 
    'author': author,
    'tags': tags,
  };
  
  factory Quote.fromJson(Map<String, dynamic> j) {
    int count = 0;
    if (j['comments'] != null && (j['comments'] as List).isNotEmpty) {
      count = j['comments'][0]['count'] ?? 0;
    }
    
    // ✅ 安全解析 tags，兼容 null 和各种格式
    List<String> parsedTags = [];
    if (j['tags'] != null) {
      if (j['tags'] is List) {
        parsedTags = (j['tags'] as List).map((t) => t.toString()).toList();
      }
    }

    return Quote(
      id: j['id'], 
      english: j['english'] ?? '', 
      chinese: j['chinese'] ?? '', 
      author: j['author'] ?? '',
      commentCount: count,
      tags: parsedTags,
    );
  }

  // 穿透式搜索逻辑
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return english.toLowerCase().contains(q) || 
           chinese.toLowerCase().contains(q) || 
           author.toLowerCase().contains(q);
  }
}

class AppCardTheme {
  final List<Color> gradient;
  final String name;
  const AppCardTheme({required this.gradient, required this.name});
}

const appCardThemes = [
  AppCardTheme(name: '羊皮纸', gradient: [Color(0xFFE8DCC4), Color(0xFFD4C4A8), Color(0xFFC0AD8C)]),
  AppCardTheme(name: '深蓝', gradient: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]),
  AppCardTheme(name: '暗红', gradient: [Color(0xFF1a0000), Color(0xFF3d0000), Color(0xFF600000)]),
  AppCardTheme(name: '纯黑', gradient: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2a2a2a)]),
];