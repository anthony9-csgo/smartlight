# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

智慧路灯管理平台 — 基于 Spring Boot 的后端服务，提供路灯设备管理、光照数据监测、自动/手动控制、告警管理和 RAG 智能问答功能。

## 技术栈

| 组件 | 版本 |
|------|------|
| Spring Boot | 3.5.9 |
| Java | 21 |
| PostgreSQL | (pgvector 扩展) |
| MyBatis-Plus | 3.5.15 |
| Hutool | 5.8.40 |
| jjwt | 0.11.5 |
| Lombok | 1.18.40 |
| pgvector | 0.1.6 |

## 构建与运行

```bash
# 编译项目
mvn compile

# 运行测试
mvn test

# 运行单个测试类
mvn test -Dtest=SmartStreetLightApplicationTests

# 启动应用（开发环境）
mvn spring-boot:run

# 打包
mvn package -DskipTests
```

## 项目结构

```
src/main/java/com/cqu/
├── SmartStreetLightApplication.java    # 启动类（@EnableScheduling）
├── config/
│   ├── GlobalExceptionHandler.java     # 全局异常处理，返回 Result.fail
│   ├── MyBatisPlusConfig.java          # MyBatis-Plus 分页插件
│   ├── TokenInterceptor.java           # JWT 拦截器，从请求头 token 字段解析用户
│   ├── WebMvcConfiguration.java        # 注册拦截器，排除 /users/register 和 /users/login
│   ├── WebSocketConfig.java            # STOMP over WebSocket 配置
│   └── WebSocketAuthInterceptor.java   # WebSocket 握手阶段 JWT 校验
├── controller/                         # REST 控制器（6 个模块）
│   ├── UsersController.java            # 注册/登录
│   ├── DevicesController.java          # 设备 CRUD + 状态回传 + 心跳
│   ├── LightReadingsController.java    # 光照数据上报/查询/趋势
│   ├── AlarmLogsController.java        # 告警 CRUD + 统计
│   ├── ThresholdConfigController.java  # 阈值配置
│   └── ControlLogsController.java      # 审计日志
├── entity/                             # 实体类，使用 MyBatis-Plus 注解
├── mapper/                             # MyBatis-Plus BaseMapper 接口
├── schedule/
│   └── HeartbeatCheckTask.java         # 心跳超时检测定时任务（@Scheduled 30s）
├── service/
│   ├── I*Service.java                  # 服务接口，继承 IService<T>
│   └── impl/*ServiceImpl.java          # 服务实现，继承 ServiceImpl<Mapper, Entity>
├── vo/                                 # 视图对象 + WebSocketMessage
└── utils/
    ├── Result.java                     # 统一响应体 {code, errorMsg, data}
    ├── UserHolder.java                 # ThreadLocal 存储当前用户 ID
    ├── JwtProperties.java              # JWT 创建/解析，15 分钟过期，HmacSHA256
    └── PgVectorTypeHandler.java        # pgvector ↔ float[] 类型转换器

src/main/resources/
├── application.yml                     # 主配置（数据源、MyBatis-Plus、日志）
├── application-secret.yml              # 敏感配置（密码、JWT密钥），已 gitignore
└── mapper/                             # MyBatis XML 映射文件（7 个）

sql/
└── schema.sql                          # 完整 DDL，含注释
```

## 架构要点

- **三层分层**：Controller → Service → Mapper，MyBatis-Plus 的 `ServiceImpl` 提供了通用 CRUD
- **认证机制**：JWT 拦截器（`TokenInterceptor`），除注册/登录外所有请求需带 `token` 请求头，用户 ID 通过 `UserHolder.getCurrent()` 获取。WebSocket 握手阶段通过 URL 参数 `?token=xxx` 校验 JWT
- **双通道通信**：
  - **前端操作 → HTTP 请求-响应**：用户主动发起的操作（CRUD、手动控制等）走 REST 接口
  - **硬件变更 → WebSocket 推送前端**：硬件上报数据/回传状态后，服务端通过 STOMP over WebSocket 实时推送（4 个全局主题：`/topic/light-readings`、`/topic/device-status`、`/topic/device-online`、`/topic/alarms`）
- **自动化控制**：
  - **光照阈值自动开关**：事件驱动，`reportReading()` 中实时比较光照值与阈值，低于开灯阈值自动开灯、高于关灯阈值自动关灯
  - **心跳超时离线检测**：`@Scheduled(fixedRate=30s)` 定时任务，扫描超时设备自动标记离线并创建告警
- **统一响应**：所有接口返回 `Result<T>`，成功 `Result.success(data)`，失败 `Result.fail(msg)`
- **pgvector 集成**：`KnowledgeChunks` 实体的 `embedding` 字段（1024 维向量）通过 `PgVectorTypeHandler` 自动与 pgvector 的 `vector` 类型转换
- **配置分离**：数据库密码、JWT 密钥等敏感信息在 `application-secret.yml`（需手动创建，不入库）

## 数据库

- 7 张业务表：`users`, `devices`, `light_readings`, `control_logs`, `threshold_config`, `alarm_logs`, `knowledge_chunks`
- 序列号自增使用 `BIGSERIAL`，所有 ID 类型为 `Long`
- `threshold_config` 为单行配置表，`sql/schema.sql` 已预置默认值
- `light_readings` 为时序数据，按 `device_id` 分组
- pgvector 向量索引（IVFFlat）需先灌数据再创建

## 关键约定

- 数据库字段使用下划线命名，MyBatis-Plus 自动映射到驼峰实体属性（`map-underscore-to-camel-case: true`）
- Entity 类必须 `implements Serializable`，使用 `@TableId(value = "id", type = IdType.NONE)`（数据库自增）
- `knowledge_chunks.embedding` 字段必须标注 `@TableField(typeHandler = PgVectorTypeHandler.class)`
- Maven 编译不跳过测试时需 PostgreSQL + pgvector 可用，否则用 `-DskipTests`

## 当前状态

核心业务接口已全部实现：

- **用户模块**：注册/登录（JWT 认证）
- **设备管理**：CRUD、概览统计、硬件状态回传、心跳上报
- **光照监测**：数据上报（含阈值自动开关灯）、分页查询、实时趋势
- **告警管理**：创建（系统触发）、分页查询、解决、统计
- **阈值配置**：获取/更新开关阈值和心跳超时参数
- **控制日志**：审计查询（`ADD_DEVICE` / `UPDATE_DEVICE` / `DELETE_DEVICE` / `RESOLVE_ALARM` / `UPDATE_THRESHOLD` / `STATUS_CALLBACK` / `AUTO_ON` / `AUTO_OFF`）
- **WebSocket 实时推送**：光照数据 / 设备状态变更 / 在线状态变更 / 新告警通知
- **定时任务**：`HeartbeatCheckTask` 每 30 秒扫描心跳超时设备

尚未实现：MQTT 网关（硬件直接对接 HTTP，未来可迁至 MQTT）、RAG 智能问答。

## 开发日志

**所有接口改动必须同步记录到 `dev-log.md`**，包含：改动时间、接口名称、请求方法/路径、请求参数、返回数据、改动说明。每次修改 Controller/Service 后务必更新该文件。
