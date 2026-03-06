import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'auth.dart';
import 'admin_login_audit.dart';

class ProfileScreen extends StatefulWidget {
  final String? username;
  final Function(String) onUpdate;
  const ProfileScreen(
      {super.key, required this.username, required this.onUpdate});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// 12个预设头像（emoji）
const List<String> kAvatarList = [
  '🦁',
  '🐺',
  '🦅',
  '🐉',
  '🌊',
  '⚡',
  '🌿',
  '🔥',
  '🌙',
  '☀️',
  '🗿',
  '⚔️',
];

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _defaultAdminEmails = '01barrylee@gmail.com';
  static const String _adminEmailsRaw = String.fromEnvironment(
    'ADMIN_EMAILS',
    defaultValue: _defaultAdminEmails,
  );

  late TextEditingController _controller;
  bool _saving = false;
  String _selectedAvatar = '🦁';
  bool _loadingAvatar = true;

  bool get _isAdmin {
    final email = (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    final allowList = _adminEmailsRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    return allowList.contains(email);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.username ?? '');
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select('avatar')
          .eq('id', uid)
          .maybeSingle();
      if (data != null && data['avatar'] != null) {
        setState(() => _selectedAvatar = data['avatar'] as String);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAvatar = false);
    }
  }

  Future<void> _saveAvatar(String avatar) async {
    setState(() => _selectedAvatar = avatar);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({'id': uid, 'avatar': avatar});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('头像保存失败: $e')));
      }
    }
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 20) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('昵称不能为空，最多20字')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({
        'id': uid,
        'username': name,
        'updated_at': DateTime.now().toIso8601String()
      });
      widget.onUpdate(name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('昵称已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  // ← 新增: 登出功能
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要退出账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认登出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登出失败：$e')),
          );
        }
      }
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择头像',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: kAvatarList
                  .map((emoji) => GestureDetector(
                        onTap: () {
                          _saveAvatar(emoji);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedAvatar == emoji
                                ? const Color(0xFF8B7355).withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                            border: Border.all(
                              color: _selectedAvatar == emoji
                                  ? const Color(0xFF8B7355)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 28))),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ← 新增: 发送邮件（替代 dart:html）
  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: '01barrylee@gmail.com',
      query: Uri.encodeComponent('subject=Stoic Wisdom Feedback'),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请复制邮箱: 01barrylee@gmail.com')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('打开邮件失败: $e')));
      }
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
          // 当前头像
          Center(
            child: GestureDetector(
              onTap: () => _showAvatarPicker(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF8B7355), width: 2),
                ),
                child: Center(
                  child: _loadingAvatar
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(_selectedAvatar,
                          style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
              child: Text('点击更换头像',
                  style: TextStyle(fontSize: 11, color: Colors.grey))),
          const SizedBox(height: 4),
          Center(
              child: Text(email,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),

          const SizedBox(height: 32),

          // ← 新增: 我的修行足迹入口
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.forum_outlined, color: Colors.blueGrey),
            title: const Text('我的修行足迹 (评论过的名言)'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyCommentsScreen())),
          ),
          if (_isAdmin)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.deepPurple),
              title: const Text('后台登录审计'),
              subtitle: const Text('查看登录 IP、时间与设备'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminLoginAuditScreen()),
              ),
            ),
          const Divider(),
          const SizedBox(height: 16),

          const Text('昵称', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
              controller: _controller,
              maxLength: 20,
              decoration: const InputDecoration(
                  hintText: '设置你的昵称',
                  border: OutlineInputBorder(),
                  counterText: '')),
          const SizedBox(height: 16),
          SizedBox(
              height: 44,
              child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('保存'))),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),

          const Text('关于 Stoic Wisdom',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 12),
          const Text(
              '每天一句斯多葛智慧，帮助你在喧嚣的世界中找到内心的平静。\n\n'
              '收录了 Marcus Aurelius、Seneca、Epictetus 三位斯多葛哲学家的 300+ 条经典名言，中英对照。',
              style: TextStyle(color: Colors.grey, height: 1.6)),
          const SizedBox(height: 24),

          // ← 改进: 使用 url_launcher 替代 dart:html
          GestureDetector(
            onTap: _launchEmail,
            child: const Row(children: [
              Icon(Icons.mail_outline, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('联系作者：01barrylee@gmail.com',
                  style: TextStyle(color: Colors.grey, fontSize: 13))
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Version 3.0',
              style: TextStyle(color: Colors.grey, fontSize: 11)),

          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),

          // ← 新增: 登出按钮
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 我的评论列表页面 ← 完整重构
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
      // ← 改进: 联表查询，获取对应的名言信息
      final data = await supabase
          .from('comments')
          .select(
              'id, content, created_at, quotes(id, english, chinese, author)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _myComments = data as List<dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ← 新增: 删除评论功能
  Future<void> _deleteComment(String commentId, int index) async {
    try {
      await supabase.from('comments').delete().eq('id', commentId);

      setState(() => _myComments.removeAt(index));

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('评论已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的足迹')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myComments.isEmpty
              ? const Center(
                  child:
                      Text('你还没有留下过任何感悟', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myComments.length,
                  itemBuilder: (context, index) {
                    final c = _myComments[index];
                    final quote = c['quotes'] as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ← 新增: 原名言背景框
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quote['english'] ?? '未知名言',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '– ${quote['author'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ← 改进: 用户的评论部分
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '我的感悟：',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c['content'],
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.6),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ← 改进: 时间和操作按钮
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(c['created_at']),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                // ← 新增: 删除按钮
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('确认删除'),
                                        content: const Text('删除后无法恢复'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('确认',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteComment(c['id'], index);
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // ← 新增: 日期格式化工具
  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return dt.toString().substring(0, 10);
    } catch (_) {
      return "未知日期";
    }
  }
}
