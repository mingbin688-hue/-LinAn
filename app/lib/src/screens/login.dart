import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
      backgroundColor: LinanColors.bg,
      body: Stack(
        children: [
          const _LoginBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 11, child: Padding(
                        padding: EdgeInsets.fromLTRB(64, 40, 32, 40),
                        child: _BrandPanel(),
                      )),
                      Expanded(
                        flex: 10,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                            child: _form(context),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandPanel(compact: true),
                      const SizedBox(height: 26),
                      Center(child: _form(context)),
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

  Widget _form(BuildContext context) {
    final bootError = widget.state.bootError?.trim() ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 404),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bootError.isNotEmpty) ...[
            _BootErrorBar(message: bootError),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
            decoration: BoxDecoration(
              color: LinanColors.surface.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: LinanColors.separator, width: .8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .07),
                  blurRadius: 44,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('登录邻安',
                      style: TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w700, color: LinanColors.text, letterSpacing: -.6)),
                  const SizedBox(height: 6),
                  Text('用演示账号进入守护台，所有档案均为虚拟数据。',
                      style: TextStyle(fontSize: 12, color: LinanColors.muted, height: 1.6)),
                  const SizedBox(height: 24),
                  const _FieldLabel('账号'),
                  TextFormField(
                    controller: _user,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                      hintText: '例如 admin',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '请输入账号' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  _FieldLabel('密码'),
                  TextFormField(
                    controller: _pass,
                    obscureText: _obscure,
                    style: TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                      hintText: '演示密码已预填',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? '显示密码' : '隐藏密码',
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17),
                        color: LinanColors.faint,
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 14),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: LinanColors.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_rounded,
                              size: 15, color: LinanColors.danger),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(fontSize: 11.5, color: LinanColors.danger, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: _submitting
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('进入守护台', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('快速体验身份',
                            style: TextStyle(fontSize: 11, color: LinanColors.faint, letterSpacing: .2)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in [
                        ('admin', '管理员'),
                        ('staff1', '照护人员'),
                        ('family', '家属'),
                        ('elder', '老人'),
                      ])
                        _QuickChip(
                          label: item.$2,
                          selected: _user.text == item.$1,
                          onTap: _submitting ? null : () => _quick(item.$1),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _serverOpen = !_serverOpen),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.dns_outlined, size: 14, color: LinanColors.muted),
                            const SizedBox(width: 6),
                            Text('服务器地址',
                                style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Icon(_serverOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 17, color: LinanColors.faint),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_serverOpen) ...[
                    TextField(
                      controller: _server,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(hintText: 'https://your-host 或留空使用默认地址'),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text('留空使用默认地址；桌面端默认 http://127.0.0.1:8765',
                              style: TextStyle(fontSize: 11, color: LinanColors.faint, height: 1.5)),
                        ),
                        TextButton(onPressed: _saveServer, child: const Text('保存')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('演示提示：同一虚拟社区内，家属只能查看关联老人，照护人员只能处理自己的任务。',
                      style: TextStyle(fontSize: 11, color: LinanColors.faint, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LinanColors.bgTop, LinanColors.bg, LinanColors.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -180,
              left: -120,
              child: _Glow(color: LinanColors.primary.withValues(alpha: .13), size: 520),
            ),
            Positioned(
              bottom: -200,
              right: -140,
              child: _Glow(color: LinanColors.teal.withValues(alpha: .10), size: 480),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BootErrorBar extends StatelessWidget {
  final String message;
  const _BootErrorBar({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LinanColors.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LinanColors.danger.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.cloud_off_outlined, size: 16, color: LinanColors.danger),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 11.5, color: LinanColors.danger, height: 1.5)),
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
        padding: EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: TextStyle(fontSize: 11.5, color: LinanColors.muted, fontWeight: FontWeight.w600, letterSpacing: .1)),
      );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _QuickChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LinanColors.primarySoft : LinanColors.surfaceAlt,
      borderRadius: BorderRadius.circular(LinanColors.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinanColors.rPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? LinanColors.primary : LinanColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 42 : 46,
              height: compact ? 42 : 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [LinanColors.brandTop, LinanColors.primary, LinanColors.brandDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: LinanColors.primary.withValues(alpha: .30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.health_and_safety_rounded, size: compact ? 23 : 25, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('邻安',
                    style: TextStyle(
                        fontSize: compact ? 19 : 21,
                        fontWeight: FontWeight.w700,
                        color: LinanColors.text,
                        letterSpacing: -.4,
                        height: 1.2)),
                Text('LINAN COMMUNITY GUARD',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: LinanColors.faint, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        SizedBox(height: compact ? 18 : 48),
        Text(
          '让每一次异常，\n都有人接住。',
          style: TextStyle(
            color: LinanColors.text,
            fontSize: compact ? 27 : 46,
            fontWeight: FontWeight.w700,
            height: 1.24,
            letterSpacing: compact ? -.8 : -1.6,
          ),
        ),
        SizedBox(height: compact ? 10 : 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            compact
                ? '虚拟社区演示 · 规则优先，模型只解释证据'
                : '把活动感知、风险判断、人员调度与处置复核收进同一条守护链路。规则先行，模型只解释证据；每一个动作都留痕，每一次关闭都要人工核实。',
            style: TextStyle(fontSize: compact ? 11.5 : 13, color: LinanColors.muted, height: 1.8),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 34),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Feature(icon: Icons.sensors_rounded, title: '15 分钟活动感知', desc: '异常先分级再派人'),
              _Feature(icon: Icons.rule_rounded, title: '规则优先分级', desc: 'SOS 不降级、不合并掉'),
              _Feature(icon: Icons.route_rounded, title: '派单与复核闭环', desc: '接单、处置、核实、留痕'),
            ],
          ),
          const SizedBox(height: 40),
          Container(width: 44, height: 1, color: LinanColors.border),
          SizedBox(height: 16),
          Text('虚拟社区演示 · 数据来自合成档案与公开 CASAS 活动窗口',
              style: TextStyle(fontSize: 11.5, color: LinanColors.faint)),
        ],
      ],
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
    return Container(
      width: 206,
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LinanColors.surface.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LinanColors.separator, width: .7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, size: 30, iconSize: 16),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: LinanColors.text, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.35)),
                SizedBox(height: 2),
                Text(desc, style: TextStyle(color: LinanColors.muted, fontSize: 11, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
