# 开发日志 - 2026-03-05 Log 持久化

## 背景
本次需求聚焦于日志可追溯性与运维可维护性：
- 将运行日志从内存态改为项目顶层 `logs/` 文件持久化。
- Log Panel 支持读取持久化日志，并在日志较多时保持可滚动浏览。
- 过期日志清理策略由“打开面板自动清理”调整为“用户点击 Refresh 时清理”。

## 主要改动
### 后端
1. 新增日志目录配置 `RST_LOGS_DIR`（默认 `./logs`），并在启动初始化时确保目录存在。
2. 重构 `LogService`：
   - `add_log` 改为写入 `logs/*.json` 文件。
   - 文件名采用：`{日期}{时间}{模型名称}{Main LLM/Sche LLM}{success/error}.json`。
   - 对模型名/状态名做非法文件名字符清洗，避免跨平台写入失败。
   - `get_logs/get_log_by_id` 改为从文件系统读取并反序列化。
3. 新增过期清理能力：按文件修改时间删除超过 7 天日志。
4. 新增接口 `DELETE /logs/expired?retention_days=7` 返回删除数量。
5. 新增模型 `LogCleanupResult` 作为清理接口响应。

### 前端
1. `Log API` 新增 `cleanupExpiredLogs` 请求封装。
2. `log store` 新增 `cleanupExpiredLogs` 方法。
3. `LogPanel` 调整交互：
   - 打开面板时仅拉取日志，不做清理。
   - 点击 `Refresh` 时先清理过期日志，再拉取最新日志。
4. 日志列表补充滚动条样式，避免长列表可用性下降。

### 测试与校验
1. 新增后端测试 `backend/tests/test_log_service.py`，覆盖：
   - 日志落盘
   - 文件名规则关键片段
   - 读取排序
   - 过期清理
2. 回归测试：`test_chat_flow.py::test_logs_include_usage_and_stop_reason` 通过。
3. 前端类型检查：`pnpm -C frontend run type-check` 通过。

## 备注
- 项目已在仓库根目录保留 `logs/.gitkeep`，并通过 `.gitignore` 忽略 `logs/*.json` 运行产物。
- 当前提交未包含 `RSTv0.2.zip`（338MB），该文件超过 GitHub 单文件大小限制，若需纳入版本管理请改用 Git LFS。
