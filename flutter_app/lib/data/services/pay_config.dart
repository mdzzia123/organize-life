/// 客户端支付配置（需与微信开放平台 / 支付宝应用一致）
class PayConfig {
  static const String wechatAppId = String.fromEnvironment(
    'WECHAT_APP_ID',
    defaultValue: '',
  );

  /// iOS Universal Link（仅 iOS 需要，Android 可留空）
  static const String wechatUniversalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
    defaultValue: '',
  );
}
