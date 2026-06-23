import 'package:fluwx/fluwx.dart';
import 'package:tobias/tobias.dart';

import 'pay_config.dart';

class PaymentService {
  PaymentService({Fluwx? fluwx, Tobias? tobias})
      : _fluwx = fluwx ?? Fluwx(),
        _tobias = tobias ?? Tobias();

  final Fluwx _fluwx;
  final Tobias _tobias;
  bool _wechatReady = false;

  Future<void> initWechat() async {
    final appId = PayConfig.wechatAppId;
    if (appId.isEmpty) return;
    _wechatReady = await _fluwx.registerApi(
      appId: appId,
      doOnAndroid: true,
      doOnIOS: true,
      universalLink: PayConfig.wechatUniversalLink,
    );
  }

  Future<bool> payWechat(Map<String, dynamic> params) async {
    if (!_wechatReady && PayConfig.wechatAppId.isNotEmpty) {
      await initWechat();
    }
    final ts = int.tryParse(params['timestamp']?.toString() ?? '') ?? 0;
    return _fluwx.pay(
      which: Payment(
        appId: params['appid']?.toString() ?? PayConfig.wechatAppId,
        partnerId: params['partnerid']?.toString() ?? '',
        prepayId: params['prepayid']?.toString() ?? '',
        packageValue: params['package']?.toString() ?? 'Sign=WXPay',
        nonceStr: params['noncestr']?.toString() ?? '',
        timestamp: ts,
        sign: params['sign']?.toString() ?? '',
      ),
    );
  }

  Future<Map<String, dynamic>> payAlipay(String orderString) async {
    final result = await _tobias.pay(orderString);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'resultStatus': result.toString()};
  }

  bool isAlipaySuccess(Map<String, dynamic> result) {
    final status = result['resultStatus']?.toString() ?? '';
    return status == '9000';
  }
}
