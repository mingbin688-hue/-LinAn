import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../labels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 管理员自助配置云端大模型（OpenAI 兼容接口）。
///
/// 密钥只写不读：页面与服务端响应都只显示尾号；留空保存表示保持已保存的密钥。
class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _base = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _key = TextEditingController();

  bool _enabled = false;
  bool _dirty = false;
  bool _keyVisible = false;
  bool _saving = false;
  bool _testing = false;
  bool _loadingModels = false;
  String? _error;
  String? _modelError;
  Map<String, dynamic>? _test;
  LlmSettings? _synced;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _applyIfAvailable();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyIfAvailable();
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  /// 服务端配置变化时同步表单；用户有未保存输入时不覆盖。
  void _applyIfAvailable() {
    final next = s.llm;
    if (next == null || identical(next, _synced)) return;
    if (_dirty || _saving) return;
    _synced = next;
    _base.text = next.baseUrl;
    _model.text = next.model;
    _enabled = next.requested;
    _key.clear();
    _test = null;
    _error = null;
    _modelError = null;
  }

  void _fail(String message) {
    setState(() => _error = message);
  }

  Future<void> _save() async {
    final base = _base.text.trim();
    final model = _model.text.trim();
    final key = _key.text.trim();
    if (_enabled && base.isEmpty) return _fail('启用模型前请填写基础地址');
    if (_enabled && model.isEmpty) return _fail('启用模型前请填写模型名称');
    if (_enabled && key.isEmpty && !(s.llm?.apiKeySet ?? false)) {
      return _fail('启用模型前请填写 API Key');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await s.saveLlmSettings(
        enabled: _enabled,
        baseUrl: base,
        model: model,
        apiKey: key.isEmpty ? null : key,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _synced = saved;
        _dirty = false;
        _key.clear();
        _test = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请检查后端连接';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    final base = _base.text.trim();
    final model = _model.text.trim();
    if (base.isEmpty || model.isEmpty) return _fail('请先填写基础地址和模型名称');
    setState(() {
      _testing = true;
      _error = null;
      _test = null;
    });
    try {
      final result = await s.testLlmConnection(
        baseUrl: base,
        model: model,
        apiKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
      );
      if (mounted) {
        setState(() {
          _testing = false;
          _test = result;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _test = {'ok': false, 'error': e.message};
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _testing = false;
          _test = {'ok': false, 'error': '连接自检失败，请检查后端连接'};
        });
      }
    }
  }

  Future<void> _clearKey() async {
    final ok = await confirmDialog(
      context,
      title: '清除 API Key',
      body: '清除后模型回到规则模式，已保存的基础地址和模型名称会保留。',
      confirmText: '清除',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await s.saveLlmSettings(
        enabled: false,
        baseUrl: _base.text.trim(),
        model: _model.text.trim(),
        clearKey: true,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _synced = saved;
        _dirty = false;
        _enabled = false;
        _key.clear();
        _test = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final llm = s.llm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final form = _formCard(llm);
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(llm),
            const SizedBox(height: 16),
            _guideCard(),
          ],
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 0, wide ? 28 : 16, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader(
                    title: '设置',
                    subtitle: '云端模型与接入配置 · 仅社区管理员可修改',
                    icon: Icons.settings_rounded,
                  ),
                  _banner(),
                  if (s.llmLoading) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(minHeight: 3, color: LinanColors.primary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: form),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: side),
                      ],
                    )
                  else ...[
                    form,
                    const SizedBox(height: 16),
                    side,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LinanColors.primarySoft.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(Icons.lock_rounded, size: 30, iconSize: 16),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              '云端大模型只查询授权记录、解释证据和生成建议，不改变风险等级，也不能执行派单或关闭操作。'
              'API Key 保存在本机数据库，仅管理员可修改；接口只回传尾号，不会回显明文。',
              style: TextStyle(fontSize: 11, color: LinanColors.primaryDeep, height: 1.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(LlmSettings? llm) {
    return SectionCard(
      title: '云端大模型',
      subtitle: '兼容 OpenAI Chat Completions 的接口；保存后下一次 Agent 运行即使用新配置。',
      icon: Icons.hub_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
            decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconTile(
                  Icons.auto_awesome_rounded,
                  color: _enabled ? LinanColors.green : LinanColors.muted,
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('启用模型解释', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        '关闭后所有 Agent 使用规则结果；数据缺失或调用失败时仍会自动回退，不会生成虚构结论。',
                        style: TextStyle(fontSize: 11.5, height: 1.55, color: LinanColors.muted.withValues(alpha: .95)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _enabled = v;
                            _dirty = true;
                          }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: '基础地址',
            controller: _base,
            hint: 'https://api.deepseek.com/v1',
            helper: '需包含服务商的版本路径；请求会拼接 /chat/completions。',
            enabled: !_saving,
          ),
          const SizedBox(height: 14),
          _field(
            label: '模型名称',
            controller: _model,
            hint: 'deepseek-chat',
            helper: '可从服务商获取后选择，也可手动填写模型 ID。',
            enabled: !_saving,
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving || _loadingModels ? null : _fetchModels,
              icon: _loadingModels
                  ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6))
                  : const Icon(Icons.travel_explore_rounded, size: 16),
              label: Text(_loadingModels ? '获取中…' : '从服务商获取模型'),
            ),
          ),
          if (_modelError != null) ...[
            const SizedBox(height: 8),
            _notice(_modelError!, danger: true),
          ],
          const SizedBox(height: 14),
          _field(
            label: 'API Key',
            controller: _key,
            hint: llm?.apiKeySet == true ? '已保存 ${llm!.apiKeyHint}，留空保持不变' : 'sk-...',
            helper: llm?.apiKeySet == true
                ? '当前密钥：${llm!.apiKeyHint}。新值只在保存时写入，页面不会回显明文。'
                : '密钥仅保存在本机 runtime 数据库，不会写入日志或审计记录。',
            enabled: !_saving,
            obscure: !_keyVisible,
            suffix: IconButton(
              tooltip: _keyVisible ? '隐藏密钥' : '显示输入',
              onPressed: () => setState(() => _keyVisible = !_keyVisible),
              icon: Icon(_keyVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17),
              color: LinanColors.muted,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 12),
            _notice(_error!, danger: true),
          ],
          if (_test != null) ...[
            SizedBox(height: 12),
            _testResult(),
          ],
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(_saving ? '保存中…' : '保存配置'),
              ),
              OutlinedButton.icon(
                onPressed: _saving || _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6))
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(_testing ? '测试中…' : '测试连接'),
              ),
              if (llm?.apiKeySet == true)
                TextButton.icon(
                  onPressed: _saving ? null : _clearKey,
                  icon: Icon(Icons.key_off_outlined, size: 16, color: LinanColors.danger),
                  label: Text('清除密钥', style: TextStyle(color: LinanColors.danger)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '提示：修改配置不会中断正在生成的解释；已保存的事件、任务与审计记录不受影响。',
            style: TextStyle(fontSize: 11, height: 1.6, color: LinanColors.faint),
          ),
        ],
      ),
    );
  }

  /// 用当前表单地址与密钥（或已保存密钥）请求服务商的模型目录。
  Future<void> _fetchModels() async {
    final base = _base.text.trim();
    if (base.isEmpty) return _fail('请先填写基础地址，再获取模型列表');
    final typedKey = _key.text.trim();
    if (typedKey.isEmpty && !(s.llm?.apiKeySet ?? false)) {
      return _fail('请先填写 API Key，再获取模型列表');
    }
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final result = await s.fetchLlmModels(
        baseUrl: base,
        apiKey: typedKey.isEmpty ? null : typedKey,
      );
      if (!mounted) return;
      if (result['ok'] != true) {
        setState(() => _modelError = '${result['error'] ?? '获取模型列表失败，可手动填写模型名称'}');
        return;
      }
      final names = [for (final item in (result['models'] as List? ?? const [])) '$item'];
      if (names.isEmpty) {
        setState(() => _modelError = '服务未返回可用模型，可手动填写模型名称');
        return;
      }
      await _showModels(names);
    } on ApiException catch (e) {
      if (mounted) setState(() => _modelError = e.message);
    } catch (_) {
      if (mounted) setState(() => _modelError = '获取模型列表失败，请检查后端连接');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _showModels(List<String> models) {
    return showSideSheet(
      context,
      title: '选择模型',
      subtitle: '来自服务商 /models，共 ${models.length} 个；也可直接在表单中手动填写。',
      child: _ModelPicker(
        models: models,
        onPick: (name) {
          setState(() {
            _model.text = name;
            _dirty = true;
            _modelError = null;
          });
        },
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String helper,
    bool enabled = true,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: LinanColors.muted),
        ),
        SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => _dirty = true,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
          ),
        ),
        SizedBox(height: 7),
        Text(helper, style: TextStyle(fontSize: 11, height: 1.55, color: LinanColors.faint)),
      ],
    );
  }

  Widget _notice(String text, {bool danger = false}) {
    final color = danger ? LinanColors.danger : LinanColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(danger ? Icons.error_rounded : Icons.check_circle_rounded, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11, height: 1.6, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _testResult() {
    final ok = _test!['ok'] == true;
    if (!ok) return _notice('${_test!['error'] ?? '连接失败'}', danger: true);
    final latency = _test!['latency_ms'];
    final model = _test!['model'];
    final detail = [
      if (latency != null) '$latency ms',
      if (model != null && '$model'.isNotEmpty) '模型：$model',
    ].join(' · ');
    return _notice(detail.isEmpty ? '连接成功' : '连接成功 · $detail');
  }

  Widget _statusCard(LlmSettings? llm) {
    final ready = llm?.configured == true;
    return SectionCard(
      title: '当前状态',
      subtitle: '优先使用本机保存的配置；从未保存过时才回退环境变量。',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(
                llm?.usesModel == true ? '模型解释已启用' : '规则模式',
                color: llm?.usesModel == true ? LinanColors.green : LinanColors.muted,
              ),
              if (llm?.requested == true && !ready)
                Tag('配置不完整', color: LinanColors.amber),
              if (llm != null) Tag('来源：${llm.sourceLabel}'),
            ],
          ),
          const SizedBox(height: 10),
          if (llm == null)
            const EmptyHint('正在读取模型配置…', icon: Icons.settings_ethernet)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              decoration: BoxDecoration(color: LinanColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  KeyValue('运行模式', llm.usesModel ? '云端模型解释' : '规则引擎'),
                  KeyValue('配置完整性', ready ? '地址、模型与密钥齐全' : '缺少基础地址、模型名称或 API Key'),
                  KeyValue('API Key', llm.apiKeySet ? '已保存 ${llm.apiKeyHint}' : '未保存'),
                  KeyValue('配置来源', llm.sourceLabel),
                  KeyValue('上次保存', llm.updatedAt == null ? '—' : formatStamp(llm.updatedAt)),
                  KeyValue('保存人', llm.updatedBy ?? '—'),
                ],
              ),
            ),
          if (llm?.fallbackReason != null) ...[
            const SizedBox(height: 10),
            _notice(llm!.fallbackReason!, danger: true),
          ],
        ],
      ),
    );
  }

  Widget _guideCard() {
    return SectionCard(
      title: '接入说明',
      subtitle: '常见 OpenAI 兼容服务的配置示例。',
      icon: Icons.menu_book_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _example('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat', showDivider: true),
          _example('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus',
              showDivider: true),
          _example('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
          const SizedBox(height: 12),
          Text(
            '· 模型只能解释已有记录并给出建议，风险等级仍由规则与本地模型判断。\n'
            '· 数据缺失、超时或返回格式不合法时自动回退规则结果，并在助手与工作流中标注。\n'
            '· 更换服务商时请同时更新基础地址、模型名称和 API Key。',
            style: TextStyle(fontSize: 11.5, height: 1.8, color: LinanColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _example(String name, String base, String model, {bool showDivider = false}) {
    return ListRow(
      leading: const IconTile(Icons.public_rounded, size: 32, iconSize: 16),
      title: name,
      subtitle: base,
      trailing: Tag(model, color: LinanColors.faint),
      showDivider: showDivider,
    );
  }
}

class _ModelPicker extends StatefulWidget {
  final List<String> models;
  final ValueChanged<String> onPick;
  const _ModelPicker({required this.models, required this.onPick});

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.models
        : widget.models.where((m) => m.toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '搜索模型名称',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const EmptyHint('没有匹配的模型，可在表单中手动填写。', icon: Icons.search_off)
        else
          SizedBox(
            height: 340,
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final name = shown[i];
                return ListRow(
                  leading: const IconTile(Icons.memory_rounded, size: 32, iconSize: 16),
                  title: name,
                  showChevron: true,
                  showDivider: i != shown.length - 1,
                  onTap: () {
                    widget.onPick(name);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
