/// 与后端 RULE_VERSION / 云端展示保持一致的文案映射。
const Map<int, String> levelNames = {
  -1: '平稳',
  0: '状态未知',
  1: '关注',
  2: '优先',
  3: '紧急',
};

const Map<String, String> stateNames = {
  'pending': '待确认',
  'dispatched': '已派单',
  'accepted': '已接单',
  'processing': '处理中',
  'review': '待复核',
  'closed': '已关闭',
};

const Map<String, String> skillNames = {
  'phone': '电话核实',
  'visit': '上门走访',
  'device': '设备检查',
};

const Map<String, String> kindNames = {
  'safe': '报平安',
  'contact': '请求联系',
  'sos': '主动求助',
  'away': '确认外出',
  'home': '确认在家',
  'rest': '确认休息',
  'need_help': '需要帮助',
  'unreachable': '核实未获回应',
  'data_offline': '数据源离线',
  'data_online': '数据源恢复',
  'missed_checkin': '未按约定报平安',
  'activity': '活动窗口',
};

const Map<String, String> roleNames = {
  'admin': '社区管理人员',
  'staff': '社区照护人员',
  'family': '关联家属',
  'elder': '老人本人',
};

const Map<String, String> outcomeNames = {
  'safe': '已确认安全',
  'needs_help': '需要进一步帮助',
  'unreachable': '未能联系',
  'data_issue': '数据问题已核查',
};

const Map<String, String> auditNames = {
  'risk_created': '风险事件已建立',
  'risk_updated': '风险判断已更新',
  'dispatch_confirmed': '社区确认派单',
  'task_accept': '负责人接单',
  'task_start': '开始处置',
  'task_reject': '拒单，等待重新推荐',
  'task_feedback': '提交处置反馈',
  'task_followup': '继续跟进',
  'task_close': '人工核实关闭',
  'task_overdue': '任务超时提醒',
};

const Map<String, String> runStatusNames = {
  'queued': '等待执行',
  'running': '执行中',
  'waiting_human': '等待人工',
  'completed': '已完成',
  'failed': '执行失败',
  'stale': '业务已更新',
  'cancelled': '已取消',
};

const Map<String, String> modeNames = {
  'rules': '规则模式',
  'llm': '模型模式',
  'fallback': '规则回退',
};

const Map<String, String> runKindNames = {
  'risk': '风险响应',
  'review': '处置复核',
  'chat': '对话查询',
};

const Map<String, String> agentNames = {
  'context': '上下文整理',
  'risk': '风险解释',
  'dispatch': '调度建议',
  'review': '处置复核',
};

const Map<String, String> categoryNames = {
  'safety': '安全',
  'health': '健康',
  'data': '数据',
  'care': '关怀',
};

String levelName(int level) => levelNames[level] ?? '状态未知';
String stateName(String state) => stateNames[state] ?? state;
String skillName(String? skill) => skillNames[skill] ?? (skill ?? '');
String kindName(String kind) => kindNames[kind] ?? kind;
String outcomeName(String outcome) => outcomeNames[outcome] ?? outcome;
String runStatusName(String status) => runStatusNames[status] ?? status;
String modeName(String? mode) => modeNames[mode ?? ''] ?? (mode ?? '规则模式');
String runKindName(String kind) => runKindNames[kind] ?? kind;

/// 秒级时间戳格式化为「MM-dd HH:mm」，跨年时保留年份。
String formatStamp(num? stamp, {String empty = '暂无记录'}) {
  if (stamp == null) return empty;
  final value = stamp.toInt();
  if (value <= 0) return empty;
  final date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
  final now = DateTime.now();
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final mi = date.minute.toString().padLeft(2, '0');
  if (date.year != now.year) return '${date.year}-$mm-$dd $hh:$mi';
  return '$mm-$dd $hh:$mi';
}

String formatClock(num? stamp) {
  if (stamp == null || stamp <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(stamp.toInt() * 1000);
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String formatToday() {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final now = DateTime.now();
  return '${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
}
