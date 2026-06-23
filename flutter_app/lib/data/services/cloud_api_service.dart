import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_session.dart';
import 'cloud_config.dart';

typedef UploadProgressCallback = void Function(double progress, String label);

class CloudApiService {
  CloudApiService({Dio? dio, AuthSession? session})
      : _dio = dio ?? Dio(),
        session = session ?? AuthSession();

  final Dio _dio;
  final AuthSession session;
  static const _deviceIdKey = 'ol_device_id';

  Future<void> init() async {
    await session.load();
  }

  Dio get client {
    _dio.options
      ..baseUrl = CloudConfig.apiBaseUrl
      ..connectTimeout = CloudConfig.connectTimeout
      ..receiveTimeout = CloudConfig.receiveTimeout
      ..headers = {'Content-Type': 'application/json; charset=utf-8'};
    return _dio;
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<Map<String, dynamic>> _baseBody() async {
    final deviceId = await getDeviceId();
    final body = <String, dynamic>{'userId': deviceId, 'deviceId': deviceId};
    if (session.isLoggedIn) body['accessToken'] = session.accessToken;
    return body;
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final merged = {...await _baseBody(), ...body};
    final res = await client.post('', data: merged);
    final data = res.data is String ? jsonDecode(res.data) : res.data;
    if (data is! Map<String, dynamic>) throw Exception('响应格式错误');
    if (data['code'] != 0) {
      throw CloudApiException(data['msg']?.toString() ?? '请求失败', code: data['code']);
    }
    return data;
  }

  Future<void> registerDevice() async {
    await _post({'action': 'registerDevice'});
  }

  Future<Map<String, dynamic>> ping() async => _post({'action': 'ping'});

  Future<Map<String, dynamic>> getServiceConfig() async {
    final res = await _post({'action': 'getServiceConfig'});
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<void> sendEmailCode({required String email}) async {
    await _post({'action': 'sendEmailCode', 'email': email});
  }

  Future<Map<String, dynamic>> registerEmail({
    required String email,
    required String password,
    String? emailCode,
  }) async {
    final res = await _post({
      'action': 'registerEmail',
      'email': email,
      'password': password,
      if (emailCode != null && emailCode.isNotEmpty) 'emailCode': emailCode,
    });
    await session.saveFromLogin(Map<String, dynamic>.from(res['data'] ?? {}));
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<Map<String, dynamic>> loginEmail({
    required String email,
    required String password,
  }) async {
    final res = await _post({
      'action': 'loginEmail',
      'email': email,
      'password': password,
    });
    await session.saveFromLogin(Map<String, dynamic>.from(res['data'] ?? {}));
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<void> logout() async => session.clear();

  Future<Map<String, dynamic>> getAccountProfile() async {
    final res = await _post({'action': 'getAccountProfile'});
    final data = Map<String, dynamic>.from(res['data'] ?? {});
    final member = data['member'];
    if (member is Map) await session.saveMember(Map<String, dynamic>.from(member));
    return data;
  }

  Future<Map<String, dynamic>> getMembershipStatus() async {
    final res = await _post({'action': 'getMembershipStatus'});
    final data = Map<String, dynamic>.from(res['data'] ?? {});
    final member = data;
    if (member.containsKey('isMember')) {
      await session.saveMember({
        'isMember': member['isMember'],
        'planId': member['planId'],
        'expireAt': member['expireAt'],
      });
    }
    return data;
  }

  Future<Map<String, dynamic>> listMemberPlans() async {
    final res = await _post({'action': 'listMemberPlans'});
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<Map<String, dynamic>> createMemberOrder({
    required String planId,
    required String channel,
  }) async {
    final res = await _post({
      'action': 'createMemberOrder',
      'planId': planId,
      'channel': channel,
    });
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<Map<String, dynamic>> confirmMemberOrder({
    required String orderId,
    bool mockPaid = false,
  }) async {
    final res = await _post({
      'action': 'confirmMemberOrder',
      'orderId': orderId,
      if (mockPaid) 'mockPaid': true,
    });
    final data = Map<String, dynamic>.from(res['data'] ?? {});
    final member = data['member'];
    if (member is Map) await session.saveMember(Map<String, dynamic>.from(member));
    return data;
  }

  Future<Map<String, dynamic>> queryMemberOrder(String orderId) async {
    final res = await _post({'action': 'queryMemberOrder', 'orderId': orderId});
    final data = Map<String, dynamic>.from(res['data'] ?? {});
    final member = data['member'];
    if (member is Map) await session.saveMember(Map<String, dynamic>.from(member));
    return data;
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final res = await _post({'action': 'listCategories'});
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  }

  Future<String> saveCategory({
    String? cloudId,
    required String name,
    String slug = '',
    String icon = 'category',
    String color = '#607D8B',
    int sortOrder = 100,
    String? parentCloudId,
    int depth = 0,
    bool isSystem = false,
  }) async {
    final body = {
      'action': 'saveCategory',
      'name': name,
      'slug': slug.isEmpty ? 'custom_${DateTime.now().millisecondsSinceEpoch}' : slug,
      'icon': icon,
      'color': color,
      'sortOrder': sortOrder,
      'depth': depth,
      'isSystem': isSystem,
    };
    if (parentCloudId != null && parentCloudId.isNotEmpty) body['parentId'] = parentCloudId;
    if (cloudId != null && cloudId.isNotEmpty) body['id'] = cloudId;
    final res = await _post(body);
    return res['data']?['id']?.toString() ?? cloudId ?? '';
  }

  Future<void> deleteCategory(String cloudId) async {
    await _post({'action': 'deleteCategory', 'id': cloudId});
  }

  Future<Map<String, dynamic>> prepareUpload({required String fileName}) async {
    final res = await _post({'action': 'prepareUpload', 'fileName': fileName});
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<void> uploadFileDirect(
    String localPath,
    Map<String, dynamic> meta, {
    UploadProgressCallback? onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('本地文件不存在');

    final formData = FormData.fromMap({
      'Signature': meta['authorization'],
      'x-cos-security-token': meta['token'],
      'x-cos-meta-fileid': meta['cosFileId'],
      'key': meta['cloudPath'],
      'file': await MultipartFile.fromFile(localPath, filename: p.basename(localPath)),
    });

    final uploadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
      validateStatus: (code) => code != null && code < 500,
    ));
    onProgress?.call(0.08, '正在上传图片…');
    final res = await uploadDio.post(
      meta['url']?.toString() ?? '',
      data: formData,
      onSendProgress: (sent, total) {
        if (total <= 0) return;
        final ratio = sent / total;
        onProgress?.call(0.08 + ratio * 0.82, '正在上传图片… ${(ratio * 100).toInt()}%');
      },
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('直传失败: HTTP ${res.statusCode}');
    }
    onProgress?.call(0.92, '图片上传完成');
  }

  Future<Map<String, dynamic>> saveItem({
    String? cloudId,
    required String categoryCloudId,
    required int localId,
    String title = '',
    String note = '',
    List<String> tags = const [],
    List<String> colors = const [],
    String? fileID,
    String? cloudPath,
    int imageSize = 0,
    String? localImagePath,
    bool useDirectUpload = true,
    UploadProgressCallback? onProgress,
  }) async {
    final body = <String, dynamic>{
      'action': 'saveItem',
      'categoryId': categoryCloudId,
      'localId': localId.toString(),
      'title': title,
      'note': note,
      'tags': tags,
      'colors': colors,
    };
    if (cloudId != null && cloudId.isNotEmpty) body['id'] = cloudId;

    var uploadedFileId = fileID ?? '';
    var uploadedPath = cloudPath ?? '';
    var size = imageSize;

    final needUpload = localImagePath != null &&
        localImagePath.isNotEmpty &&
        await File(localImagePath).exists() &&
        (uploadedFileId.isEmpty);

    if (needUpload && useDirectUpload) {
      try {
        onProgress?.call(0.03, '获取上传凭证…');
        final fileName = localImagePath.split(Platform.pathSeparator).last;
        final meta = await prepareUpload(fileName: fileName);
        await uploadFileDirect(localImagePath, meta, onProgress: onProgress);
        uploadedFileId = meta['fileId']?.toString() ?? '';
        uploadedPath = meta['cloudPath']?.toString() ?? '';
        size = await File(localImagePath).length();
      } catch (_) {
        // fallback below
      }
    }

    if (needUpload && uploadedFileId.isEmpty) {
      onProgress?.call(0.15, '备用通道上传中…');
      final file = File(localImagePath);
      final bytes = await file.readAsBytes();
      body['imageBase64'] = base64Encode(bytes);
      body['fileName'] = localImagePath.split(Platform.pathSeparator).last;
      onProgress?.call(0.75, '备用通道上传中…');
    } else {
      if (uploadedFileId.isNotEmpty) body['fileID'] = uploadedFileId;
      if (uploadedPath.isNotEmpty) body['cloudPath'] = uploadedPath;
      if (size > 0) body['imageSize'] = size;
    }

    onProgress?.call(0.96, '保存记录…');
    final res = await _post(body);
    onProgress?.call(1.0, '完成');
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> listItems({
    String? categoryCloudId,
    String keyword = '',
    int limit = 100,
    int skip = 0,
  }) async {
    final res = await _post({
      'action': 'listItems',
      if (categoryCloudId != null) 'categoryId': categoryCloudId,
      'keyword': keyword,
      'limit': limit,
      'skip': skip,
    });
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  }

  Future<List<Map<String, dynamic>>> listAllItems({String keyword = ''}) async {
    final all = <Map<String, dynamic>>[];
    var skip = 0;
    const limit = 100;
    while (true) {
      final batch = await listItems(keyword: keyword, limit: limit, skip: skip);
      if (batch.isEmpty) break;
      all.addAll(batch);
      if (batch.length < limit) break;
      skip += limit;
    }
    return all;
  }

  Future<Map<String, String>> getTempUrls(List<String> fileIDs) async {
    final res = await _post({'action': 'getTempUrls', 'fileIDs': fileIDs});
    return Map<String, String>.from(res['data'] ?? {});
  }

  Future<void> deleteItem(String cloudId) async {
    await _post({'action': 'deleteItem', 'id': cloudId});
  }
}

class CloudApiException implements Exception {
  CloudApiException(this.message, {this.code});
  final String message;
  final dynamic code;

  @override
  String toString() => 'CloudApiException($code): $message';
}
