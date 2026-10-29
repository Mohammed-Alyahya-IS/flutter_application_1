import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _apiRequestTimeout = Duration(seconds: 15);

Uri _apiUri(String path) => Uri.parse('$_apiBaseUrl$path');

class _TimeoutHttpClient extends http.BaseClient {
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request).timeout(_apiRequestTimeout);
}

final _apiClient = _TimeoutHttpClient();

void main() {
  runApp(const EstirahahApp());
}

class EstirahahApp extends StatefulWidget {
  const EstirahahApp({super.key});

  @override
  State<EstirahahApp> createState() => _EstirahahAppState();
}

class _EstirahahAppState extends State<EstirahahApp> {
  bool _isDarkMode = false;
  bool _isLoggedIn = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('estirahah_auth_token') ?? '';
    final email = prefs.getString('estirahah_user_email') ?? '';
    final isLoggedIn = prefs.getBool('estirahah_is_logged_in') ?? false;

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = isLoggedIn && token.isNotEmpty && email.isNotEmpty;
    });

    if (!_isLoggedIn) {
      await prefs.remove('estirahah_group_expense_state');
    }
  }

  Future<void> _handleAuthSuccess({
    required String token,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('estirahah_is_logged_in', true);
    await prefs.setString('estirahah_auth_token', token);
    if (email != null && email.isNotEmpty) {
      await prefs.setString('estirahah_user_email', email.trim().toLowerCase());
    }
    await prefs.remove('estirahah_group_expense_state');
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('estirahah_is_logged_in', false);
    await prefs.remove('estirahah_auth_token');
    await prefs.remove('estirahah_user_email');
    await prefs.remove('estirahah_group_expense_state');
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = false;
    });
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFF1D5C55);
    const background = Color(0xFFF8F9FA);
    const panel = Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
          ).copyWith(
            primary: primary,
            surface: panel,
            onSurface: const Color(0xFF1F2937),
            background: background,
          ),
      scaffoldBackgroundColor: background,
      cardTheme: const CardThemeData(
        color: panel,
        elevation: 0,
        shadowColor: Color(0x0D000000),
        surfaceTintColor: panel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE9EEF3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.3),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFFD9E7E3), width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerColor: const Color(0xFFE9EEF3),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: const Color(0xFF1F2937),
        displayColor: const Color(0xFF1F2937),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const bg = Color(0xFF121816);
    const panel = Color(0xFF1E2623);
    const panelAlt = Color(0xFF202B27);
    const accent = Color(0xFF2D6A4F);
    const accentSoft = Color(0xFF9BB9A8);
    const subtleLine = Color(0xFF32413C);
    const softText = Color(0xFFCFD9D4);
    const strongText = Color(0xFFF3F7F5);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ).copyWith(
            background: bg,
            surface: panel,
            surfaceContainerHighest: panelAlt,
            primary: accent,
            secondary: accentSoft,
            onPrimary: strongText,
            onSurface: strongText,
          ),
      scaffoldBackgroundColor: bg,
      cardTheme: const CardThemeData(
        color: panel,
        elevation: 0,
        shadowColor: Color(0x12000000),
        surfaceTintColor: panel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        hintStyle: const TextStyle(color: softText),
        labelStyle: const TextStyle(color: softText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: subtleLine, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentSoft, width: 1.4),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: panel,
        elevation: 1,
        shadowColor: Color(0x66000000),
      ),
      dividerColor: subtleLine,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: strongText,
        displayColor: strongText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة مصاريف المجموعات',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      builder: (context, child) => ScaffoldMessenger(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: _isLoggedIn
          ? HomeScreen(
              onToggleTheme: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
              onLogout: _handleLogout,
            )
          : AuthScreen(
              onToggleTheme: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
              onAuthSuccess: _handleAuthSuccess,
            ),
    );
  }
}

class FirebaseAuthReady {
  static const bool enabled = false;
  static const String provider = 'firebase_auth';

  static Future<void> initialize() async {
    // TODO: await Firebase.initializeApp();
    // TODO: configure FirebaseAuth.instance for future login flows.
  }
}

class GroupMember {
  GroupMember({
    required this.name,
    this.email = '',
    this.walletBalance = 0.0,
    this.amountOwed = 0.0,
    this.amountReceivable = 0.0,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      amountOwed: (json['amountOwed'] as num?)?.toDouble() ?? 0.0,
      amountReceivable: (json['amountReceivable'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String name;
  final String email;
  double walletBalance;
  double amountOwed;
  double amountReceivable;
}

class GroupData {
  GroupData({required this.name, List<GroupMember>? members})
    : members = members ?? <GroupMember>[];

  final String name;
  final List<GroupMember> members;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onToggleTheme,
    required this.onAuthSuccess,
  });

  final VoidCallback onToggleTheme;
  final Future<void> Function({required String token, String? email})
  onAuthSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isSubmitting = false;

  Future<void> submitAuth() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLoginMode && name.isEmpty)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تعبئة كافة الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bodyData = {'name': name, 'email': email, 'password': password};
      print('Current _isLoginMode value is: $_isLoginMode');
      final url = _apiUri(_isLoginMode ? '/api/login' : '/api/register');

      final response = await _apiClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      );

      final data = jsonDecode(response.body);

      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = (data['token'] ?? '').toString();
        final userEmail = (data['user']?['email'] ?? email).toString();

        if (token.isEmpty) {
          throw const FormatException('لم يتم استلام توكن المصادقة');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'تم إنشاء الحساب بنجاح!'),
            backgroundColor: Colors.teal,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 250));
        await widget.onAuthSuccess(token: token, email: userEmail);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'فشل إنشاء الحساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Register request error: $e');
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الاتصال بالسيرفر: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('إدارة المصاريف المشتركة'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E2623) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D5C55).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: Color(0xFF1D5C55),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_isLoginMode)
                      TextField(
                        key: const ValueKey('name_field'),
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'الاسم',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    if (!_isLoginMode) const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('password_field'),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('register_button'),
                        onPressed: _isSubmitting ? null : submitAuth,
                        child: Text(
                          _isSubmitting
                              ? 'جارٍ المعالجة...'
                              : _isLoginMode
                              ? 'دخول'
                              : 'تسجيل',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _isLoginMode ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLoginMode = !_isLoginMode);
                          },
                          child: Text(
                            _isLoginMode ? 'إنشاء حساب' : 'تسجيل الدخول',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<String> _groups = [];
  String _selectedGroup = '';

  final Map<String, GroupData> _groupData = {};
  final Map<String, int> _groupIds = {};

  final List<Map<String, dynamic>> _expenses = [];

  final List<Map<String, dynamic>> _notifications = [];
  final List<Map<String, dynamic>> _invitations = [];
  final Set<int> _respondingInvitationIds = {};
  String _currentUserEmail = '';
  Timer? _invitationRefreshTimer;
  bool _isLoadingInvitations = false;
  bool _isLoadingGroups = false;

  bool _isExpanded = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _receiptPreviewBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clearLocalDashboardState();
    _loadGroupsFromServer();
    _loadInvitationsFromServer();
    _invitationRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadGroupsFromServer();
      _loadInvitationsFromServer(showErrors: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invitationRefreshTimer?.cancel();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadGroupsFromServer();
      _loadInvitationsFromServer(showErrors: false);
    }
  }

  void _clearLocalDashboardState() {
    _groups.clear();
    _selectedGroup = '';
    _groupData.clear();
    _groupIds.clear();
    _expenses.clear();
    _notifications.clear();
    _invitations.clear();
  }

  Future<void> _loadGroupsFromServer() async {
    if (_isLoadingGroups) return;
    _isLoadingGroups = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';
      _currentUserEmail = (prefs.getString('estirahah_user_email') ?? '')
          .trim()
          .toLowerCase();

      if (token.isEmpty) {
        _clearLocalDashboardState();
        return;
      }

      final response = await _apiClient.get(
        _apiUri('/api/groups'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode != 200) {
        _clearLocalDashboardState();
        return;
      }

      final decoded = jsonDecode(response.body);
      final rawGroups = decoded is Map ? decoded['groups'] ?? [] : decoded;

      if (rawGroups is! List) {
        _clearLocalDashboardState();
        return;
      }

      final loadedGroups = <String>[];
      final loadedGroupData = <String, GroupData>{};
      final loadedGroupIds = <String, int>{};
      final loadedExpenses = <Map<String, dynamic>>[];

      for (final item in rawGroups) {
        if (item is! Map) {
          continue;
        }

        final groupName = (item['name'] ?? '').toString().trim();
        if (groupName.isEmpty) {
          continue;
        }

        final groupIdValue = item['id'];
        final parsedGroupId = groupIdValue is num
            ? groupIdValue.toInt()
            : int.tryParse(groupIdValue.toString()) ?? 0;

        loadedGroups.add(groupName);
        if (parsedGroupId > 0) {
          loadedGroupIds[groupName] = parsedGroupId;
        }

        final members = <GroupMember>[];
        final memberList = item['members'];
        if (memberList is List) {
          for (final member in memberList) {
            if (member is! Map) {
              continue;
            }
            members.add(
              GroupMember(
                name:
                    (member['name'] ??
                            member['username'] ??
                            member['email'] ??
                            '')
                        .toString(),
                email: (member['email'] ?? '').toString(),
                walletBalance: _toSafeDouble(member['walletBalance']),
                amountOwed: _toSafeDouble(member['amountOwed']),
                amountReceivable: _toSafeDouble(member['amountReceivable']),
              ),
            );
          }
        }

        loadedGroupData[groupName] = GroupData(
          name: groupName,
          members: members,
        );
      }

      for (final item in rawGroups) {
        if (item is! Map) continue;
        final rawGroupId = item['id'];
        final groupId = rawGroupId is num
            ? rawGroupId.toInt()
            : int.tryParse(rawGroupId.toString()) ?? 0;
        final groupName = (item['name'] ?? '').toString().trim();
        if (groupId <= 0 || groupName.isEmpty) continue;

        try {
          final expensesResponse = await _apiClient.get(
            _apiUri('/api/groups/$groupId/expenses'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (expensesResponse.statusCode != 200) {
            throw const FormatException('Failed to load group expenses');
          }

          final expensesPayload = jsonDecode(expensesResponse.body);
          final rows = expensesPayload is Map
              ? expensesPayload['expenses']
              : null;
          if (rows is! List) {
            throw const FormatException('Invalid group expenses response');
          }

          for (final expense in rows) {
            if (expense is! Map) continue;
            loadedExpenses.add({
              'id': expense['id'],
              'title': expense['title'] ?? '',
              'amount': _toSafeDouble(expense['amount']),
              'person':
                  expense['payer_name'] ?? expense['payer_email'] ?? 'عضو',
              'group': groupName,
              'receiptPath': null,
              'createdAt': expense['created_at'],
            });
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر تحميل مصاريف مجموعة $groupName.')),
            );
          }
        }
      }

      final previouslySelectedGroup = _selectedGroup;
      setState(() {
        _clearLocalDashboardState();
        _groups.addAll(loadedGroups);
        _groupData.addAll(loadedGroupData);
        _groupIds.addAll(loadedGroupIds);
        _expenses.addAll(loadedExpenses);
        if (_groups.contains(previouslySelectedGroup)) {
          _selectedGroup = previouslySelectedGroup;
        } else if (_groups.isNotEmpty) {
          _selectedGroup = _groups.first;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _clearLocalDashboardState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل مجموعاتك من الخادم.')),
      );
    } finally {
      _isLoadingGroups = false;
    }
  }

  Future<void> _loadInvitationsFromServer({bool showErrors = true}) async {
    if (_isLoadingInvitations) return;
    _isLoadingInvitations = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;
        setState(() => _invitations.clear());
        return;
      }

      final response = await _apiClient.get(
        _apiUri('/api/invitations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => _invitations.clear());
        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل الدعوات الواردة.')),
          );
        }
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        setState(() => _invitations.clear());
        return;
      }

      final rows = decoded['invitations'] ?? [];
      if (rows is! List) {
        setState(() => _invitations.clear());
        return;
      }

      final mapped = <Map<String, dynamic>>[];
      for (final item in rows) {
        if (item is! Map) continue;
        mapped.add(Map<String, dynamic>.from(item));
      }

      setState(
        () => _invitations
          ..clear()
          ..addAll(mapped),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _invitations.clear());
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الاتصال بالخادم لتحميل الدعوات.')),
        );
      }
    } finally {
      _isLoadingInvitations = false;
    }
  }

  Future<void> _respondToInvitation({
    required int invitationId,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('estirahah_auth_token') ?? '';

    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول مرة أخرى')),
      );
      return;
    }

    if (_respondingInvitationIds.contains(invitationId)) {
      return;
    }

    setState(() => _respondingInvitationIds.add(invitationId));
    try {
      final response = await _apiClient.post(
        _apiUri('/api/invitations/$invitationId/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      final payload = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _loadGroupsFromServer();
        if (!mounted) return;
        await _loadInvitationsFromServer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(payload['message'] ?? 'تم تحديث الدعوة'),
            backgroundColor: Colors.teal,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(payload['error'] ?? 'تعذر تحديث الدعوة'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الاتصال بالخادم لتحديث الدعوة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingInvitationIds.remove(invitationId));
      }
    }
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'groups': _groups,
      'selectedGroup': _selectedGroup,
      'expenses': _expenses,
      'notifications': _notifications.map((notification) {
        final timestampValue =
            notification['timestamp'] as String? ??
            DateTime.now().toIso8601String();
        final parsedTimestamp =
            _parseTimestamp(timestampValue) ?? DateTime.now();
        return {
          'message': notification['message'] ?? '',
          'time': _formatTimeAgo(parsedTimestamp),
          'timestamp': parsedTimestamp.toIso8601String(),
        };
      }).toList(),
      'groupData': _groupData.entries.map((entry) {
        return {
          'name': entry.key,
          'members': entry.value.members
              .map(
                (member) => {
                  'name': member.name,
                  'walletBalance': member.walletBalance,
                  'amountOwed': member.amountOwed,
                  'amountReceivable': member.amountReceivable,
                },
              )
              .toList(),
        };
      }).toList(),
    };

    try {
      await prefs.setString(
        'estirahah_group_expense_state',
        jsonEncode(payload),
      );
    } catch (_) {
      // Keep current in-memory state and avoid clearing legacy data.
    }
  }

  double _toSafeDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  double _readJsonDouble(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0.0;
  }

  String _formatMoney(dynamic value) {
    return (_toSafeDouble(value)).toStringAsFixed(2);
  }

  DateTime? _parseTimestamp(dynamic rawValue) {
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      try {
        return DateTime.tryParse(rawValue);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) {
      return 'اليوم';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    }
    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    }
    if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    }

    final days = difference.inDays;
    return 'منذ $days يوم';
  }

  void _addActivity(String message) {
    final timestamp = DateTime.now();
    _notifications.insert(0, {
      'message': message,
      'time': _formatTimeAgo(timestamp),
      'timestamp': timestamp.toIso8601String(),
    });
  }

  GroupData? get currentGroup => _groupData[_selectedGroup];
  GroupMember? get currentUserMember {
    for (final member in currentGroup?.members ?? const <GroupMember>[]) {
      if (member.email.trim().toLowerCase() == _currentUserEmail &&
          _currentUserEmail.isNotEmpty) {
        return member;
      }
    }
    return null;
  }

  String get currentUser => currentUserMember?.name ?? '';
  List<String> get currentMembers =>
      currentGroup?.members.map((member) => member.name).toList() ?? [];
  double get currentUserBalance => currentUserMember?.walletBalance ?? 0.0;

  void _showReceiptPreview(String receiptPath, {Uint8List? bytes}) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'معاينة الفاتورة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: (bytes != null)
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Image.file(File(receiptPath), fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRechargeDialog(String memberName) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة رصيد إلى المحفظة'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المراد شحنه',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إضافة الرصيد'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    if (!mounted) return;

    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      return;
    }

    final groupId = _groupIds[_selectedGroup] ?? 0;
    if (groupId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد المجموعة لشحن الرصيد.')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';
      if (token.isEmpty) {
        throw StateError('يجب تسجيل الدخول مرة أخرى');
      }

      final response = await _apiClient.post(
        _apiUri('/api/groups/$groupId/wallet/recharge'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'amount': amount}),
      );
      final payload = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          payload is Map
              ? payload['error']?.toString() ?? 'تعذر شحن المحفظة'
              : 'تعذر شحن المحفظة',
        );
      }

      await _loadGroupsFromServer();
      if (!mounted) return;
      _addActivity(
        'تم شحن محفظة $memberName بمبلغ ${amount.toStringAsFixed(2)} ر.س',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _toSafeDouble(payload['settledAmount']) > 0
                ? 'تم الشحن وسداد ${_formatMoney(_toSafeDouble(payload['settledAmount']))} ر.س من المبالغ المستحقة تلقائياً.'
                : 'تم حفظ الرصيد في المجموعة.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _showCurrentUserRechargeDialog() async {
    if (currentUser.isEmpty) {
      return;
    }
    await _showRechargeDialog(currentUser);
  }

  Future<void> _showAddMemberDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة عضو جديد'),
          content: TextField(
            key: const ValueKey('new_member_email_field'),
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إرسال الدعوة'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final email = controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح')),
      );
      return;
    }

    final groupId = _groupIds[_selectedGroup] ?? 0;
    if (groupId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد المجموعة، حاول مرة أخرى')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول مرة أخرى')),
        );
        return;
      }

      final response = await _apiClient.post(
        _apiUri('/api/groups/$groupId/invite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email}),
      );

      final payload = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadInvitationsFromServer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(payload['message'] ?? 'تم إرسال الدعوة إلى $email'),
            backgroundColor: Colors.teal,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(payload['error'] ?? 'تعذر إرسال الدعوة'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الدعوة، حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _removeMember(String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف العضو'),
          content: Text('هل أنت تأكد من إزالة $memberName من هذه المجموعة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      setState(() {
        final group = _groupData[_selectedGroup];
        if (group == null) {
          return;
        }
        group.members.removeWhere((member) => member.name == memberName);
      });

      await _saveCurrentState();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إزالة العضو "$memberName" من المجموعة')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إزالة العضو، حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _applyWalletTransfer({
    required String sourceGroupName,
    required String targetGroupName,
    required double amount,
  }) async {
    if (sourceGroupName.isEmpty || targetGroupName.isEmpty) {
      return;
    }
    if (sourceGroupName == targetGroupName) {
      return;
    }
    if (amount <= 0) {
      return;
    }

    try {
      final sourceGroup = _groupData[sourceGroupName];
      final targetGroup = _groupData[targetGroupName];
      if (sourceGroup == null || targetGroup == null) {
        return;
      }

      GroupMember? currentUserMemberIn(GroupData group) {
        for (final member in group.members) {
          if (member.email.trim().toLowerCase() == _currentUserEmail &&
              _currentUserEmail.isNotEmpty) {
            return member;
          }
        }
        return null;
      }

      final sourceMember = currentUserMemberIn(sourceGroup);
      final targetMember = currentUserMemberIn(targetGroup);
      if (sourceMember == null || targetMember == null) {
        throw StateError('تعذر العثور على محفظتك في مجموعتي التحويل.');
      }

      final sourceGroupId = _groupIds[sourceGroupName] ?? 0;
      final targetGroupId = _groupIds[targetGroupName] ?? 0;
      if (sourceGroupId <= 0 || targetGroupId <= 0) {
        throw StateError('تعذر تحديد مجموعتي التحويل.');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';
      if (token.isEmpty) {
        throw StateError('يجب تسجيل الدخول مرة أخرى');
      }

      final response = await _apiClient.post(
        _apiUri('/api/wallet/transfer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source_group_id': sourceGroupId,
          'target_group_id': targetGroupId,
          'amount': amount,
        }),
      );
      final payload = jsonDecode(response.body);
      if (!mounted) {
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          payload is Map
              ? payload['error']?.toString() ?? 'تعذر تحويل الرصيد'
              : 'تعذر تحويل الرصيد',
        );
      }

      await _loadGroupsFromServer();
      if (!mounted) return;
      _addActivity(
        'تم تحويل ${amount.toStringAsFixed(2)} ر.س من $sourceGroupName إلى $targetGroupName',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحويل ${amount.toStringAsFixed(2)} ر.س من $sourceGroupName إلى $targetGroupName',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _showWalletTransferDialog() async {
    if (_groups.length < 2) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب وجود محفظتين على الأقل لإجراء التحويل.'),
        ),
      );
      return;
    }

    String sourceGroup = _groups.first;
    String targetGroup = _groups.where((group) => group != sourceGroup).first;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تحويل رصيد بين المحافظ'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: sourceGroup,
                      decoration: const InputDecoration(
                        labelText: 'المحفظة المصدر',
                        border: OutlineInputBorder(),
                      ),
                      items: _groups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(group),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        sourceGroup = value;
                        if (sourceGroup == targetGroup) {
                          targetGroup = _groups
                              .where((group) => group != sourceGroup)
                              .first;
                        }
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: targetGroup,
                      decoration: const InputDecoration(
                        labelText: 'المحفظة الهدف',
                        border: OutlineInputBorder(),
                      ),
                      items: _groups
                          .where((group) => group != sourceGroup)
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(group),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        targetGroup = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المراد تحويله',
                        prefixIcon: Icon(Icons.swap_horiz_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأكيد التحويل'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح أكبر من صفر.')),
      );
      return;
    }

    await _applyWalletTransfer(
      sourceGroupName: sourceGroup,
      targetGroupName: targetGroup,
      amount: amount,
    );
  }

  Future<void> _addExpense(
    String payer, {
    List<String>? splitMembers,
    String? receiptPath,
  }) async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty || payer.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return;
    }

    try {
      final group = _groupData[_selectedGroup];
      if (group == null) {
        return;
      }

      final selectedMembers = (splitMembers ?? currentMembers).toList();
      final finalMembers = selectedMembers.isNotEmpty
          ? selectedMembers
          : currentMembers;

      if (finalMembers.isEmpty) {
        return;
      }

      final groupId = _groupIds[_selectedGroup] ?? 0;
      GroupMember? findMember(String name) {
        for (final member in group.members) {
          if (member.name == name) return member;
        }
        return null;
      }

      final payerMember = findMember(payer);
      final splitEmails = finalMembers
          .map((memberName) => findMember(memberName)?.email)
          .whereType<String>()
          .toList();
      if (groupId <= 0 ||
          payerMember == null ||
          payerMember.email.isEmpty ||
          splitEmails.length != finalMembers.length) {
        throw StateError('تعذر تحديد أعضاء المجموعة لحفظ القطة.');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('estirahah_auth_token') ?? '';
      if (token.isEmpty) {
        throw StateError('يجب تسجيل الدخول مرة أخرى');
      }

      final response = await _apiClient.post(
        _apiUri('/api/groups/$groupId/expenses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'payer_email': payerMember.email,
          'split_emails': splitEmails,
        }),
      );
      final payload = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          payload is Map
              ? payload['error']?.toString() ?? 'تعذر حفظ القطة'
              : 'تعذر حفظ القطة',
        );
      }

      await _loadGroupsFromServer();
      if (!mounted) return;
      _addActivity(
        'قام $payer بإضافة قطة $title بمبلغ ${amount.toStringAsFixed(2)} ر.س',
      );
      _titleController.clear();
      _amountController.clear();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _deleteGroup(int? groupId, String groupName) async {
    final messenger = ScaffoldMessenger.of(context);
    if (groupId == null || groupId <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر العثور على المجموعة المطلوبة.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف المجموعة'),
          content: Text('هل أنت متأكد من حذف مجموعة "$groupName"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final token = prefs.getString('estirahah_auth_token') ?? '';
      if (token.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('انتهت جلسة الدخول. سجّل الدخول مجددًا ثم حاول.'),
          ),
        );
        return;
      }

      final response = await _apiClient.delete(
        _apiUri('/api/groups/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print(response.body);
      print(response.statusCode);

      if (!mounted) return;
      if (response.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'تعذر حذف المجموعة (${response.statusCode}). '
              'قد لا تكون مالكها أو تعذر الوصول إلى الخادم.',
            ),
          ),
        );
        return;
      }

      final wasSelected = _selectedGroup == groupName;
      setState(() {
        _groups.remove(groupName);
        _groupData.remove(groupName);
        _groupIds.remove(groupName);
        _expenses.removeWhere((expense) => expense['group'] == groupName);

        if (_groups.isEmpty) {
          _selectedGroup = '';
        } else if (wasSelected || !_groups.contains(_selectedGroup)) {
          _selectedGroup = _groups.first;
        }
      });
      await _saveCurrentState();
    } catch (error) {
      print('Error deleting group: $error');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالخادم لحذف المجموعة.')),
      );
    }
  }

  void _showAddExpenseSheet() {
    String? payer = currentUser.isNotEmpty
        ? currentUser
        : currentMembers.isNotEmpty
        ? currentMembers.first
        : null;
    final selectedMembers = <String>{...currentMembers};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final splitList = selectedMembers.toList();
            final selectedCount = splitList.length;
            final allSelected =
                currentMembers.isNotEmpty &&
                selectedCount == currentMembers.length;
            String? receiptPath;
            Uint8List? receiptPreviewBytes;
            bool isPickingReceipt = false;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            Future<void> pickReceipt() async {
              if (isPickingReceipt) return;

              setSheetState(() {
                isPickingReceipt = true;
              });

              try {
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  requestFullMetadata: false,
                );

                if (pickedFile == null) {
                  return;
                }

                if (kIsWeb) {
                  final bytes = await pickedFile.readAsBytes();
                  setSheetState(() {
                    receiptPath = pickedFile.name;
                    receiptPreviewBytes = bytes;
                  });
                } else {
                  setSheetState(() {
                    receiptPath = pickedFile.path;
                    receiptPreviewBytes = null;
                  });
                }
              } on Exception catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعذر اختيار الصورة: ${error.toString()}'),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() {
                    isPickingReceipt = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A221E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إضافة قطة جديدة',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFF4F7F5)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? const Color(0xFFEAF5F0) : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleController,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'اسم القطة',
                            prefixIcon: const Icon(Icons.receipt_long_rounded),
                            border: const OutlineInputBorder(),
                            fillColor: isDark ? const Color(0xFF1E2623) : null,
                            filled: isDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'المبلغ الإجمالي',
                            suffixText: 'ر.س',
                            suffixStyle: const TextStyle(
                              color: Color(0xFF9BC7B1),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: const OutlineInputBorder(),
                            fillColor: isDark ? const Color(0xFF1E2623) : null,
                            filled: isDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'دافع القطة',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                            border: const OutlineInputBorder(),
                            fillColor: isDark ? const Color(0xFF1E2623) : null,
                            filled: isDark,
                          ),
                          child: Text(currentUser),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2623)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF37433E)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: CheckboxListTile(
                                    value: allSelected,
                                    title: Text(
                                      'تحديد الكل',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFF3F7F5)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          selectedMembers.addAll(
                                            currentMembers,
                                          );
                                        } else {
                                          selectedMembers.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                ...currentMembers.map(
                                  (member) => Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: selectedMembers.contains(member),
                                      title: Text(
                                        member,
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFF3F7F5)
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      dense: true,
                                      onChanged: (value) {
                                        setSheetState(() {
                                          if (value == true) {
                                            selectedMembers.add(member);
                                          } else {
                                            selectedMembers.remove(member);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isPickingReceipt ? null : pickReceipt,
                            icon: isPickingReceipt
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.attach_file_rounded),
                            label: Text(
                              receiptPath == null
                                  ? (isPickingReceipt
                                        ? 'جارٍ اختيار الصورة...'
                                        : 'إرفاق صورة الفاتورة')
                                  : 'تم إرفاق صورة الفاتورة',
                            ),
                          ),
                        ),
                        if (receiptPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: InkWell(
                              onTap: () {
                                final imageBytes =
                                    receiptPreviewBytes ??
                                    (kIsWeb
                                        ? null
                                        : File(receiptPath!).readAsBytesSync());
                                if (kIsWeb && imageBytes != null) {
                                  _showReceiptPreview(
                                    receiptPath!,
                                    bytes: imageBytes,
                                  );
                                  return;
                                }
                                if (!kIsWeb && receiptPath != null) {
                                  _showReceiptPreview(receiptPath!);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: kIsWeb && receiptPreviewBytes != null
                                      ? Image.memory(
                                          receiptPreviewBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : receiptPath != null
                                      ? Image.file(
                                          File(receiptPath!),
                                          fit: BoxFit.cover,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F362E)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2D6A4F)
                                  : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Text(
                            'التقسيم: ${selectedCount == 0 ? 1 : selectedCount} عضو/أعضاء',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFDDF7E8)
                                  : const Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: payer == null || currentMembers.isEmpty
                                ? null
                                : () => _addExpense(
                                    payer,
                                    splitMembers: selectedMembers.toList(),
                                    receiptPath: receiptPath,
                                  ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('حفظ القطة'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF2D6A4F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddGroupDialog() {
    final nameController = TextEditingController();
    final memberController = TextEditingController();
    final List<String> pendingMembers = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addMember() {
              final value = memberController.text.trim();
              if (value.isEmpty) {
                return;
              }
              if (pendingMembers.contains(value)) {
                return;
              }
              setDialogState(() {
                pendingMembers.add(value);
                memberController.clear();
              });
            }

            return AlertDialog(
              title: const Text('مجموعة جديدة'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const ValueKey('group_name_field'),
                      controller: nameController,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'اسم المجموعة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('member_name_field'),
                            controller: memberController,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => addMember(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const ValueKey('add_member_button'),
                          onPressed: addMember,
                          icon: const Icon(Icons.add_circle_rounded),
                          color: const Color(0xFF0F766E),
                          tooltip: 'إضافة عضو',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pendingMembers.isEmpty)
                      const Text(
                        'لا يوجد أعضاء مضافون بعد',
                        style: TextStyle(color: Color(0xFF64748B)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pendingMembers.map((member) {
                          return InputChip(
                            label: Text(member),
                            onDeleted: () {
                              setDialogState(() {
                                pendingMembers.remove(member);
                              });
                            },
                            deleteIcon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      return;
                    }

                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('estirahah_auth_token') ?? '';
                    if (token.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'يجب تسجيل الدخول مرة أخرى لإنشاء المجموعة.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final response = await _apiClient.post(
                      _apiUri('/api/groups'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({'name': name}),
                    );

                    final payload = jsonDecode(response.body);
                    if (response.statusCode != 201 &&
                        response.statusCode != 200) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              payload['error'] ??
                                  'تعذر إنشاء المجموعة في الخادم.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final groupPayload = payload['group'] is Map
                        ? payload['group'] as Map<String, dynamic>
                        : <String, dynamic>{};
                    final rawGroupId =
                        payload['groupId'] ??
                        payload['id'] ??
                        groupPayload['id'] ??
                        0;
                    int newGroupId = 0;
                    if (rawGroupId is num) {
                      newGroupId = rawGroupId.toInt();
                    } else if (rawGroupId is String) {
                      newGroupId = int.tryParse(rawGroupId) ?? 0;
                    }

                    if (newGroupId != 0) {
                      for (String memberEmail in pendingMembers) {
                        try {
                          await _apiClient.post(
                            _apiUri('/api/groups/$newGroupId/invite'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({'email': memberEmail}),
                          );
                        } catch (_) {
                          // تجاهل الخطأ الفردي للدعوة لكي لا يعطل إنشاء المجموعة
                        }
                      }
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    await _loadGroupsFromServer();
                    await _loadInvitationsFromServer();
                  },
                  child: const Text('إنشاء مجموعة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWalletDisplay = _toSafeDouble(currentUserBalance);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark
        ? const Color(0xFFF3F7F5)
        : const Color(0xFF0F172A);
    final mutedTextColor = isDark
        ? const Color(0xFFB9C8C1)
        : Colors.grey.shade600;
    final cardSurface = isDark ? const Color(0xFF1E2623) : Colors.white;
    final visibleNotifications = _isExpanded
        ? _notifications
        : _notifications.take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C251F).withOpacity(0.95)
                      : const Color(0xFFF4F8F5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D6A4F), Color(0xFF17372B)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D6A4F).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة المصاريف المشتركة',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'المصاريف قطة، والحساب بالملّي',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF355F4B)
                              : const Color(0xFFB7E4CD),
                        ),
                      ),
                      child: IconButton(
                        onPressed: widget.onToggleTheme,
                        icon: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: const Color(0xFF9BC7B1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF355F4B)
                              : const Color(0xFFB7E4CD),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _showAddGroupDialog,
                        icon: const Icon(
                          Icons.group_add_rounded,
                          color: Color(0xFF9BC7B1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF355F4B)
                              : const Color(0xFFB7E4CD),
                        ),
                      ),
                      child: IconButton(
                        onPressed: widget.onLogout,
                        tooltip: 'تسجيل الخروج',
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFF9BC7B1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final groupName = _groups[index];
                    final isSelected = groupName == _selectedGroup;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGroup = groupName),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 170,
                        height: 92,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF1D5C55),
                                    Color(0xFF143A37),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    isDark
                                        ? const Color(0xFF1E2623)
                                        : Colors.white,
                                    isDark
                                        ? const Color(0xFF202B27)
                                        : const Color(0xFFF8F9FA),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    groupName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : sectionTitleColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteGroup(
                                    _groupIds[groupName],
                                    groupName,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  color: isSelected
                                      ? Colors.white
                                      : sectionTitleColor,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              '${_groupData[groupName]?.members.length ?? 0} أعضاء',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white70
                                    : mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D5C55), Color(0xFF143A37)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رصيدي في هذه المجموعة: ${_formatMoney(currentWalletDisplay)} ر.س',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentUserMember != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'المبالغ المستحقة عليّ: ${_formatMoney(currentUserMember!.amountOwed)} ر.س',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المبالغ المستحقة لي: ${_formatMoney(currentUserMember!.amountReceivable)} ر.س',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'المجموعة: $_selectedGroup',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (currentUser.isNotEmpty)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showCurrentUserRechargeDialog,
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        label: const Text('شحن محفظتي في هذه المجموعة'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2D6A4F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showWalletTransferDialog,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('تحويل رصيد بين المحافظ'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: Color(0xFF2D6A4F),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF33463F)
                        : const Color(0xFFE7F0EC),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الدعوات الواردة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'تحديث الدعوات',
                          onPressed: _isLoadingInvitations
                              ? null
                              : () => _loadInvitationsFromServer(),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_invitations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا توجد دعوات معلقة حالياً.',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ..._invitations.map((invitation) {
                        final invitationId =
                            int.tryParse(invitation['id'].toString()) ?? 0;
                        final isResponding = _respondingInvitationIds.contains(
                          invitationId,
                        );
                        final groupName = invitation['group_name'] ?? 'مجموعة';
                        final email = invitation['email'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C251F)
                                : const Color(0xFFF4F8F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'دعوة للانضمام إلى $groupName',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: sectionTitleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email.isNotEmpty ? email : 'بريد مجهول',
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    onPressed: invitationId > 0 && !isResponding
                                        ? () => _respondToInvitation(
                                            invitationId: invitationId,
                                            status: 'accepted',
                                          )
                                        : null,
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('قبول'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: invitationId > 0 && !isResponding
                                        ? () => _respondToInvitation(
                                            invitationId: invitationId,
                                            status: 'rejected',
                                          )
                                        : null,
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('رفض'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'أعضاء المجموعة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: sectionTitleColor,
                    ),
                  ),
                  IconButton(
                    onPressed: _showAddMemberDialog,
                    tooltip: 'إضافة عضو جديد',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    color: const Color(0xFF2D6A4F),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentMembers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final member = currentMembers[index];

                  return Card(
                    margin: EdgeInsets.zero,
                    color: cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2D6A4F)
                                .withOpacity(0.18),
                            child: Icon(
                              Icons.person_rounded,
                              color: const Color(0xFFBFE5D1),
                            ),
                          ),
                          title: Text(
                            member,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'إزالة العضو',
                            onPressed: () => _removeMember(member),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'آخر النشاطات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: sectionTitleColor,
                    ),
                  ),
                  Text(
                    'الكل',
                    style: TextStyle(
                      color: const Color(0xFF9BC7B1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ...visibleNotifications.map((notification) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2D6A4F),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification['message']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: sectionTitleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeAgo(
                                      _parseTimestamp(
                                        notification['timestamp'] ??
                                            notification['time'],
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_notifications.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _isExpanded ? 'عرض الأقل' : 'عرض المزيد',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'قائمة المصاريف',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: sectionTitleColor,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final item = _expenses[index];
                  if (item['group'] != _selectedGroup) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D6A4F),
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sectionTitleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'دفعه: ${item['person']}',
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_toSafeDouble(item['amount']).toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFBFE5D1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B241F).withOpacity(0.9)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 12,
                      color: Color(0xFF2D6A4F),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'صُمم بشغف لإدارة المصاريف المشتركة والقطات ⚡ | قطة © 2026',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showAddExpenseSheet,
        backgroundColor: const Color(0xFF1D5C55),
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
