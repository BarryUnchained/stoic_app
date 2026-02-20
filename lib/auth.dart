import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config.dart';
import 'quote_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // 新增确认密码
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) { setState(() => _errorMessage = '请输入邮箱和密码'); return; }
    if (password.length < 6) { setState(() => _errorMessage = '密码至少 6 位'); return; }
    
    // 注册模式下的防呆拦截
    if (_isSignUp && password != _confirmPasswordController.text.trim()) {
      setState(() => _errorMessage = '两次输入的密码不一致'); return; 
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const QuoteScreen()), (r) => false);
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(_isSignUp ? Icons.person_add_alt_1_outlined : Icons.auto_stories_outlined, size: 48, color: _isSignUp ? Colors.blueGrey : Colors.grey),
            const SizedBox(height: 16),
            Text(_isSignUp ? '加入 Stoic 社区' : '欢迎回到宁静', style: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.w300, color: textColor)),
            const SizedBox(height: 8),
            Text(_isSignUp ? '解锁 300+ 完整名言与收藏功能' : '每日斯多葛智慧', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 48),
            TextField(controller: _emailController, decoration: const InputDecoration(hintText: '邮箱', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: '密码（至少6位）', border: OutlineInputBorder()), onSubmitted: (_) => _isSignUp ? null : _handleAuth()),
            
            // 注册模式下才显示的确认密码框
            if (_isSignUp) ...[
              const SizedBox(height: 12),
              TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(hintText: '再次确认密码', border: OutlineInputBorder()), onSubmitted: (_) => _handleAuth()),
            ],

            const SizedBox(height: 20),
            if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
            
            SizedBox(
              width: double.infinity, height: 48, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isSignUp ? (isDark ? Colors.white24 : Colors.black87) : null),
                onPressed: _isLoading ? null : _handleAuth, 
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isSignUp ? '立即注册' : '登录')
              )
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() { _isSignUp = !_isSignUp; _errorMessage = null; _confirmPasswordController.clear(); }), 
              child: Text(_isSignUp ? '已有账号？点此登录' : '没有账号？点此注册')
            ),
          ]),
        ),
      ),
    );
  }
}

class SetUsernameScreen extends StatefulWidget {
  final Function(String) onDone;
  const SetUsernameScreen({super.key, required this.onDone});
  @override
  State<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends State<SetUsernameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称需在 1-20 个字内'))); return;
    }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({'id': uid, 'username': name, 'updated_at': DateTime.now().toIso8601String()});
      widget.onDone(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置昵称'), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('给自己取个名字吧', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            const Text('其他用户会看到这个名字', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 32),
            // 注意：删除了会导致弹窗键盘闪退的 autofocus: true 
            TextField(controller: _controller, maxLength: 20, decoration: const InputDecoration(hintText: '输入昵称', border: OutlineInputBorder(), counterText: ''), onSubmitted: (_) => _save()),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('确认'))),
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('以后再说', style: TextStyle(color: Colors.grey)))),
          ],
        ),
      ),
    );
  }
}