import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'quote_screen.dart';

class PasswordValidator {
  static String? validate(String password) {
    if (password.isEmpty) return '密码不能为空';
    if (password.length < 6) return '密码至少 6 位';
    return null;
  }
}

class EmailValidator {
  static final _regex = RegExp(r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');
  static bool isValid(String email) => _regex.hasMatch(email);
  
  static String? validate(String email) {
    if (email.isEmpty) return '邮箱不能为空';
    if (!isValid(email)) return '请输入有效的邮箱地址';
    return null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    final emailError = EmailValidator.validate(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    
    final pwdError = PasswordValidator.validate(password);
    if (pwdError != null) {
      setState(() => _errorMessage = pwdError);
      return;
    }
    
    if (_isSignUp) {
      if (password != _confirmPasswordController.text.trim()) {
        setState(() => _errorMessage = '两次输入的密码不一致');
        return; 
      }
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        if (kDebugMode) print('📝 尝试注册账户: $email');
        final response = await supabase.auth.signUp(email: email, password: password);
        if (kDebugMode) print('✅ 注册成功，用户ID: ${response.user?.id}');
        if (mounted && response.user != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetUsernameScreen(onDone: (username) {
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const QuoteScreen()), (r) => false);
          })));
          return;
        }
      } else {
        if (kDebugMode) print('🔓 尝试登录账户: $email');
        await supabase.auth.signInWithPassword(email: email, password: password);
        if (kDebugMode) print('✅ 登录成功，用户ID: ${supabase.auth.currentUser?.id}');
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const QuoteScreen()), (r) => false);
        }
      }
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('❌ AuthException 异常');
        print('❌ 错误消息: ${e.message}');
        print('❌ 错误代码: ${e.statusCode}');
        print('❌ 完整错误: ${e.toString()}');
      }
      setState(() => _errorMessage = _mapAuthError(e.message));
    } catch (e) {
      if (kDebugMode) {
        print('❌ 捕获到异常');
        print('❌ 错误类型: ${e.runtimeType}');
        print('❌ 错误内容: $e');
      }
      setState(() => _errorMessage = '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String rawError) {
    if (rawError.contains('already registered') || rawError.contains('already exists')) return '该邮箱已注册';
    if (rawError.contains('Invalid login credentials')) return '邮箱或密码错误';
    if (rawError.contains('Email not confirmed')) return '请先验证邮箱';
    return '认证失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(_isSignUp ? Icons.person_add_alt_1_outlined : Icons.auto_stories_outlined, size: 48),
            const SizedBox(height: 16),
            Text(_isSignUp ? '加入 Stoic 社区' : '欢迎回到家园', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 48),
            TextField(controller: _emailController, decoration: const InputDecoration(hintText: '邮箱', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(hintText: _isSignUp ? '密码（6位以上即可）' : '密码', border: const OutlineInputBorder()), onSubmitted: (_) => _handleAuth()),
            if (_isSignUp) ...[const SizedBox(height: 12), TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(hintText: '再次确认密码', border: OutlineInputBorder()), onSubmitted: (_) => _handleAuth())],
            const SizedBox(height: 20),
            if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _isLoading ? null : _handleAuth, child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : Text(_isSignUp ? '立即注册' : '登录'))),
            const SizedBox(height: 12),
            TextButton(onPressed: () => setState(() { _isSignUp = !_isSignUp; _errorMessage = null; }), child: Text(_isSignUp ? '已有账号？点此登录' : '没有账号？点此注册')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称需在 1-20 个字内')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (kDebugMode) print('💾 保存昵称: $name');
      await supabase.from('profiles').upsert({'id': supabase.auth.currentUser!.id, 'username': name});
      if (kDebugMode) print('✅ 昵称保存成功');
      widget.onDone(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) print('❌ 保存昵称失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置昵称'), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        const Text('给自己取个昵称吧', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 32),
        TextField(controller: _controller, maxLength: 20, decoration: const InputDecoration(hintText: '输入昵称', border: OutlineInputBorder(), counterText: ''), onSubmitted: (_) => _save()),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('确认'))),
      ])),
    );
  }
}
