/* Isolated Agent acceptance: run through Verify.ps1 -Browser. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const url = process.env.LINAN_URL;
const output = process.env.LINAN_OUTPUT_DIR;
if (process.env.LINAN_VERIFY_ISOLATED !== '1' || !url || !output) {
  throw new Error('Use Verify.ps1 -Browser to create an isolated database, server and output directory.');
}
const errors = [];
const checks = [];
let browser;

(async () => {
  await fs.mkdir(output, { recursive: true });
  browser = await chromium.launch({ headless: true, ...(process.env.BROWSER_EXECUTABLE ? { executablePath: process.env.BROWSER_EXECUTABLE } : { channel: 'msedge' }) });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1080 } });
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));

  const api = (route, method = 'GET', body) => page.evaluate(async ({ route, method, body }) => {
    const response = await fetch('/api' + route, { method, headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + sessionStorage.getItem('linan_token') }, ...(body ? { body: JSON.stringify(body) } : {}) });
    const value = await response.json();
    if (!response.ok) throw new Error(`${response.status}: ${JSON.stringify(value)}`);
    return value;
  }, { route, method, body });
  const login = async account => {
    if (await page.locator('.app-shell').count()) await page.getByRole('button', { name: '退出并切换身份' }).click();
    await page.locator('.login-form input').nth(0).fill(account);
    await page.locator('.login-form input').nth(1).fill('Demo2026!');
    await page.getByRole('button', { name: /登录守护工作台/ }).click();
    await page.locator('.app-shell').waitFor();
  };
  const nav = name => page.locator('nav button').filter({ hasText: name }).click();
  const ask = async question => {
    await nav('邻安助手');
    const replies = page.getByTestId('assistant-reply');
    const count = await replies.count();
    await page.getByTestId('assistant-input').locator('textarea').fill(question);
    await page.getByTestId('assistant-send').click();
    await page.waitForFunction(previous => document.querySelectorAll('[data-testid="assistant-reply"]').length > previous, count);
    const text = await replies.last().innerText();
    assert(text.trim().length > 8, 'Assistant reply is empty');
    return text;
  };
  const waitTask = async predicate => {
    for (let i = 0; i < 50; i++) {
      const task = (await api('/tasks')).find(predicate);
      if (task) return task;
      await page.waitForTimeout(400);
    }
    throw new Error('Expected task transition did not occur');
  };

  await page.goto(url);
  await login('admin');
  assert.equal((await api('/workflows/settings')).auto_dispatch, false);
  await api('/events', 'POST', { id: 'browser-agent-contact', elder_id: 10, kind: 'contact', source: '隔离浏览器验收' });
  await nav('工作流中心');
  await page.getByTestId('auto-dispatch-switch').click();
  const task = await waitTask(t => t.elder_id === 10 && t.level === 1 && t.state === 'dispatched');
  assert(task.staff_id, 'Automatic dispatch did not select a worker');
  const urgent = (await api('/tasks')).find(t => t.level === 3);
  assert(urgent && urgent.state === 'pending', 'Emergency was automatically dispatched');
  checks.push('管理员开启关注级电话核实自动派单', '紧急任务保留人工确认');
  await page.screenshot({ path: path.join(output, 'workflow-center.png'), fullPage: true });
  const runs = await api('/workflows/runs');
  assert(runs.some(r => r.kind === 'risk'), 'Risk workflow was not recorded');
  const run = await api('/workflows/runs/' + runs.find(r => r.kind === 'risk').id);
  assert(run.nodes.length >= 2 && run.nodes.every(n => n.output), 'Workflow node evidence is missing');
  checks.push('持久化工作流节点与结果');
  await ask('今天哪些老人需要关注？');
  await page.screenshot({ path: path.join(output, 'assistant-admin.png'), fullPage: true });
  checks.push('管理员助手');

  await login('staff' + task.staff_id);
  await ask('我的待办任务有哪些？');
  checks.push('照护人员助手');
  await nav('我的任务');
  let card = page.locator('.task-card').filter({ hasText: task.id });
  await card.waitFor();
  await card.getByRole('button', { name: '接单', exact: true }).click();
  await card.getByRole('button', { name: '开始处理' }).click();
  await card.getByRole('button', { name: '提交处置结果' }).click();
  await page.locator('.el-dialog').filter({ hasText: '提交处置结果' }).locator('textarea').fill('隔离演示电话联系完成，老人已回应并确认安全。');
  await page.getByRole('button', { name: '确认提交', exact: true }).click();

  await login('admin');
  await nav('任务中心');
  card = page.locator('.task-card').filter({ hasText: task.id });
  await card.getByRole('button', { name: '核实并关闭' }).click();
  await page.locator('.el-dialog').filter({ hasText: '核实并关闭事件' }).locator('textarea').fill('管理员已复核隔离演示记录，确认安全后关闭。');
  await page.getByRole('button', { name: '确认提交', exact: true }).click();
  await card.getByText('已关闭', { exact: true }).waitFor();
  await card.getByRole('button', { name: '详情与记录' }).click();
  await page.getByTestId('workflow-node').first().waitFor();
  await page.screenshot({ path: path.join(output, 'agent-task-trace.png'), fullPage: true });
  await page.locator('.el-drawer__close-btn:visible').click();
  checks.push('自动派单后接单、反馈与人工复核关闭', '任务 Agent 建议与运行记录');

  const recommendation = page.waitForResponse(r => r.url().endsWith('/api/dispatch/recommend') && r.request().method() === 'POST');
  await page.getByRole('button', { name: '计算派单建议' }).click();
  const result = await (await recommendation).json();
  assert(result.recommendations.length && result.recommendations[0].level >= 2);
  await page.locator('.recommendation').first().getByRole('button', { name: '确认派单' }).click();
  await page.locator('.el-dialog').filter({ hasText: '协同处置 · 派单建议' }).getByRole('button', { name: '关闭', exact: true }).click();
  checks.push('紧急任务人工确认派单');

  await login('family');
  await ask('王桂兰现在是什么状态？');
  assert.equal((await api('/elders')).length, 1);
  const forbidden = await page.evaluate(async () => (await fetch('/api/assistant/messages', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + sessionStorage.getItem('linan_token') }, body: JSON.stringify({ message: '查询状态', elder_id: 2 }) })).status);
  assert.equal(forbidden, 403);
  checks.push('家属助手及关联对象范围');

  await login('elder');
  await page.setViewportSize({ width: 390, height: 844 });
  await ask('我下一步应该怎么做？');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), false, 'Mobile assistant overflows horizontally');
  await page.screenshot({ path: path.join(output, 'assistant-mobile.png'), fullPage: true });
  checks.push('老人助手与390px手机布局');
  assert.deepEqual(errors, [], 'Browser JavaScript errors');
  await fs.writeFile(path.join(output, 'browser-check.json'), JSON.stringify({ success: true, checks, js_errors: errors, task_id: task.id, desktop: '1440x1080', mobile: '390x844', model_mode: 'rules' }, null, 2));
  console.log(JSON.stringify({ success: true, checks, output }, null, 2));
  await context.close();
})().catch(async error => {
  console.error(error);
  await fs.mkdir(output, { recursive: true }).catch(() => {});
  await fs.writeFile(path.join(output, 'browser-check.json'), JSON.stringify({ success: false, checks, js_errors: errors, error: error.message }, null, 2)).catch(() => {});
  process.exitCode = 1;
}).finally(async () => { if (browser) await browser.close(); });
