# 整理人生

多分类生活图片管理 App（Flutter + ObjectBox + 腾讯云开发）

## 目录

```
D:\organize-life\
├── cloud\organize_life\     # 腾讯云函数
├── flutter_app\             # Flutter 客户端
└── setup.ps1                # 一键初始化脚本
```

## 快速开始

### 1. 部署云函数

1. 登录 [腾讯云 CloudBase 控制台](https://console.cloud.tencent.com/tcb)
2. 新建云函数 `organize_life`，运行环境 Node.js 16+
3. 上传 `cloud/organize_life/` 目录（含 index.js、package.json）
4. 创建文档型数据库集合：`ol_users`、`ol_categories`、`ol_items`
5. 开启云存储（权限：仅创建者及管理员可读写）
6. 为云函数配置 HTTP 访问服务，记下触发 URL

### 2. 初始化 Flutter 项目

```powershell
powershell -ExecutionPolicy Bypass -File D:\organize-life\setup.ps1
```

### 3. 配置 API 地址

编辑 `flutter_app/lib/data/services/cloud_config.dart`，或通过编译参数传入：

```bash
flutter run --dart-define=CLOUD_API_URL=https://xxx.ap-shanghai.app.tcloudbase.com/organize_life
```

## V1 功能范围

- [x] 7 种预设分类 + 自定义分类
- [x] 拍照/相册上传图片
- [x] 本地 ObjectBox 存储（离线可用）
- [x] 云端同步（腾讯云存储 + 文档数据库）
- [x] 分类内搜索、删除、同步重试

## 后续迭代

- 用户账号登录（替换 deviceId）
- 批量上传、网页导入
- 标签体系、统计图表
- 密码保护、会员体系
