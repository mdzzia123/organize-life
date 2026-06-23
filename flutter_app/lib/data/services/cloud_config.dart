/// 腾讯云 CloudBase 配置
/// 部署云函数后，将 HTTP 触发地址填入此处
class CloudConfig {
  /// 云函数 HTTP 触发 URL（示例）
  /// 格式: https://<env-id>.<region>.app.tcloudbase.com/organize_life
  static const String apiBaseUrl = String.fromEnvironment(
    'CLOUD_API_URL',
    defaultValue:
        'https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life',
  );

  static const String envId = String.fromEnvironment(
    'CLOUD_ENV_ID',
    defaultValue: 'madi-213-8gs6wu0se568f2d1-1302661085',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
