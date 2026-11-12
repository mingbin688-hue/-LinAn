import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();
  final _server = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _submitting = false;
  bool _serverOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pass.text = demoPassword;
    _server.text = widget.state.displayBase;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.state.login(_user.text, _pass.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '登录失败，请确认后端服务与服务器地址');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _quick(String username) {
    setState(() {
      _user.text = username;
      _pass.text = demoPassword;
      _error = null;
    });
  }

  Future<void> _saveServer() async {
    await widget.state.setBase(_server.text);
    if (!mounted) return;
    setState(() {
      _serverOpen = false;
      _error = null;
    });
    widget.state.toast('服务器地址已保存');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 11, child: _BrandPanel()),
                Expanded(flex: 10, child: Center(child: SingleChildScrollView(child: _form(context)))),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                const _BrandPanel(compact: true),
                Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 34), child: _form(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final bootError = widget.state.bootError?.trim() ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 396),
      margin: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bootError.isNotEmpty) ...[
            _BootErrorBar(message: bootError),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            decoration: BoxDecoration(
              color: LinanColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LinanColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 26, offset: const Offset(0, 10))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('登录邻安', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: LinanColors.text)),
                  const SizedBox(height: 5),
                  const Text('用演示账号进入守护台，所有档案均为虚拟数据。', style: TextStyle(fontSize: 11, color: LinanColors.muted, height: 1.6)),
                  const SizedBox(height: 22),
                  const _FieldLabel('账号'),
                  TextFormField(
                    controller: _user,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 16), hintText: '例如 admin'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '请输入账号' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('密码'),
                  TextFormField(
                    controller: _pass,
                    obscureText: _obscure,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, size: 15),
                      hintText: '演示密码已预填',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 15),
                        color: LinanColors.faint,
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: LinanColors.danger.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: LinanColors.danger.withValues(alpha: .18)),
                      ),
                      child: Text(_error!, style: const TextStyle(fontSize: 11, color: LinanColors.danger, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: _submitting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                        : const Text('进入守护台', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('快速体验身份', style: TextStyle(fontSize: 9.5, color: LinanColors.faint)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in const [
                        ('admin', '管理员'),
                        ('staff1', '照护人员'),
                        ('family', '家属'),
                        ('elder', '老人'),
                      ])
                        ActionChip(
                          label: Text(item.$2, style: const TextStyle(fontSize: 10.5)),
                          onPressed: _submitting ? null : () => _quick(item.$1),
                          backgroundColor: _user.text == item.$1 ? LinanColors.primarySoft : Colors.white,
                          side: BorderSide(color: _user.text == item.$1 ? LinanColors.primary.withValues(alpha: .35) : LinanColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _serverOpen = !_serverOpen),
                      icon: const Icon(Icons.dns_outlined, size: 13),
                      label: const Text('服务器地址'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                    ),
                  ),
                  if (_serverOpen) ...[
                    TextField(
                      controller: _server,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: const InputDecoration(hintText: 'https://your-host 或留空使用默认地址'),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('留空使用默认地址；桌面端默认 http://127.0.0.1:8765',
                              style: TextStyle(fontSize: 9.5, color: LinanColors.faint, height: 1.5)),
                        ),
                        TextButton(onPressed: _saveServer, child: const Text('保存')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text('演示提示：同一虚拟社区内，家属只能查看关联老人，照护人员只能处理自己的任务。',
                      style: TextStyle(fontSize: 9.5, color: LinanColors.faint, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 启动阶段（如后端不可达、会话失效）留下的错误提示，登录成功后由 AppState 清空。
class _BootErrorBar extends StatelessWidget {
  final String message;
  const _BootErrorBar({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LinanColors.danger.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LinanColors.danger.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.cloud_off_outlined, size: 15, color: LinanColors.danger),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 11, color: LinanColors.danger, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 11, color: LinanColors.muted, fontWeight: FontWeight.w500)),
      );
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 22 : 54, compact ? 22 : 54, compact ? 22 : 54, compact ? 22 : 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5A49), Color(0xFF123F33)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Text('安', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('邻安', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.2)),
                  Text('LINAN COMMUNITY GUARD', style: TextStyle(color: Color(0xFF9BC3AF), fontSize: 7.5, letterSpacing: 1.4)),
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 46),
          Text(
            '让每一次异常，\n都有人接住。',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 25 : 37,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: .5,
            ),
          ),
          if (compact) ...[
            const SizedBox(height: 10),
            const Text('虚拟社区演示 · 规则优先，模型只解释证据',
                style: TextStyle(color: Color(0xFFC7DDD1), fontSize: 10.5, height: 1.7)),
            const SizedBox(height: 14),
          ] else ...[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: const Text(
                '把活动感知、风险判断、人员调度与处置复核收进同一条守护链路。规则先行，模型只解释证据；每一个动作都留痕，每一次关闭都要人工核实。',
                style: TextStyle(color: Color(0xFFC7DDD1), fontSize: 11.5, height: 1.9),
              ),
            ),
            const SizedBox(height: 34),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: const [
                _Feature(icon: Icons.sensors_outlined, title: '15 分钟活动感知', desc: '异常先分级再派人'),
                _Feature(icon: Icons.rule_folder_outlined, title: '规则优先分级', desc: 'SOS 不降级、不合并掉'),
                _Feature(icon: Icons.route_outlined, title: '派单与复核闭环', desc: '接单、处置、核实、留痕'),
              ],
            ),
            const SizedBox(height: 40),
            Container(height: 1, color: Colors.white.withValues(alpha: .13)),
            const SizedBox(height: 18),
            const Text('虚拟社区演示 · 数据来自合成档案与公开 CASAS 活动窗口',
                style: TextStyle(color: Color(0xFF8FB6A3), fontSize: 9.5)),
          ],
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _Feature({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFFBFDDCD), size: 14),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Color(0xFF9FC1AF), fontSize: 9, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
