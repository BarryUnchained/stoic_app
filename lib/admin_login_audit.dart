import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';

class LoginEvent {
  final String userId;
  final String email;
  final String ip;
  final String userAgent;
  final DateTime createdAt;

  const LoginEvent({
    required this.userId,
    required this.email,
    required this.ip,
    required this.userAgent,
    required this.createdAt,
  });

  factory LoginEvent.fromMap(Map<String, dynamic> row) {
    return LoginEvent(
      userId: (row['user_id'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      ip: (row['ip'] ?? '').toString(),
      userAgent: (row['user_agent'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AdminLoginAuditScreen extends StatefulWidget {
  const AdminLoginAuditScreen({super.key});

  @override
  State<AdminLoginAuditScreen> createState() => _AdminLoginAuditScreenState();
}

class _AdminLoginAuditScreenState extends State<AdminLoginAuditScreen> {
  static const String _defaultAdminEmails = '01barrylee@gmail.com';
  static const String _adminEmailsRaw = String.fromEnvironment(
    'ADMIN_EMAILS',
    defaultValue: _defaultAdminEmails,
  );

  final TextEditingController _searchController = TextEditingController();
  final List<LoginEvent> _allEvents = [];
  bool _loading = true;
  String? _error;
  int _daysFilter = 7; // 0=全部, 1=24h, 7, 30

  bool get _isAdmin {
    final email = (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    final allowList = _adminEmailsRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    return allowList.contains(email);
  }

  List<LoginEvent> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final cutoff =
        _daysFilter == 0 ? null : now.subtract(Duration(days: _daysFilter));

    return _allEvents.where((e) {
      if (cutoff != null && e.createdAt.isBefore(cutoff)) return false;
      if (query.isEmpty) return true;
      return e.email.toLowerCase().contains(query) ||
          e.ip.toLowerCase().contains(query) ||
          e.userId.toLowerCase().contains(query) ||
          e.userAgent.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supabase
          .from('login_events')
          .select('user_id, email, ip, user_agent, created_at')
          .order('created_at', ascending: false)
          .limit(500);
      final rows = (data as List)
          .map((e) => LoginEvent.fromMap(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _allEvents
            ..clear()
            ..addAll(rows);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _csvEscape(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final rows = _filteredEvents;
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可导出的记录')),
        );
      }
      return;
    }

    final buffer = StringBuffer()
      ..writeln('user_id,email,ip,user_agent,created_at');
    for (final e in rows) {
      buffer.writeln(
        '${_csvEscape(e.userId)},'
        '${_csvEscape(e.email)},'
        '${_csvEscape(e.ip)},'
        '${_csvEscape(e.userAgent)},'
        '${_csvEscape(e.createdAt.toUtc().toIso8601String())}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 已复制到剪贴板（${rows.length} 条）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('登录审计后台')),
        body: const Center(
          child: Text('无权限访问此页面', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final filtered = _filteredEvents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录审计后台'),
        actions: [
          IconButton(
            tooltip: '复制 CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('加载失败：$_error',
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: '搜索邮箱 / IP / User ID',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _daysFilter,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('24h')),
                              DropdownMenuItem(value: 7, child: Text('7天')),
                              DropdownMenuItem(value: 30, child: Text('30天')),
                              DropdownMenuItem(value: 0, child: Text('全部')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _daysFilter = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '共 ${filtered.length} 条记录（最多拉取最近 500 条）',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('暂无记录',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    e.email.isEmpty ? '(无邮箱)' : e.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('IP: ${e.ip.isEmpty ? '-' : e.ip}'),
                                      Text('时间: ${_fmt(e.createdAt)}'),
                                      Text(
                                        'UA: ${e.userAgent.isEmpty ? '-' : e.userAgent}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'UID: ${e.userId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
