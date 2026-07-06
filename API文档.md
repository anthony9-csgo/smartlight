# 智慧路灯管理平台 — API 接口文档

- 2.4/2.5/3.4/4.5 接口为硬件/MQTT 网关调用，2.9/3.4 响应中携带 command 字段下发硬件指令，其他接口为前端调用

## 通用约定

| 项目         | 说明                                                                       |
|------------|--------------------------------------------------------------------------|
| **基础路径**   | `http://localhost:8080`                                                  |
| **认证方式**   | 除注册/登录外，所有请求 Header 需携带 `token`（JWT，15分钟有效）                              |
| **统一响应格式** | `{"code": 200, "errorMsg": null, "data": ...}` ，成功 code=200，失败 code=500  |
| **分页参数**   | `page`（从1开始，默认1）、`pageSize`（默认10），返回 `{"total": long, "records": [...]}` |
| **时间格式**   | `yyyy-MM-dd HH:mm:ss`（如 `2026-06-30 10:30:00`）                           |

---

## 1. 用户模块 — `/users`

### 1.1 用户注册

| 项目       | 内容                                                                |
|----------|-------------------------------------------------------------------|
| **URL**  | `POST /users/register`                                            |
| **认证**   | 不需要                                                               |
| **请求体**  | `{"username": "string", "password": "string", "role?": "string"}` |
| **成功返回** | `{"code": 200, "errorMsg": null, "data": "注册成功"}`                 |

| 请求字段     | 类型     | 必填 | 说明                                          |
|----------|--------|----|---------------------------------------------|
| username | string | 是  | 用户名，不可重复                                    |
| password | string | 是  | 密码，BCrypt 加密存储                              |
| role     | string | 否  | 角色：`MUNICIPAL_STAFF`（市政人员，默认）/ `ADMIN`（管理员） |

**作用**：新用户注册，密码 BCrypt 加密，默认角色为市政人员。

---

### 1.2 用户登录

| 项目       | 内容                                                 |
|----------|----------------------------------------------------|
| **URL**  | `POST /users/login`                                |
| **认证**   | 不需要                                                |
| **请求体**  | `{"username": "string", "password": "string"}`     |
| **成功返回** | `{"code": 200, "errorMsg": null, "data": LoginVO}` |

| 请求字段     | 类型     | 必填 | 说明  |
|----------|--------|----|-----|
| username | string | 是  | 用户名 |
| password | string | 是  | 密码  |

| 返回字段 (LoginVO) | 类型     | 说明            |
|----------------|--------|---------------|
| token          | string | JWT 令牌，15分钟有效 |
| userId         | long   | 用户ID          |
| username       | string | 用户名           |
| role           | string | 角色            |

**作用**：验证用户名密码，返回 JWT token，后续请求在 Header 中携带 `token`。

---

## 2. 设备管理 — `/devices`

### 2.1 设备分页列表

| 项目       | 内容                                                              |
|----------|-----------------------------------------------------------------|
| **URL**  | `GET /devices`                                                  |
| **成功返回** | `{"code": 200, "data": {"total": long, "records": [DeviceVO]}}` |

| 请求参数         | 类型     | 必填 | 默认值 | 说明                        |
|--------------|--------|----|-----|---------------------------|
| page         | int    | 是  | 1   | 页码                        |
| pageSize     | int    | 是  | 10  | 每页条数                      |
| deviceName   | string | 否  | —   | 设备名称（模糊搜索）                |
| status       | string | 否  | —   | 开关状态：`ON` / `OFF`         |
| onlineStatus | string | 否  | —   | 在线状态：`ONLINE` / `OFFLINE` |

| 返回字段 (DeviceVO)   | 类型     | 说明                    |
|-------------------|--------|-----------------------|
| id                | long   | 设备ID                  |
| deviceName        | string | 设备名称                  |
| deviceSn          | string | 设备序列号                 |
| status            | string | 开关状态：ON / OFF         |
| onlineStatus      | string | 在线状态：ONLINE / OFFLINE |
| lastHeartbeatTime | string | 最近心跳时间                |
| createdAt         | string | 创建时间                  |

**作用**：分页查询所有路灯设备，支持按名称模糊搜索、按开关/在线状态筛选，按创建时间倒序。

---

### 2.2 设备详情

| 项目       | 内容                                      |
|----------|-----------------------------------------|
| **URL**  | `GET /devices/{id}`                     |
| **成功返回** | `{"code": 200, "data": DeviceDetailVO}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 设备ID |

| 返回字段 (DeviceDetailVO) | 类型     | 说明      |
|-----------------------|--------|---------|
| id                    | long   | 设备ID    |
| deviceName            | string | 设备名称    |
| deviceSn              | string | 设备序列号   |
| status                | string | 开关状态    |
| onlineStatus          | string | 在线状态    |
| lastHeartbeatTime     | string | 最近心跳时间  |
| latestLightIntensity  | number | 最新光照强度值 |
| activeAlarmCount      | long   | 活跃告警数   |
| createdAt             | string | 创建时间    |

**作用**：查看单个设备完整信息，附带最新光照值和活跃告警数量。

---

### 2.3 添加设备

| 项目       | 内容                                               |
|----------|--------------------------------------------------|
| **URL**  | `POST /devices`                                  |
| **请求体**  | `{"deviceName": "string", "deviceSn": "string"}` |
| **成功返回** | `{"code": 200, "data": "添加成功"}`                  |

| 请求字段       | 类型     | 必填 | 说明                    |
|------------|--------|----|-----------------------|
| deviceName | string | 是  | 设备名称                  |
| deviceSn   | string | 是  | 设备序列号（唯一，作为MQTT客户端标识） |

**作用**：注册新路灯设备，校验名称和序列号不为空、序列号不可重复。

---

### 2.4 硬件状态回传

| 项目       | 内容                                       |
|----------|------------------------------------------|
| **URL**  | `POST /devices/status-callback`          |
| **请求体**  | `{"deviceId": long, "status": "string"}` |
| **成功返回** | `{"code": 200, "data": "状态更新成功"}`        |

| 请求字段     | 类型     | 必填 | 说明                |
|----------|--------|----|-------------------|
| deviceId | long   | 是  | 设备ID              |
| status   | string | 是  | 开关状态：`ON` / `OFF` |

**作用**：硬件执行开关指令后回传最终状态，更新设备开关状态字段，自动记录控制日志（source=AUTO）。状态变更后通过 WebSocket 推送
`DEVICE_STATUS_CHANGED`。

---

### 2.5 设备心跳上报（备用）

| 项目       | 内容                                             |
|----------|------------------------------------------------|
| **URL**  | `POST /devices/heartbeat`                      |
| **请求体**  | `{"deviceId": long}`                           |
| **成功返回** | `{"code": 200, "data": {"command": "string"}}` |

| 请求字段     | 类型   | 必填 | 说明   |
|----------|------|----|------|
| deviceId | long | 是  | 设备ID |

| 返回字段    | 类型     | 说明                                       |
|---------|--------|------------------------------------------|
| command | string | 当前固定返回 `NONE`（后续手动控制时可能带回指令） |

**作用**：硬件定期发送心跳信号（备用通道，光照上报已隐式刷新心跳），更新 `lastHeartbeatTime` 和在线状态。若设备此前离线，通过
WebSocket 推送 `DEVICE_ONLINE_STATUS_CHANGED`。响应中统一带回 `command` 字段，与光照上报接口保持一致。服务端另有
`@Scheduled` 定时任务（每 30 秒）扫描超时设备自动标记离线并创建告警。

---

### 2.6 编辑设备

| 项目       | 内容                              |
|----------|---------------------------------|
| **URL**  | `PUT /devices/{id}`             |
| **请求体**  | `{"deviceName": "string"}`      |
| **成功返回** | `{"code": 200, "data": "修改成功"}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 设备ID |

| 请求字段       | 类型     | 必填 | 说明    |
|------------|--------|----|-------|
| deviceName | string | 是  | 新设备名称 |

**作用**：修改设备名称，序列号不可修改。

---

### 2.7 删除设备

| 项目       | 内容                              |
|----------|---------------------------------|
| **URL**  | `DELETE /devices/{id}`          |
| **成功返回** | `{"code": 200, "data": "删除成功"}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 设备ID |

**作用**：物理删除设备，同时清理该设备关联的所有光照记录和告警日志。

---

### 2.8 设备概览统计

| 项目       | 内容                                          |
|----------|---------------------------------------------|
| **URL**  | `GET /devices/statistics`                   |
| **成功返回** | `{"code": 200, "data": DeviceStatisticsVO}` |

| 返回字段 (DeviceStatisticsVO) | 类型   | 说明     |
|---------------------------|------|--------|
| totalCount                | long | 设备总数   |
| onlineCount               | long | 在线设备数  |
| offlineCount              | long | 离线设备数  |
| onCount                   | long | 已开灯设备数 |
| offCount                  | long | 已关灯设备数 |

**作用**：Dashboard 首页设备状态概览统计。

---

### 2.9 手动开关灯控制（预留硬件通知）

| 项目       | 内容                                                              |
|----------|-----------------------------------------------------------------|
| **URL**  | `POST /devices/{id}/switch`                                     |
| **请求体**  | `{"status": "ON|OFF"}`                                          |
| **成功返回** | `{"code": 200, "data": {"command": "string"}}`                  |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 设备ID |

| 请求字段   | 类型     | 必填 | 说明                |
|--------|--------|----|-------------------|
| status | string | 是  | 目标开关状态：`ON` / `OFF` |

| 返回字段    | 类型     | 说明                                  |
|---------|--------|-------------------------------------|
| command | string | `MANUAL_ON` 或 `MANUAL_OFF`（硬件通知通道预留） |

**作用**：前端管理员手动控制路灯开关。后端更新 `devices.status`，记录控制日志（source=MANUAL），通过 WebSocket
推送 `DEVICE_STATUS_CHANGED`。**硬件通知通道预留**——当前 HTTP 响应中返回 command，后续 MQTT 接入后可直接推送至设备。

---

## 3. 光照监测 — `/light-readings`

### 3.1 光照记录分页列表

| 项目       | 内容                                                                     |
|----------|------------------------------------------------------------------------|
| **URL**  | `GET /light-readings`                                                  |
| **成功返回** | `{"code": 200, "data": {"total": long, "records": [LightReadingsVO]}}` |

| 请求参数      | 类型     | 必填 | 默认值 | 说明                        |
|-----------|--------|----|-----|---------------------------|
| page      | int    | 是  | 1   | 页码                        |
| pageSize  | int    | 是  | 10  | 每页条数                      |
| deviceId  | long   | 否  | —   | 设备ID                      |
| startTime | string | 否  | —   | 开始时间（yyyy-MM-dd HH:mm:ss） |
| endTime   | string | 否  | —   | 结束时间（yyyy-MM-dd HH:mm:ss） |

| 返回字段 (LightReadingsVO) | 类型     | 说明    |
|------------------------|--------|-------|
| id                     | long   | 记录ID  |
| deviceId               | long   | 设备ID  |
| deviceName             | string | 设备名称  |
| lightIntensity         | number | 光照强度值 |
| createdAt              | string | 采集时间  |

**作用**：分页查询光照采集记录，支持按设备、时间范围筛选，按采集时间倒序。

---

### 3.2 设备最新光照

| 项目       | 内容                                      |
|----------|-----------------------------------------|
| **URL**  | `GET /light-readings/latest/{deviceId}` |
| **成功返回** | `{"code": 200, "data": LatestLightVO}`  |

| 路径参数     | 类型   | 说明   |
|----------|------|------|
| deviceId | long | 设备ID |

| 返回字段 (LatestLightVO) | 类型     | 说明      |
|----------------------|--------|---------|
| deviceId             | long   | 设备ID    |
| lightIntensity       | number | 最新光照强度值 |
| createdAt            | string | 采集时间    |

**作用**：获取指定设备最新一条光照数据，用于设备详情卡片展示。

---

### 3.3 历史光照趋势

| 项目       | 内容                                      |
|----------|-----------------------------------------|
| **URL**  | `GET /light-readings/trend`             |
| **成功返回** | `{"code": 200, "data": [TrendPointVO]}` |

| 请求参数      | 类型     | 必填 | 说明                        |
|-----------|--------|----|---------------------------|
| deviceId  | long   | 是  | 设备ID                      |
| startTime | string | 是  | 开始时间（yyyy-MM-dd HH:mm:ss） |
| endTime   | string | 是  | 结束时间（yyyy-MM-dd HH:mm:ss） |

| 返回字段 (TrendPointVO) | 类型     | 说明    |
|---------------------|--------|-------|
| time                | string | 采集时间  |
| value               | number | 光照强度值 |

**作用**：查询指定时间范围内的光照变化，按时间升序排列，供前端折线图使用。

---

### 3.4 光照数据上报

| 项目       | 内容                                             |
|----------|------------------------------------------------|
| **URL**  | `POST /light-readings`                         |
| **请求体**  | `{"deviceId": long, "lightIntensity": number}` |
| **成功返回** | `{"code": 200, "data": {"command": "string"}}` |

| 请求字段           | 类型     | 必填 | 说明    |
|----------------|--------|----|-------|
| deviceId       | long   | 是  | 设备ID  |
| lightIntensity | number | 是  | 光照强度值 |

| 返回字段    | 类型     | 说明                                                               |
|---------|--------|------------------------------------------------------------------|
| command | string | 下发给硬件的开关指令：`AUTO_ON`（自动开灯）、`AUTO_OFF`（自动关灯）、`NONE`（无操作） |

**作用**：接收硬件上报的光照数据，写入光照记录表。同时隐式刷新心跳（`onlineStatus=ONLINE` + `lastHeartbeatTime`）。写入后自动执行阈值判定——光照
< 开灯阈值且当前 OFF → 自动开灯（AUTO_ON）；光照 > 关灯阈值且当前 ON → 自动关灯（AUTO_OFF）。判定结果作为 `command`
通过HTTP响应返回给硬件，硬件根据command执行开关动作。若设备此前离线，额外通过 WebSocket `/topic/device-online` 推送上线通知。

---

## 4. 告警管理 — `/alarm-logs`

### 4.1 告警分页列表

| 项目       | 内容                                                                |
|----------|-------------------------------------------------------------------|
| **URL**  | `GET /alarm-logs`                                                 |
| **成功返回** | `{"code": 200, "data": {"total": long, "records": [AlarmLogVO]}}` |

| 请求参数      | 类型     | 必填 | 默认值 | 说明                         |
|-----------|--------|----|-----|----------------------------|
| page      | int    | 是  | 1   | 页码                         |
| pageSize  | int    | 是  | 10  | 每页条数                       |
| deviceId  | long   | 否  | —   | 设备ID                       |
| alarmType | string | 否  | —   | 告警类型（如 `OFFLINE`）          |
| status    | string | 否  | —   | 告警状态：`ACTIVE` / `RESOLVED` |

| 返回字段 (AlarmLogVO) | 类型     | 说明                   |
|-------------------|--------|----------------------|
| id                | long   | 告警ID                 |
| deviceId          | long   | 设备ID                 |
| deviceName        | string | 设备名称                 |
| alarmType         | string | 告警类型                 |
| message           | string | 告警详情                 |
| status            | string | 状态：ACTIVE / RESOLVED |
| createdAt         | string | 告警产生时间               |
| resolvedAt        | string | 解决时间（null 表示未解决）     |

**作用**：分页查询告警记录，支持按设备、类型、状态筛选，按产生时间倒序。

---

### 4.2 告警详情

| 项目       | 内容                                  |
|----------|-------------------------------------|
| **URL**  | `GET /alarm-logs/{id}`              |
| **成功返回** | `{"code": 200, "data": AlarmLogVO}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 告警ID |

**作用**：查看单条告警的完整信息（返回结构与 4.1 相同）。

---

### 4.3 解决告警

| 项目       | 内容                              |
|----------|---------------------------------|
| **URL**  | `PUT /alarm-logs/{id}/resolve`  |
| **成功返回** | `{"code": 200, "data": "处理成功"}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 告警ID |

**作用**：将告警标记为已解决（ACTIVE → RESOLVED），记录解决时间。已解决的告警不可重复操作。

---

### 4.4 告警统计

| 项目       | 内容                                         |
|----------|--------------------------------------------|
| **URL**  | `GET /alarm-logs/statistics`               |
| **成功返回** | `{"code": 200, "data": AlarmStatisticsVO}` |

| 返回字段 (AlarmStatisticsVO) | 类型     | 说明      |
|--------------------------|--------|---------|
| activeCount              | long   | 活跃告警总数  |
| byType                   | array  | 按类型分组统计 |
| byType[].alarmType       | string | 告警类型    |
| byType[].count           | long   | 该类型数量   |

**作用**：Dashboard 告警概览，展示活跃告警总数及按类型分组统计。

---

### 4.5 创建告警

| 项目       | 内容                                                               |
|----------|------------------------------------------------------------------|
| **URL**  | `POST /alarm-logs`                                               |
| **请求体**  | `{"deviceId": long, "alarmType": "string", "message": "string"}` |
| **成功返回** | `{"code": 200, "data": "创建成功"}`                                  |

| 请求字段      | 类型     | 必填 | 说明                                 |
|-----------|--------|----|------------------------------------|
| deviceId  | long   | 是  | 关联设备ID                             |
| alarmType | string | 是  | 告警类型（如 `OFFLINE`、`LIGHT_ABNORMAL`） |
| message   | string | 否  | 告警详情描述                             |

**作用**：由硬件/系统调用，创建一条告警记录（status=ACTIVE）。创建成功后通过 WebSocket 推送 `ALARM_CREATED`。

---

## 5. 阈值配置 — `/threshold-config`

### 5.1 获取阈值

| 项目       | 内容                                         |
|----------|--------------------------------------------|
| **URL**  | `GET /threshold-config`                    |
| **成功返回** | `{"code": 200, "data": ThresholdConfigVO}` |

| 返回字段 (ThresholdConfigVO) | 类型     | 说明               |
|--------------------------|--------|------------------|
| id                       | long   | 配置ID（固定为 1）      |
| lightThresholdOn         | number | 光照开灯阈值（低于此值自动开灯） |
| lightThresholdOff        | number | 光照关灯阈值（高于此值自动关灯） |
| heartbeatTimeout         | int    | 心跳超时秒数（超时判定离线）   |
| updatedAt                | string | 最后更新时间           |

**作用**：获取当前系统的阈值配置参数。

---

### 5.2 更新阈值

| 项目       | 内容                                                                                   |
|----------|--------------------------------------------------------------------------------------|
| **URL**  | `PUT /threshold-config`                                                              |
| **请求体**  | `{"lightThresholdOn": number, "lightThresholdOff": number, "heartbeatTimeout": int}` |
| **成功返回** | `{"code": 200, "data": "更新成功"}`                                                      |

| 请求字段              | 类型     | 必填 | 说明             |
|-------------------|--------|----|----------------|
| lightThresholdOn  | number | 是  | 开灯阈值，必须 < 关灯阈值 |
| lightThresholdOff | number | 是  | 关灯阈值，必须 > 开灯阈值 |
| heartbeatTimeout  | int    | 是  | 心跳超时秒数，必须 > 0  |

**作用**：修改光照自动开关阈值和心跳超时参数。

---

## 6. 控制日志 — `/control-logs`

> `control_logs` 为操作审计日志表，记录所有非幂等（状态变更）操作。command 枚举：`ADD_DEVICE` / `UPDATE_DEVICE` /
`DELETE_DEVICE` / `RESOLVE_ALARM` / `UPDATE_THRESHOLD` / `STATUS_CALLBACK` / `AUTO_ON` / `AUTO_OFF` / `MANUAL_ON` / `MANUAL_OFF`。

### 6.1 控制日志分页列表

| 项目       | 内容                                                                  |
|----------|---------------------------------------------------------------------|
| **URL**  | `GET /control-logs`                                                 |
| **成功返回** | `{"code": 200, "data": {"total": long, "records": [ControlLogVO]}}` |

| 请求参数       | 类型     | 必填 | 默认值 | 说明    |
|------------|--------|----|-----|-------|
| page       | int    | 是  | 1   | 页码    |
| pageSize   | int    | 是  | 10  | 每页条数  |
| deviceId   | long   | 否  | —   | 设备ID  |
| command    | string | 否  | —   | 操作类型  |
| operatorId | long   | 否  | —   | 操作人ID |

| 返回字段 (ControlLogVO) | 类型     | 说明                 |
|---------------------|--------|--------------------|
| id                  | long   | 日志ID               |
| deviceId            | long   | 设备ID（null 表示无关联设备） |
| deviceName          | string | 设备名称               |
| operatorId          | long   | 操作人ID              |
| operatorName        | string | 操作人用户名             |
| command             | string | 操作类型               |
| source              | string | 来源（固定 MANUAL）      |
| result              | string | 结果：SUCCESS / FAIL  |
| createdAt           | string | 操作时间               |

**作用**：分页查询操作审计日志，支持按设备、操作类型、操作人筛选，按时间倒序。

---

### 6.2 控制日志详情

| 项目       | 内容                                    |
|----------|---------------------------------------|
| **URL**  | `GET /control-logs/{id}`              |
| **成功返回** | `{"code": 200, "data": ControlLogVO}` |

| 路径参数 | 类型   | 说明   |
|------|------|------|
| id   | long | 日志ID |

**作用**：查看单条操作日志的完整信息（返回结构与 6.1 相同）。

---

---

## 7. WebSocket 实时推送 — `/ws`

### 7.1 连接方式

| 项目            | 内容                                                                      |
|---------------|-------------------------------------------------------------------------|
| **协议**        | STOMP over WebSocket                                                    |
| **端点**        | `ws://localhost:8080/ws?token={jwt_token}`                              |
| **认证**        | 握手阶段通过 URL 参数 `token` 传递 JWT，由 `WebSocketAuthInterceptor` 校验            |
| **Broker 前缀** | `/topic`（广播）                                                            |
| **消息格式**      | `{"type": "string", "timestamp": "yyyy-MM-dd HH:mm:ss", "data": {...}}` |

### 7.2 推送主题

| 主题                      | 消息类型                           | 触发时机                                                          | 推送数据                                                      |
|-------------------------|--------------------------------|---------------------------------------------------------------|-----------------------------------------------------------|
| `/topic/light-readings` | `LIGHT_REPORTED`               | 硬件上报光照数据（`POST /light-readings`）                              | `LatestLightVO`                                           |
| `/topic/device-status`  | `DEVICE_STATUS_CHANGED`        | 自动开关灯（阈值判定触发）、手动开关灯（`POST /devices/{id}/switch`）、硬件状态回传（`POST /devices/status-callback`） | `{deviceId, deviceName, oldStatus, status}`               |
| `/topic/device-online`  | `DEVICE_ONLINE_STATUS_CHANGED` | 首次光照恢复上线（`POST /light-readings`）、独立心跳恢复上线（`POST /devices/heartbeat`）、心跳超时离线（定时任务） | `{deviceId, deviceName, onlineStatus, lastHeartbeatTime}` |
| `/topic/alarms`         | `ALARM_CREATED`                | 硬件执行失败（`POST /alarm-logs`）、心跳超时离线（定时任务）                        | `AlarmLogVO`                                              |

### 7.3 设计原则

- **硬件侧变更 → WebSocket 推送前端**：前端是被动接收方，不知道硬件何时上报/回传，通过订阅主题实时获取
- **前端用户操作 → HTTP 请求-响应**：前端主动发起，自己知道结果，无需额外推送

---

## 8. 大模型对话 — `/knowledge-chunks`

### 8.1 大模型单轮对话

| 项目       | 内容                                                           |
|----------|--------------------------------------------------------------|
| **URL**  | `POST /knowledge-chunks/chat`                                |
| **请求体**  | `{"message": "string"}`                                      |
| **成功返回** | `{"code": 200, "errorMsg": null, "data": "string（大模型回复内容）"}` |

| 请求字段    | 类型     | 必填 | 说明              |
|---------|--------|----|-----------------|
| message | string | 是  | 用户输入的问题/消息，不可为空 |

| 配置项 (`application-secret.yml`) | 说明                | 示例                       |
|--------------------------------|-------------------|--------------------------|
| `llm.api-key`                  | OpenAI 兼容 API Key | `sk-xxx`                 |
| `llm.base-url`                 | API 地址            | `https://api.openai.com` |
| `llm.model`                    | 模型名称              | `gpt-4o-mini`            |

**作用**：调用 OpenAI 兼容的大模型 API（`/v1/chat/completions`）进行单轮对话。当前版本无上下文记忆、无 RAG
检索，仅实现最简单的单轮调用。后续计划增加对话历史管理和知识库检索增强（RAG）。兼容 OpenAI、DeepSeek、通义千问等所有支持 Chat
Completions 协议的 API。

---

## 附录 A：通用分页返回结构

```json
{
  "code": 200,
  "errorMsg": null,
  "data": {
    "total": 100,
    "records": [
      ...
    ]
  }
}
```

| 字段      | 类型    | 说明      |
|---------|-------|---------|
| total   | long  | 总记录数    |
| records | array | 当前页数据列表 |

## 附录 B：错误返回结构

```json
{
  "code": 500,
  "errorMsg": "错误描述信息",
  "data": null
}
```
