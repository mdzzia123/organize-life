import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static const _tokenKey = 'ol_access_token';
  static const _emailKey = 'ol_account_email';
  static const _accountIdKey = 'ol_account_id';
  static const _memberKey = 'ol_is_member';
  static const _memberPlanKey = 'ol_member_plan';
  static const _memberExpireKey = 'ol_member_expire';

  String? accessToken;
  String? email;
  String? accountId;
  bool isMember = false;
  String? memberPlanId;
  String? memberExpireAt;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);
    email = prefs.getString(_emailKey);
    accountId = prefs.getString(_accountIdKey);
    isMember = prefs.getBool(_memberKey) ?? false;
    memberPlanId = prefs.getString(_memberPlanKey);
    memberExpireAt = prefs.getString(_memberExpireKey);
  }

  Future<void> saveMember(Map<String, dynamic>? member) async {
    if (member == null) return;
    isMember = member['isMember'] == true;
    memberPlanId = member['planId']?.toString();
    memberExpireAt = member['expireAt']?.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memberKey, isMember);
    if (memberPlanId != null) {
      await prefs.setString(_memberPlanKey, memberPlanId!);
    } else {
      await prefs.remove(_memberPlanKey);
    }
    if (memberExpireAt != null && memberExpireAt!.isNotEmpty) {
      await prefs.setString(_memberExpireKey, memberExpireAt!);
    } else {
      await prefs.remove(_memberExpireKey);
    }
  }

  Future<void> saveFromLogin(Map<String, dynamic> data) async {
    accessToken = data['accessToken']?.toString();
    email = data['email']?.toString();
    accountId = data['accountId']?.toString();
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) await prefs.setString(_tokenKey, accessToken!);
    if (email != null) await prefs.setString(_emailKey, email!);
    if (accountId != null) await prefs.setString(_accountIdKey, accountId!);
    final member = data['member'];
    if (member is Map) await saveMember(Map<String, dynamic>.from(member));
  }

  Future<void> clear() async {
    accessToken = null;
    email = null;
    accountId = null;
    isMember = false;
    memberPlanId = null;
    memberExpireAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_accountIdKey);
    await prefs.remove(_memberKey);
    await prefs.remove(_memberPlanKey);
    await prefs.remove(_memberExpireKey);
  }
}
