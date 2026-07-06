# 开发日志

所有接口改动记录，按时间倒序排列。

---

## 2026-06-29

### 1. 用户注册

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/users/register` |
| **请求参数** | `{"username": "string", "password": "string", "role?": "string"}` |
| **返回数据** | `{"code": 200, "errorMsg": null, "data": "注册成功"}` |
| **改动文件** | `UsersController.java`, `IUsersService.java`, `UsersServiceImpl.java` |
| **说明** | 新用户注册，密码使用 BCrypt 加密存储。默认角色为 `MUNICIPAL_STAFF`（市政人员），可传入 `ADMIN` 指定为管理员。用户名重复时返回 500 "用户名已存在"。 |

### 2. 用户登录

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/users/login` |
| **请求参数** | `{"username": "string", "password": "string"}` |
| **返回数据** | `{"code": 200, "errorMsg": null, "data": {"token": "string", "userId": long, "username": "string", "role": "string"}}` |
| **改动文件** | `UsersController.java`, `IUsersService.java`, `UsersServiceImpl.java` |
| **说明** | 验证用户名密码，成功后返回 JWT token（15 分钟有效）。后续请求在 Header 中携带 `token` 字段。用户名或密码错误时返回 500 "用户名或密码错误"。返回数据使用 `LoginVO` 封装。 |

### 3. 抽取 LoginVO

| 项目 | 内容 |
|------|------|
| **改动文件** | `vo/LoginVO.java`（新增）, `UsersController.java` |
| **说明** | 将登录接口返回的 `Map<String, Object>` 替换为类型安全的 `LoginVO`（token, userId, username, role），使用 Lombok Builder 模式构造。新增 `com.cqu.vo` 包，后续新增 VO 统一放此包下。 |

---

## 2026-06-30

### 基础设施

#### 4. 修复 DDL 缺陷

| 项目 | 内容 |
|------|------|
| **改动文件** | `sql/schema.sql` |
| **说明** | (1) 修正 `control_logs` 建表语句的表名（原来误写成 `light_readings`）；(2) `control_logs.operator_id` 改为允许 NULL（AUTO 自动指令时无操作人）。 |

#### 5. MyBatis-Plus 分页插件

| 项目 | 内容 |
|------|------|
| **改动文件** | `config/MyBatisPlusConfig.java`（新增） |
| **说明** | 注册 `PaginationInnerInterceptor`（PostgreSQL 方言），启用分页查询能力。 |

#### 6. 新增 VO 类（10 个）

| 项目 | 内容 |
|------|------|
| **改动文件** | `vo/` 包下新增 10 个 VO 类 |
| **说明** | `PageResult<T>` — 通用分页结果（total + records）；`DeviceVO`、`DeviceDetailVO`、`DeviceStatisticsVO` — 设备管理；`LightReadingsVO`、`LatestLightVO`、`TrendPointVO` — 光照监测；`AlarmLogVO`、`AlarmStatisticsVO` — 告警管理；`ThresholdConfigVO` — 阈值配置。 |

---

### 设备管理 — `/devices`

#### 7. 设备分页列表 — `GET /devices`

| 项目 | 内容 |
|------|------|
| **请求参数** | `page`(必填, 默认1), `pageSize`(必填, 默认10), `deviceName`(可选, 模糊搜索), `status`(可选, ON/OFF), `onlineStatus`(可选, ONLINE/OFFLINE) |
| **返回数据** | `{"code": 200, "data": {"total": long, "records": [DeviceVO]}}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 支持按设备名称模糊搜索、按开关状态和在线状态精确筛选。按创建时间倒序排列。 |

#### 8. 设备详情 — `GET /devices/{id}`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": DeviceDetailVO}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 返回设备完整信息，附带最新光照值（`latestLightIntensity`）和活跃告警数（`activeAlarmCount`）。设备不存在时返回 500。 |

#### 9. 添加设备 — `POST /devices`

| 项目 | 内容 |
|------|------|
| **请求体** | `{"deviceName": "string", "deviceSn": "string"}` |
| **返回数据** | `{"code": 200, "data": "添加成功"}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 校验 deviceName 和 deviceSn 不可为空，deviceSn 不可重复。 |

#### 10. 编辑设备 — `PUT /devices/{id}`

| 项目 | 内容 |
|------|------|
| **请求体** | `{"deviceName": "string"}` |
| **返回数据** | `{"code": 200, "data": "修改成功"}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 只允许修改设备名称，序列号不可改。 |

#### 11. 删除设备 — `DELETE /devices/{id}`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": "删除成功"}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 物理删除设备，同时清理该设备关联的所有光照记录和告警日志。 |

#### 12. 设备概览统计 — `GET /devices/statistics`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": {"totalCount": long, "onlineCount": long, "offlineCount": long, "onCount": long, "offCount": long}}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | Dashboard 首页设备状态统计，返回总数、在线/离线数、开灯/关灯数。 |

---

### 光照监测 — `/light-readings`

#### 13. 光照记录分页列表 — `GET /light-readings`

| 项目 | 内容 |
|------|------|
| **请求参数** | `page`(必填, 默认1), `pageSize`(必填, 默认10), `deviceId`(可选), `startTime`(可选, yyyy-MM-dd HH:mm:ss), `endTime`(可选) |
| **返回数据** | `{"code": 200, "data": {"total": long, "records": [LightReadingsVO]}}` |
| **改动文件** | `LightReadingsController.java`, `ILightReadingsService.java`, `LightReadingsServiceImpl.java` |
| **说明** | 按采集时间倒序排列。`LightReadingsVO` 中携带 `deviceName` 避免前端二次查询。 |

#### 14. 设备最新光照 — `GET /light-readings/latest/{deviceId}`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": {"deviceId": long, "lightIntensity": BigDecimal, "createdAt": "string"}}` |
| **改动文件** | `LightReadingsController.java`, `ILightReadingsService.java`, `LightReadingsServiceImpl.java` |
| **说明** | 获取指定设备的最新一条光照数据。无数据时返回 500。 |

#### 15. 历史光照趋势 — `GET /light-readings/trend`

| 项目 | 内容 |
|------|------|
| **请求参数** | `deviceId`(必填), `startTime`(必填), `endTime`(必填) |
| **返回数据** | `{"code": 200, "data": [{"time": "string", "value": BigDecimal}]}` |
| **改动文件** | `LightReadingsController.java`, `ILightReadingsService.java`, `LightReadingsServiceImpl.java` |
| **说明** | 返回指定时间范围内的光照数据，按时间升序排列，供前端折线图使用。 |

#### 16. 光照数据上报 — `POST /light-readings`

| 项目 | 内容 |
|------|------|
| **请求体** | `{"deviceId": long, "lightIntensity": number}` |
| **返回数据** | `{"code": 200, "data": "上报成功"}` |
| **改动文件** | `LightReadingsController.java`, `ILightReadingsService.java`, `LightReadingsServiceImpl.java` |
| **说明** | 接收硬件/MQTT 网关上报的光照数据。自动开关灯判定逻辑后续实现。 |

---

### 告警管理 — `/alarm-logs`

#### 17. 告警分页列表 — `GET /alarm-logs`

| 项目 | 内容 |
|------|------|
| **请求参数** | `page`(必填, 默认1), `pageSize`(必填, 默认10), `deviceId`(可选), `alarmType`(可选), `status`(可选, ACTIVE/RESOLVED) |
| **返回数据** | `{"code": 200, "data": {"total": long, "records": [AlarmLogVO]}}` |
| **改动文件** | `AlarmLogsController.java`, `IAlarmLogsService.java`, `AlarmLogsServiceImpl.java` |
| **说明** | 按产生时间倒序排列。`AlarmLogVO` 中携带 `deviceName`。 |

#### 18. 告警详情 — `GET /alarm-logs/{id}`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": AlarmLogVO}` |
| **改动文件** | `AlarmLogsController.java`, `IAlarmLogsService.java`, `AlarmLogsServiceImpl.java` |
| **说明** | 查看单条告警完整信息。告警不存在时返回 500。 |

#### 19. 解决告警 — `PUT /alarm-logs/{id}/resolve`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": "处理成功"}` |
| **改动文件** | `AlarmLogsController.java`, `IAlarmLogsService.java`, `AlarmLogsServiceImpl.java` |
| **说明** | status 改为 RESOLVED，resolvedAt 设为当前时间。只有 ACTIVE 状态可被解决，已解决的告警重复操作返回 500。 |

#### 20. 告警统计 — `GET /alarm-logs/statistics`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": {"activeCount": long, "byType": [{"alarmType": "string", "count": long}]}}` |
| **改动文件** | `AlarmLogsController.java`, `IAlarmLogsService.java`, `AlarmLogsServiceImpl.java` |
| **说明** | 活跃告警总数 + 按告警类型分组统计。 |

---

### 阈值配置 — `/threshold-config`

#### 21. 获取阈值 — `GET /threshold-config`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": {"id": 1, "lightThresholdOn": BigDecimal, "lightThresholdOff": BigDecimal, "heartbeatTimeout": int, "updatedAt": "string"}}` |
| **改动文件** | `ThresholdConfigController.java`, `IThresholdConfigService.java`, `ThresholdConfigServiceImpl.java` |
| **说明** | 获取当前系统阈值配置（表中仅一行数据，id=1）。 |

#### 22. 更新阈值 — `PUT /threshold-config`

| 项目 | 内容 |
|------|------|
| **请求体** | `{"lightThresholdOn": number, "lightThresholdOff": number, "heartbeatTimeout": int}` |
| **返回数据** | `{"code": 200, "data": "更新成功"}` |
| **改动文件** | `ThresholdConfigController.java`, `IThresholdConfigService.java`, `ThresholdConfigServiceImpl.java` |
| **说明** | 校验：开灯阈值 < 关灯阈值，心跳超时 > 0。参数为空或校验失败返回 500。 |

---

### 控制日志 — `/control-logs`

#### 23. 控制日志分页列表 — `GET /control-logs`

| 项目 | 内容 |
|------|------|
| **请求参数** | `page`(必填, 默认1), `pageSize`(必填, 默认10), `deviceId`(可选), `command`(可选), `operatorId`(可选) |
| **返回数据** | `{"code": 200, "data": {"total": long, "records": [ControlLogVO]}}` |
| **改动文件** | `ControlLogsController.java`, `IControlLogsService.java`, `ControlLogsServiceImpl.java` |
| **说明** | 按操作时间倒序排列。`ControlLogVO` 中携带 `deviceName` 和 `operatorName`。 |

#### 24. 控制日志详情 — `GET /control-logs/{id}`

| 项目 | 内容 |
|------|------|
| **返回数据** | `{"code": 200, "data": ControlLogVO}` |
| **改动文件** | `ControlLogsController.java`, `IControlLogsService.java`, `ControlLogsServiceImpl.java` |
| **说明** | 查看单条操作日志完整信息。 |

#### 25. 操作审计日志回填

| 项目 | 内容 |
|------|------|
| **改动文件** | `DevicesServiceImpl.java`, `AlarmLogsServiceImpl.java`, `ThresholdConfigServiceImpl.java` |
| **说明** | 在设备增删改、解决告警、更新阈值等非幂等操作中，调用 `IControlLogsService.recordLog()` 写入审计日志。command 枚举：`ADD_DEVICE` / `UPDATE_DEVICE` / `DELETE_DEVICE` / `RESOLVE_ALARM` / `UPDATE_THRESHOLD`。operator_id 通过 `UserHolder.getCurrent()` 获取。 |

#### 26. 控制日志增强 — 支持 source 参数

| 项目 | 内容 |
|------|------|
| **请求方式** | 内部调用 |
| **改动文件** | `IControlLogsService.java`, `ControlLogsServiceImpl.java` |
| **说明** | 新增 `recordLog(deviceId, command, result, source)` 重载方法，支持指定操作来源（MANUAL / AUTO）。原 `recordLog` 方法委托到新方法，source 默认 MANUAL。硬件回传/系统自动操作的日志使用 source=AUTO。 |

---

### WebSocket 实时推送

#### 27. WebSocket 基础设施搭建

| 项目 | 内容 |
|------|------|
| **改动文件** | `pom.xml`, `config/WebSocketConfig.java`（新增）, `config/WebSocketAuthInterceptor.java`（新增）, `vo/WebSocketMessage.java`（新增） |
| **说明** | 引入 `spring-boot-starter-websocket` 依赖。基于 STOMP over WebSocket 协议，Broker 前缀 `/topic`/`/queue`，应用前缀 `/app`。STOMP 端点 `/ws`，握手阶段从 URL 参数 `?token=xxx` 校验 JWT。统一消息信封 `WebSocketMessage`（type, timestamp, data）。 |

#### 28. 光照数据上报 → WebSocket 推送

| 项目 | 内容 |
|------|------|
| **触发时机** | 硬件上报光照数据时（`POST /light-readings`） |
| **推送主题** | `/topic/light-readings` |
| **推送数据** | `{"type": "LIGHT_REPORTED", "timestamp": "...", "data": LatestLightVO}` |
| **改动文件** | `LightReadingsServiceImpl.java` |
| **说明** | 光照数据上报保存成功后，通过 `SimpMessagingTemplate.convertAndSend()` 推送到所有订阅 `/topic/light-readings` 的前端客户端。属于硬件侧变更被动通知。 |

---

### 告警管理补充

#### 29. 创建告警 — `POST /alarm-logs`

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/alarm-logs` |
| **请求体** | `{"deviceId": long, "alarmType": "string", "message": "string"}` |
| **返回数据** | `{"code": 200, "data": "创建成功"}` |
| **改动文件** | `AlarmLogsController.java`, `IAlarmLogsService.java`, `AlarmLogsServiceImpl.java` |
| **说明** | 创建告警记录（status=ACTIVE），供硬件/系统调用（如 MQTT 网关检测到设备离线时调用）。创建成功后通过 WebSocket 主题 `/topic/alarms` 推送 `ALARM_CREATED` 消息（数据体为 `AlarmLogVO`），前端可实时收到告警通知。 |

---

### 设备管理补充

#### 30. 硬件状态回传 — `POST /devices/status-callback`

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/devices/status-callback` |
| **请求体** | `{"deviceId": long, "status": "ON|OFF"}` |
| **返回数据** | `{"code": 200, "data": "状态更新成功"}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 硬件执行开关指令后回传最终状态，更新 `devices.status` 字段，自动记录控制日志（command=`STATUS_CALLBACK`, source=AUTO）。状态变更后通过 WebSocket 主题 `/topic/device-status` 推送 `DEVICE_STATUS_CHANGED` 消息（含 oldStatus 和 newStatus）。 |

#### 31. 设备心跳上报 — `POST /devices/heartbeat`

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/devices/heartbeat` |
| **请求体** | `{"deviceId": long}` |
| **返回数据** | `{"code": 200, "data": "心跳接收成功"}` |
| **改动文件** | `DevicesController.java`, `IDevicesService.java`, `DevicesServiceImpl.java` |
| **说明** | 硬件定期发送心跳信号，更新 `lastHeartbeatTime` 和 `onlineStatus=ONLINE`。若设备之前处于离线状态，通过 WebSocket 主题 `/topic/device-online` 推送 `DEVICE_ONLINE_STATUS_CHANGED` 消息。 |

---

### 自动化控制

#### 32. 光照阈值自动开关灯 — 事件驱动

| 项目 | 内容 |
|------|------|
| **触发时机** | 硬件上报光照数据时（`POST /light-readings`），在 `reportReading()` 中实时判定 |
| **改动文件** | `LightReadingsServiceImpl.java` |
| **说明** | 光照数据上报后即时比较阈值：光照 < `lightThresholdOn` 且设备 OFF → 自动开灯（command=`AUTO_ON`）；光照 > `lightThresholdOff` 且设备 ON → 自动关灯（command=`AUTO_OFF`）。操作来源 source=`AUTO`，通过 WebSocket 主题 `/topic/device-status` 推送 `DEVICE_STATUS_CHANGED`。**事件驱动**，来一条数据判一条，不走定时轮询。 |

#### 33. 心跳超时离线检测 — 定时扫描

| 项目 | 内容 |
|------|------|
| **触发时机** | `@Scheduled(fixedRate=30000)` 每 30 秒自动执行 |
| **改动文件** | `schedule/HeartbeatCheckTask.java`（新增）, `SmartStreetLightApplication.java`（添加 `@EnableScheduling`） |
| **说明** | 扫描所有 `onlineStatus=ONLINE` 的设备，若 `lastHeartbeatTime + heartbeatTimeout秒 < now`，则标记为 `OFFLINE`，自动创建 `OFFLINE` 类型告警，并通过 WebSocket 主题 `/topic/device-online` 推送 `DEVICE_ONLINE_STATUS_CHANGED`。从未收到心跳的设备也会被判定离线。 |

---

### 大模型对话 — `/knowledge-chunks`

#### 34. 大模型单轮对话 — `POST /knowledge-chunks/chat`

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/knowledge-chunks/chat` |
| **请求参数** | `{"message": "string"}` |
| **返回数据** | `{"code": 200, "errorMsg": null, "data": "string（大模型回复内容）"}` |
| **改动文件** | `KnowledgeChunksController.java`, `config/LlmConfig.java`（新增）, `vo/ChatRequest.java`（新增）, `application-secret.yml` |
| **说明** | 调用 OpenAI 兼容的大模型 API 进行单轮对话。配置项在 `application-secret.yml` 的 `llm.*` 节点下（api-key / base-url / model）。使用 `RestTemplate` 发送 HTTP 请求，请求格式遵循 `/v1/chat/completions` 规范。当前版本无上下文记忆、无 RAG 检索，仅实现最简单的单轮调用。后续计划增加对话历史和知识库检索增强。 |

---

### 逻辑合并

#### 35. 光照上报合并心跳刷新

| 项目 | 内容 |
|------|------|
| **触发时机** | 硬件上报光照数据时（`POST /light-readings`），同时刷新设备在线状态 |
| **改动文件** | `LightReadingsServiceImpl.java` |
| **说明** | 光照数据上报即视为心跳，在 `reportReading()` 中同步刷新 `onlineStatus=ONLINE` 和 `lastHeartbeatTime`。若设备之前处于离线状态（首次光照），通过 WebSocket 主题 `/topic/device-online` 推送上线通知；后续持续在线则不再重复推送。硬件端可不再单独调用心跳接口，减少一次 HTTP 请求。心跳接口 `/devices/heartbeat` 保留，供无需上报光照的场景（如设备空闲保活）使用。 |

---

## 2026-07-01

### 后端→硬件指令通道

#### 36. 光照上报响应带回开关指令

| 项目 | 内容 |
|------|------|
| **触发时机** | 硬件上报光照数据时（`POST /light-readings`），响应中返回自动判定结果 |
| **改动文件** | `ILightReadingsService.java`, `LightReadingsServiceImpl.java`, `LightReadingsController.java` |
| **说明** | `reportReading()` 返回值由 `void` 改为 `String`，返回 `AUTO_ON` / `AUTO_OFF` / `NONE`。控制器将指令放入响应体 `{"command": "xxx"}` 返回给硬件。硬件根据 command 执行开关动作，无需额外请求。`checkAndAutoControl()` 同步改为返回指令字符串。 |

#### 37. 手动开关灯控制接口（预留硬件通知）

| 项目 | 内容 |
|------|------|
| **请求方式** | `POST` |
| **请求路径** | `/devices/{id}/switch` |
| **请求体** | `{"status": "ON|OFF"}` |
| **返回数据** | `{"code": 200, "data": {"command": "MANUAL_ON|MANUAL_OFF"}}` |
| **改动文件** | `IDevicesService.java`, `DevicesServiceImpl.java`, `DevicesController.java` |
| **说明** | 前端管理员手动控制路灯开关。后端更新 `devices.status`，记录控制日志（source=MANUAL, command=MANUAL_ON/MANUAL_OFF），通过 WebSocket 推送 `DEVICE_STATUS_CHANGED`。**硬件通知通道预留**——当前 HTTP 响应中返回 command，后续 MQTT 接入后可直接推送至设备。 |

#### 38. 心跳上报响应格式统一

| 项目 | 内容 |
|------|------|
| **触发时机** | 硬件发送心跳时（`POST /devices/heartbeat`），响应中统一带回 command 字段 |
| **改动文件** | `DevicesController.java` |
| **说明** | 心跳响应由 `"心跳接收成功"` 改为 `{"command": "NONE"}`，与光照上报接口响应格式对齐。硬件统一解析 command 字段即可，无需区分接口。当前心跳场景固定返回 NONE。 |

