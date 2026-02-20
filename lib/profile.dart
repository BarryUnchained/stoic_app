import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'config.dart';

class ProfileScreen extends StatefulWidget {
  final String? username;
  final Function(String) onUpdate;
  const ProfileScreen({super.key, required this.username, required this.onUpdate});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.username ?? ''); }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 20) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称不能为空，最多20字'))); return; }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({'id': uid, 'username': name, 'updated_at': DateTime.now().toIso8601String()});
      widget.onUpdate(name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称已更新')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey)),
          const SizedBox(height: 8),
          Center(child: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          
          const SizedBox(height: 32),
          // 新增：我的评论足迹入口
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.forum_outlined, color: Colors.blueGrey),
            title: const Text('我的修行足迹 (评论过的名言)'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCommentsScreen())),
          ),
          const Divider(),
          const SizedBox(height: 16),

          const Text('昵称', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: _controller, maxLength: 20, decoration: const InputDecoration(hintText: '设置你的昵称', border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 16),
          SizedBox(height: 44, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('保存'))),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),
          const Text('关于 Stoic Wisdom', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 12),
          const Text('每日一句斯多葛智慧，帮助你在喧嚣的世界中找到内心的平静。\n\n收录了 Marcus Aurelius、Seneca、Epictetus 三位斯多葛哲学家的 300+ 条经典名言，中英对照。', style: TextStyle(color: Colors.grey, height: 1.6)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => html.window.open('mailto:01barrylee@gmail.com', '_blank'),
            child: const Row(children: [Icon(Icons.mail_outline, size: 18, color: Colors.grey), SizedBox(width: 8), Text('联系作者：01barrylee@gmail.com', style: TextStyle(color: Colors.grey, fontSize: 13))]),
          ),
          const SizedBox(height: 16),
          const Text('Version 2.0', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ============================================================
// 我的评论列表页
// ============================================================
class MyCommentsScreen extends StatefulWidget {
  const MyCommentsScreen({super.key});
  @override
  State<MyCommentsScreen> createState() => _MyCommentsScreenState();
}

class _MyCommentsScreenState extends State<MyCommentsScreen> {
  List<dynamic> _myComments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyComments();
  }

  Future<void> _fetchMyComments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      // 联表查询：查出自己的评论，同时带出对应名言的英文内容
      final data = await supabase
          .from('comments')
          .select('*, quotes(english)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _myComments = data as List<dynamic>; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的足迹')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _myComments.isEmpty 
          ? const Center(child: Text('你还没有留下过任何感悟', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myComments.length,
              itemBuilder: (context, index) {
                final c = _myComments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['quotes']?['english'] ?? '未知名言', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 8),
                        Text(c['content'], style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(c['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}