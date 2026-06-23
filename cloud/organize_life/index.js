'use strict';

/**
 * 整理人生 - 云函数 API v1.2
 *
 * 集合:
 *   ol_users       设备记录（deviceId → accountId）
 *   ol_accounts    邮箱账号（accountId + devices[]）
 *   ol_categories  分类
 *   ol_items       图片条目元数据
 *   ol_email_codes 邮箱验证码
 *   ol_orders      会员订单
 *
 * 云存储路径: deal_life/user_{ownerId}/items/{timestamp}_{filename}
 * ownerId = 登录后的 accountId，未登录时为 deviceId
 */

const crypto = require('crypto');
const cloud = require('wx-server-sdk');
const tcb = require('@cloudbase/node-sdk');
const { createMembershipHelpers } = require('./ol_membership.js');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });

const tcbApp = tcb.init({ env: cloud.DYNAMIC_CURRENT_ENV });

const db = cloud.database();
const _ = db.command;

const users = db.collection('ol_users');
const accounts = db.collection('ol_accounts');
const categories = db.collection('ol_categories');
const items = db.collection('ol_items');

const SESSION_SECRET = process.env.OL_SESSION_SECRET || 'organize-life-session-v1';
const TOKEN_TTL_MS = 30 * 24 * 3600 * 1000;
const STORAGE_PREFIX = 'deal_life';

const _CLOTHING_TYPES = [
  { slug: 'outerwear', name: '外套', sortOrder: 1 },
  { slug: 'innerwear', name: '内搭', sortOrder: 2 },
  { slug: 'pants', name: '裤子', sortOrder: 3 },
  { slug: 'dress', name: '连衣裙', sortOrder: 4 },
  { slug: 'skirt', name: '半裙', sortOrder: 5 },
];
const _JEWELRY_TYPES = [
  { slug: 'earrings', name: '耳饰', sortOrder: 1 },
  { slug: 'necklace', name: '项链', sortOrder: 2 },
  { slug: 'ring', name: '戒指', sortOrder: 3 },
];

const PRESET_TREE = [
  { slug: 'wardrobe', name: '衣橱', icon: 'checkroom', color: '#5B8DEF', sortOrder: 1, children: [
    { slug: 'winter', name: '冬季', sortOrder: 1, children: _CLOTHING_TYPES },
    { slug: 'spring_autumn', name: '春秋', sortOrder: 2, children: _CLOTHING_TYPES },
    { slug: 'summer', name: '夏季', sortOrder: 3, children: _CLOTHING_TYPES },
  ]},
  { slug: 'cosmetics', name: '化妆品', icon: 'face', color: '#E87BA0', sortOrder: 2, children: [
    { slug: 'skincare', name: '护肤', sortOrder: 1 },
    { slug: 'makeup', name: '彩妆', sortOrder: 2, children: [
      { slug: 'eyeshadow', name: '眼影类', sortOrder: 1 },
      { slug: 'makeup_tools', name: '工具类', sortOrder: 2 },
    ]},
  ]},
  { slug: 'jewelry', name: '首饰', icon: 'diamond', color: '#AB47BC', sortOrder: 3, children: [
    { slug: 'gold', name: '黄金', sortOrder: 1, children: _JEWELRY_TYPES },
    { slug: 'jade', name: '玉石', sortOrder: 2, children: _JEWELRY_TYPES },
    { slug: 'kgold', name: 'K金', sortOrder: 3, children: _JEWELRY_TYPES },
  ]},
  { slug: 'health', name: '健康', icon: 'medical_services', color: '#4CAF88', sortOrder: 4, children: [
    { slug: 'hospital_reports', name: '医院检查报告', sortOrder: 1, children: [{ slug: 'department', name: '科室', sortOrder: 1 }] },
    { slug: 'home_medicine', name: '家有药品', sortOrder: 2, children: [
      { slug: 'cold_medicine', name: '感冒药', sortOrder: 1 },
      { slug: 'chinese_medicine', name: '中成药', sortOrder: 2 },
      { slug: 'anti_inflammatory', name: '消炎药', sortOrder: 3 },
    ]},
  ]},
  { slug: 'documents', name: '证件', icon: 'badge', color: '#F5A623', sortOrder: 5, children: [
    { slug: 'id_card', name: '身份证', sortOrder: 1 },
    { slug: 'driver_license', name: '驾驶证', sortOrder: 2 },
    { slug: 'qualification', name: '学历工作资质', sortOrder: 3, children: [
      { slug: 'graduation_cert', name: '毕业证书', sortOrder: 1 },
      { slug: 'skill_cert', name: '技能证书', sortOrder: 2 },
    ]},
  ]},
  { slug: 'assets', name: '资产', icon: 'account_balance', color: '#795548', sortOrder: 6, children: [
    { slug: 'insurance', name: '保险单据', sortOrder: 1 },
    { slug: 'property_deed', name: '房产证', sortOrder: 2 },
    { slug: 'finance', name: '银行证券', sortOrder: 3 },
  ]},
  { slug: 'collections', name: '收藏爱好类', icon: 'collections', color: '#9C27B0', sortOrder: 7, children: [
    { slug: 'tea_set', name: '茶具', sortOrder: 1 },
    { slug: 'calligraphy', name: '字画', sortOrder: 2 },
    { slug: 'figures', name: '手办', sortOrder: 3, children: [{ slug: 'books', name: '书籍', sortOrder: 1 }] },
  ]},
  { slug: 'furniture_home', name: '家具家居', icon: 'chair', color: '#8D6E63', sortOrder: 8, children: [
    { slug: 'master_bedroom', name: '主卧', sortOrder: 1 },
    { slug: 'living_room', name: '客厅', sortOrder: 2 },
    { slug: 'appliances', name: '大家电', sortOrder: 3 },
  ]},
  { slug: 'kitchen', name: '厨房', icon: 'kitchen', color: '#FF7043', sortOrder: 9, children: [
    { slug: 'kitchen_appliances', name: '厨电', sortOrder: 1 },
    { slug: 'tableware', name: '餐具', sortOrder: 2 },
    { slug: 'kitchen_tools', name: '工具', sortOrder: 3 },
  ]},
  { slug: 'digital', name: '数码', icon: 'devices', color: '#2196F3', sortOrder: 10, children: [
    { slug: 'computer', name: '电脑', sortOrder: 1 },
    { slug: 'wearables', name: '个人电子穿戴', sortOrder: 2 },
    { slug: 'accessories', name: '配件', sortOrder: 3 },
  ]},
];

function flattenPresetTree(nodes, parentSlug = null, depth = 0, rootColor = '#607D8B') {
  const out = [];
  for (const n of nodes) {
    const slug = parentSlug ? `${parentSlug}_${n.slug}` : n.slug;
    const color = depth === 0 ? (n.color || rootColor) : rootColor;
    out.push({
      slug,
      name: n.name,
      icon: depth === 0 ? (n.icon || 'category') : 'subcategory',
      color,
      sortOrder: n.sortOrder || 100,
      parentSlug,
      depth,
    });
    if (n.children && n.children.length) {
      out.push(...flattenPresetTree(n.children, slug, depth + 1, color));
    }
  }
  return out;
}

function buildHeaders() {
  return { 'Content-Type': 'application/json; charset=utf-8' };
}

function jsonResponse(data, statusCode = 200) {
  return {
    isBase64Encoded: false,
    statusCode,
    headers: buildHeaders(),
    body: JSON.stringify(data),
  };
}

function xmlResponse(xml, statusCode = 200) {
  return {
    isBase64Encoded: false,
    statusCode,
    headers: { 'Content-Type': 'text/xml; charset=utf-8' },
    body: xml,
  };
}

function textResponse(text, statusCode = 200) {
  return {
    isBase64Encoded: false,
    statusCode,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: text,
  };
}

function beijingNow() {
  return new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false });
}

function parseQueryFromUrl(url) {
  if (!url || typeof url !== 'string') return {};
  const qIdx = url.indexOf('?');
  if (qIdx < 0) return {};
  const out = {};
  for (const part of url.slice(qIdx + 1).split('&')) {
    if (!part) continue;
    const eq = part.indexOf('=');
    if (eq < 0) out[decodeURIComponent(part)] = '';
    else out[decodeURIComponent(part.slice(0, eq))] = decodeURIComponent(part.slice(eq + 1));
  }
  return out;
}

function getQuery(event, context) {
  return (
    event?.queryStringParameters ||
    context?.httpContext?.queryStringParameters ||
    parseQueryFromUrl(context?.httpContext?.url) ||
    parseQueryFromUrl(context?.httpContext?.path) ||
    parseQueryFromUrl(event?.path) ||
    {}
  );
}

function getRawBody(event) {
  if (!event?.body) return '';
  let raw = event.body;
  if (event.isBase64Encoded) raw = Buffer.from(raw, 'base64').toString('utf-8');
  return typeof raw === 'string' ? raw : JSON.stringify(raw);
}

function parseFormBody(raw) {
  const out = {};
  for (const part of String(raw || '').split('&')) {
    if (!part) continue;
    const eq = part.indexOf('=');
    if (eq < 0) continue;
    const k = decodeURIComponent(part.slice(0, eq));
    const v = decodeURIComponent(part.slice(eq + 1).replace(/\+/g, ' '));
    out[k] = v;
  }
  return out;
}

function parseBody(event) {
  try {
    let body = {};
    if (event.body) {
      let rawBody = event.body;
      if (event.isBase64Encoded) rawBody = Buffer.from(rawBody, 'base64').toString('utf-8');
      body = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    } else if (event && typeof event === 'object' && !event.httpMethod && !event.path) {
      body = event;
    }
    return body;
  } catch (err) {
    console.warn('parseBody failed:', err.message || err);
    return {};
  }
}

function getAction(event, context, body) {
  if (body?.action) return body.action;
  if (event?.action) return event.action;
  const q = getQuery(event, context);
  return q.action || '';
}

function extractAccessToken(body, event) {
  const fromBody = String(body.accessToken || '').trim();
  if (fromBody) return fromBody;
  const auth = event?.headers?.authorization || event?.headers?.Authorization || '';
  const m = String(auth).match(/^Bearer\s+(.+)$/i);
  return m ? m[1].trim() : '';
}

function hashPassword(password, salt) {
  return crypto.scryptSync(password, salt, 64).toString('hex');
}

function createAccessToken(accountId) {
  const exp = Date.now() + TOKEN_TTL_MS;
  const payload = `${accountId}:${exp}`;
  const sig = crypto.createHmac('sha256', SESSION_SECRET).update(payload).digest('hex');
  return Buffer.from(`${payload}:${sig}`).toString('base64url');
}

function verifyAccessToken(token) {
  if (!token) return null;
  try {
    const raw = Buffer.from(token, 'base64url').toString('utf8');
    const parts = raw.split(':');
    if (parts.length !== 3) return null;
    const [accountId, expStr, sig] = parts;
    const exp = parseInt(expStr, 10);
    if (!accountId || !exp || Date.now() > exp) return null;
    const payload = `${accountId}:${expStr}`;
    const expected = crypto.createHmac('sha256', SESSION_SECRET).update(payload).digest('hex');
    if (sig !== expected) return null;
    return accountId;
  } catch (_) {
    return null;
  }
}

function requireDeviceId(body) {
  const deviceId = String(body.userId || body.deviceId || '').trim();
  if (!deviceId) throw new Error('缺少 userId / deviceId');
  return deviceId;
}

function cloudPathFor(ownerId, fileName) {
  const safe = String(fileName || 'image.jpg').replace(/[^\w.\-]/g, '_');
  return `${STORAGE_PREFIX}/user_${ownerId}/items/${Date.now()}_${safe}`;
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function findAccountByEmail(email) {
  const res = await accounts.where({ email }).limit(1).get();
  return res.data?.[0] || null;
}

async function findAccountById(accountId) {
  const res = await accounts.where({ accountId }).limit(1).get();
  return res.data?.[0] || null;
}

async function linkDeviceToAccount(account, deviceId) {
  const list = Array.isArray(account.devices) ? account.devices : [];
  if (!list.some((d) => d.deviceId === deviceId)) {
    list.push({ deviceId, linkedAt: beijingNow() });
    await accounts.doc(account._id).update({
      data: { devices: list, updatedAt: beijingNow() },
    });
    account.devices = list;
  }
  const userRes = await users.where({ userId: deviceId }).limit(1).get();
  if (userRes.data?.length) {
    await users.doc(userRes.data[0]._id).update({
      data: { accountId: account.accountId, updatedAt: beijingNow() },
    });
  } else {
    await users.add({
      data: { userId: deviceId, accountId: account.accountId, createdAt: beijingNow(), updatedAt: beijingNow() },
    });
  }
}

async function migrateUserData(fromUserId, toUserId) {
  if (!fromUserId || !toUserId || fromUserId === toUserId) return;

  const fromCats = (await categories.where({ userId: fromUserId }).limit(200).get()).data || [];
  const slugToTargetCatId = {};

  for (const cat of fromCats) {
    const targetRes = await categories.where({ userId: toUserId, slug: cat.slug }).limit(1).get();
    if (targetRes.data?.length) {
      slugToTargetCatId[cat._id] = targetRes.data[0]._id;
      if (!cat.isSystem) await categories.doc(cat._id).remove();
    } else {
      await categories.doc(cat._id).update({ data: { userId: toUserId, updatedAt: beijingNow() } });
      slugToTargetCatId[cat._id] = cat._id;
    }
  }

  const fromItems = (await items.where({ userId: fromUserId }).limit(500).get()).data || [];
  for (const item of fromItems) {
    const newCatId = slugToTargetCatId[item.categoryId] || item.categoryId;
    await items.doc(item._id).update({
      data: { userId: toUserId, categoryId: newCatId, updatedAt: beijingNow() },
    });
  }
}

async function resolveOwner(body, event) {
  const deviceId = String(body.userId || body.deviceId || '').trim();
  const token = extractAccessToken(body, event);
  if (token) {
    const accountId = verifyAccessToken(token);
    if (!accountId) throw new Error('登录已失效，请重新登录');
    const account = await findAccountById(accountId);
    if (!account) throw new Error('账号不存在');
    if (deviceId) {
      await linkDeviceToAccount(account, deviceId);
      await mergeDeviceIntoAccount(deviceId, accountId);
    }
    return { ownerId: accountId, deviceId, accountId, email: account.email, isLoggedIn: true };
  }
  if (!deviceId) throw new Error('缺少 userId / deviceId');
  return { ownerId: deviceId, deviceId, accountId: null, email: '', isLoggedIn: false };
}

async function mergeDeviceIntoAccount(deviceId, accountId) {
  const userRes = await users.where({ userId: deviceId }).limit(1).get();
  const row = userRes.data?.[0];
  if (row?.migratedToAccount === accountId) return;
  const catCount = await categories.where({ userId: deviceId }).count();
  const itemCount = await items.where({ userId: deviceId }).count();
  if ((catCount.total || 0) > 0 || (itemCount.total || 0) > 0) {
    await migrateUserData(deviceId, accountId);
  }
  if (row) {
    await users.doc(row._id).update({
      data: { accountId, migratedToAccount: accountId, updatedAt: beijingNow() },
    });
  }
}

async function ensureUser(ownerId) {
  const res = await users.where({ userId: ownerId }).limit(1).get();
  if (res.data && res.data.length) {
    const catCount = await categories.where({ userId: ownerId }).count();
    if ((catCount.total || 0) === 0) await seedPresetCategories(ownerId);
    return res.data[0];
  }

  const now = beijingNow();
  await users.add({ data: { userId: ownerId, createdAt: now, updatedAt: now } });
  await seedPresetCategories(ownerId);
  return { userId: ownerId, createdAt: now };
}

async function seedPresetCategories(ownerId) {
  const now = beijingNow();
  const flat = flattenPresetTree(PRESET_TREE);
  const slugToId = {};

  for (const preset of flat) {
    const exists = await categories.where({ userId: ownerId, slug: preset.slug }).limit(1).get();
    if (exists.data?.length) {
      slugToId[preset.slug] = exists.data[0]._id;
      continue;
    }
    const parentId = preset.parentSlug ? (slugToId[preset.parentSlug] || '') : '';
    const addRes = await categories.add({
      data: {
        userId: ownerId,
        slug: preset.slug,
        name: preset.name,
        icon: preset.icon,
        color: preset.color,
        sortOrder: preset.sortOrder,
        parentId,
        depth: preset.depth,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      },
    });
    slugToId[preset.slug] = addRes._id;
  }
}

async function uploadBase64Image(ownerId, base64, fileName) {
  if (!base64) return { fileID: '', cloudPath: '' };
  const buf = Buffer.from(base64.replace(/^data:image\/\w+;base64,/, ''), 'base64');
  const cloudPath = cloudPathFor(ownerId, fileName);
  const uploadRes = await cloud.uploadFile({ cloudPath, fileContent: buf });
  return { fileID: uploadRes.fileID || '', cloudPath, size: buf.length };
}

async function prepareUploadMetadata(ownerId, fileName) {
  const cloudPath = cloudPathFor(ownerId, fileName);
  const meta = await tcbApp.getUploadMetadata({ cloudPath });
  const data = meta.data || meta;
  return {
    url: data.url,
    authorization: data.authorization,
    token: data.token,
    cosFileId: data.cosFileId,
    fileId: data.fileId,
    cloudPath,
  };
}

async function getTempUrls(fileIDs) {
  const ids = (fileIDs || []).filter(Boolean).slice(0, 50);
  if (!ids.length) return {};
  const res = await cloud.getTempFileURL({ fileList: ids.map((fileID) => ({ fileID, maxAge: 7200 })) });
  const map = {};
  for (const row of res.fileList || []) map[row.fileID] = row.tempFileURL || '';
  return map;
}

const membership = createMembershipHelpers({
  db,
  accounts,
  items,
  jsonResponse,
  xmlResponse,
  textResponse,
  beijingNow,
  normalizeEmail,
  validateEmail,
  findAccountByEmail,
  findAccountById,
  requireDeviceId,
  createAccessToken,
});

const {
  memberSnapshot,
  verifyEmailCode,
  handleSendEmailCode,
  handleListMemberPlans,
  handleGetMembershipStatus,
  handleCreateMemberOrder,
  handleConfirmMemberOrder,
  handleQueryMemberOrder,
  handleWechatPayNotify,
  handleAlipayPayNotify,
  handleGetServiceConfig,
} = membership;

async function resolveMemberForOwner(ownerId, isLoggedIn) {
  if (!isLoggedIn) return memberSnapshot(null);
  const account = await findAccountById(ownerId);
  return memberSnapshot(account);
}

async function handleRegisterEmail(body) {
  const email = normalizeEmail(body.email);
  const password = String(body.password || '');
  const emailCode = String(body.emailCode || body.code || '').trim();
  const deviceId = requireDeviceId(body);
  if (!validateEmail(email)) return jsonResponse({ code: 4002, msg: '邮箱格式不正确' });
  if (password.length < 6) return jsonResponse({ code: 4002, msg: '密码至少 6 位' });

  const requireCode = process.env.OL_REQUIRE_EMAIL_CODE === '1';
  if (requireCode) {
    if (!emailCode || emailCode.length < 4) return jsonResponse({ code: 4002, msg: '请输入邮箱验证码' });
    if (!(await verifyEmailCode(email, emailCode))) return jsonResponse({ code: 4011, msg: '验证码错误或已过期' });
  }

  if (await findAccountByEmail(email)) return jsonResponse({ code: 4006, msg: '该邮箱已注册' });

  const accountId = crypto.randomUUID();
  const salt = crypto.randomBytes(16).toString('hex');
  const passwordHash = hashPassword(password, salt);
  const now = beijingNow();

  await accounts.add({
    data: {
      accountId,
      email,
      passwordSalt: salt,
      passwordHash,
      devices: [{ deviceId, linkedAt: now }],
      createdAt: now,
      updatedAt: now,
    },
  });

  await ensureUser(deviceId);
  await migrateUserData(deviceId, accountId);
  await ensureUser(accountId);
  const account = await findAccountById(accountId);
  await linkDeviceToAccount(account, deviceId);

  const accessToken = createAccessToken(accountId);
  const member = memberSnapshot(account);
  return jsonResponse({
    code: 0,
    msg: 'registered',
    data: { accountId, email, accessToken, ownerId: accountId, deviceId, member },
  });
}

async function handleLoginEmail(body) {
  const email = normalizeEmail(body.email);
  const password = String(body.password || '');
  const deviceId = requireDeviceId(body);
  if (!validateEmail(email)) return jsonResponse({ code: 4002, msg: '邮箱格式不正确' });

  const account = await findAccountByEmail(email);
  if (!account) return jsonResponse({ code: 4007, msg: '邮箱或密码错误' });

  const hash = hashPassword(password, account.passwordSalt);
  if (hash !== account.passwordHash) return jsonResponse({ code: 4007, msg: '邮箱或密码错误' });

  await linkDeviceToAccount(account, deviceId);
  await mergeDeviceIntoAccount(deviceId, account.accountId);
  await ensureUser(account.accountId);

  const accessToken = createAccessToken(account.accountId);
  const member = memberSnapshot(account);
  return jsonResponse({
    code: 0,
    msg: 'ok',
    data: {
      accountId: account.accountId,
      email: account.email,
      accessToken,
      ownerId: account.accountId,
      deviceId,
      linkedDevices: (account.devices || []).map((d) => d.deviceId),
      member,
    },
  });
}

async function handleGetAccountProfile(body, event) {
  const { ownerId, email, deviceId, isLoggedIn } = await resolveOwner(body, event);
  const account = isLoggedIn ? await findAccountById(ownerId) : null;
  const member = memberSnapshot(account);
  const itemCount = (await items.where({ userId: ownerId }).count()).total || 0;
  return jsonResponse({
    code: 0,
    msg: 'ok',
    data: {
      isLoggedIn,
      accountId: isLoggedIn ? ownerId : '',
      email: email || account?.email || '',
      deviceId,
      ownerId,
      linkedDevices: account?.devices?.map((d) => d.deviceId) || [],
      member,
      itemCount,
    },
  });
}

exports.main = async (event, context) => {
  const method = context?.httpContext?.httpMethod || event?.httpMethod || '';
  if (method === 'OPTIONS') {
    return { isBase64Encoded: false, statusCode: 204, headers: buildHeaders(), body: '' };
  }

  try {
    const query = getQuery(event, context);
    const rawBody = getRawBody(event);

    // 微信 / 支付宝异步回调（非 JSON，通过 ?notify=wechat|alipay 区分）
    if (method === 'POST' && query.notify === 'wechat') {
      return handleWechatPayNotify(rawBody);
    }
    if (method === 'POST' && query.notify === 'alipay') {
      return handleAlipayPayNotify(parseFormBody(rawBody));
    }

    const body = parseBody(event);
    const action = getAction(event, context, body);

    if (action === 'ping') {
      return jsonResponse({ code: 0, msg: 'pong', service: 'organize_life', version: '1.5.1', time: beijingNow() });
    }

    if (action === 'getServiceConfig') return handleGetServiceConfig();

    if (action === 'sendEmailCode') return handleSendEmailCode(body);
    if (action === 'registerEmail') return handleRegisterEmail(body);
    if (action === 'loginEmail') return handleLoginEmail(body);
    if (action === 'getAccountProfile') return handleGetAccountProfile(body, event);
    if (action === 'listMemberPlans') return handleListMemberPlans();
    if (action === 'getMembershipStatus') return handleGetMembershipStatus(body, event, resolveOwner);
    if (action === 'createMemberOrder') return handleCreateMemberOrder(body, event, resolveOwner);
    if (action === 'confirmMemberOrder') return handleConfirmMemberOrder(body, event, resolveOwner);
    if (action === 'queryMemberOrder') return handleQueryMemberOrder(body, event, resolveOwner);

    if (action === 'registerDevice') {
      const deviceId = requireDeviceId(body);
      await ensureUser(deviceId);
      const token = extractAccessToken(body, event);
      let ownerId = deviceId;
      if (token) {
        const accountId = verifyAccessToken(token);
        if (accountId) {
          const account = await findAccountById(accountId);
          if (account) {
            await linkDeviceToAccount(account, deviceId);
            await mergeDeviceIntoAccount(deviceId, accountId);
            ownerId = accountId;
          }
        }
      }
      await ensureUser(ownerId);
      return jsonResponse({ code: 0, msg: 'ok', data: { userId: ownerId, deviceId, ownerId } });
    }

    if (action === 'prepareUpload') {
      const { ownerId, isLoggedIn } = await resolveOwner(body, event);
      await ensureUser(ownerId);
      const member = await resolveMemberForOwner(ownerId, isLoggedIn);
      if (!member.cloudBackup) {
        return jsonResponse({ code: 4033, msg: '云端备份为会员功能，请先升级会员' });
      }
      const fileName = String(body.fileName || 'photo.jpg');
      const meta = await prepareUploadMetadata(ownerId, fileName);
      return jsonResponse({ code: 0, msg: 'ok', data: meta });
    }

    const { ownerId } = await resolveOwner(body, event);

    if (action === 'listCategories') {
      await ensureUser(ownerId);
      const res = await categories.where({ userId: ownerId }).orderBy('sortOrder', 'asc').limit(500).get();
      return jsonResponse({ code: 0, msg: 'ok', data: res.data || [] });
    }

    if (action === 'saveCategory') {
      await ensureUser(ownerId);
      const id = String(body.id || body._id || '').trim();
      const name = String(body.name || '').trim();
      if (!name) return jsonResponse({ code: 4002, msg: '分类名称不能为空' });

      const parentId = String(body.parentId || '').trim();
      const depth = Math.max(parseInt(body.depth || '0', 10), 0);
      if (depth > 4) return jsonResponse({ code: 4003, msg: '分类层级不能超过 5 级' });

      const now = beijingNow();
      const record = {
        userId: ownerId,
        slug: String(body.slug || `custom_${Date.now()}`),
        name,
        icon: String(body.icon || 'category'),
        color: String(body.color || '#607D8B'),
        sortOrder: parseInt(body.sortOrder || '100', 10),
        parentId,
        depth,
        isSystem: body.isSystem === true,
        updatedAt: now,
      };

      if (id) {
        const existing = await categories.doc(id).get();
        if (!existing.data || existing.data.userId !== ownerId) return jsonResponse({ code: 4004, msg: '分类不存在' });
        record.isSystem = existing.data.isSystem === true;
        record.slug = existing.data.slug || record.slug;
        await categories.doc(id).update({ data: { ...existing.data, ...record } });
        return jsonResponse({ code: 0, msg: 'updated', data: { id } });
      }

      record.createdAt = now;
      const addRes = await categories.add({ data: record });
      return jsonResponse({ code: 0, msg: 'saved', data: { id: addRes._id } });
    }

    if (action === 'deleteCategory') {
      const id = String(body.id || body._id || '').trim();
      if (!id) return jsonResponse({ code: 4002, msg: '缺少 id' });
      const existing = await categories.doc(id).get();
      if (!existing.data || existing.data.userId !== ownerId) return jsonResponse({ code: 4004, msg: '分类不存在' });
      const childCount = await categories.where({ userId: ownerId, parentId: id }).count();
      if (childCount.total > 0) return jsonResponse({ code: 4005, msg: '请先删除子分类' });
      const countRes = await items.where({ userId: ownerId, categoryId: id }).count();
      if (countRes.total > 0) return jsonResponse({ code: 4005, msg: `该分类下还有 ${countRes.total} 张图片` });
      await categories.doc(id).remove();
      return jsonResponse({ code: 0, msg: 'deleted' });
    }

    if (action === 'saveItem') {
      await ensureUser(ownerId);
      const categoryId = String(body.categoryId || '').trim();
      if (!categoryId) return jsonResponse({ code: 4002, msg: '缺少 categoryId' });

      const id = String(body.id || body._id || '').trim();
      if (!id) {
        const { isLoggedIn } = await resolveOwner(body, event);
        const member = await resolveMemberForOwner(ownerId, isLoggedIn);
        if (member.itemLimit > 0) {
          const countRes = await items.where({ userId: ownerId }).count();
          if ((countRes.total || 0) >= member.itemLimit) {
            return jsonResponse({ code: 4033, msg: `免费版最多 ${member.itemLimit} 张图片，升级会员可无限存储` });
          }
        }
      }

      const now = beijingNow();
      let fileID = String(body.fileID || body.fileId || '');
      let cloudPath = String(body.cloudPath || '');
      let imageSize = parseInt(body.imageSize || '0', 10);

      if (body.imageBase64) {
        const uploaded = await uploadBase64Image(ownerId, body.imageBase64, body.fileName || 'photo.jpg');
        fileID = uploaded.fileID;
        cloudPath = uploaded.cloudPath;
        imageSize = uploaded.size || 0;
      }

      const record = {
        userId: ownerId,
        categoryId,
        title: String(body.title || '').trim(),
        note: String(body.note || '').trim(),
        tags: Array.isArray(body.tags) ? body.tags.slice(0, 20) : [],
        colors: Array.isArray(body.colors) ? body.colors.slice(0, 14) : [],
        fileID,
        cloudPath,
        imageSize,
        localId: String(body.localId || ''),
        sourceDeviceId: String(body.deviceId || ''),
        updatedAt: now,
      };

      if (id) {
        const existing = await items.doc(id).get();
        if (!existing.data || existing.data.userId !== ownerId) return jsonResponse({ code: 4004, msg: '条目不存在' });
        await items.doc(id).update({ data: record });
        return jsonResponse({ code: 0, msg: 'updated', data: { id, fileID, cloudPath } });
      }

      record.createdAt = now;
      const addRes = await items.add({ data: record });
      return jsonResponse({ code: 0, msg: 'saved', data: { id: addRes._id, fileID, cloudPath } });
    }

    if (action === 'listItems') {
      const { isLoggedIn } = await resolveOwner(body, event);
      const member = await resolveMemberForOwner(ownerId, isLoggedIn);
      if (!member.cloudBackup) {
        return jsonResponse({ code: 4033, msg: '云端恢复为会员功能，请先升级会员' });
      }
      const categoryId = String(body.categoryId || '').trim();
      const keyword = String(body.keyword || '').trim();
      const limit = Math.min(parseInt(body.limit || '100', 10), 500);
      const skip = Math.max(parseInt(body.skip || '0', 10), 0);

      let query = items.where({ userId: ownerId });
      if (categoryId) query = query.where({ categoryId });

      const res = await query.orderBy('updatedAt', 'desc').skip(skip).limit(limit).get();
      let data = res.data || [];

      if (keyword) {
        const kw = keyword.toLowerCase();
        data = data.filter(
          (row) =>
            String(row.title || '').toLowerCase().includes(kw) ||
            String(row.note || '').toLowerCase().includes(kw) ||
            (row.tags || []).some((t) => String(t).toLowerCase().includes(kw)) ||
            (row.colors || []).some((c) => String(c).toLowerCase().includes(kw)),
        );
      }

      const tempUrls = await getTempUrls(data.map((r) => r.fileID).filter(Boolean));
      data = data.map((row) => ({ ...row, tempUrl: row.fileID ? tempUrls[row.fileID] || '' : '' }));
      return jsonResponse({ code: 0, msg: 'ok', total: data.length, data });
    }

    if (action === 'getItem') {
      const id = String(body.id || body._id || '').trim();
      if (!id) return jsonResponse({ code: 4002, msg: '缺少 id' });
      const res = await items.doc(id).get();
      if (!res.data || res.data.userId !== ownerId) return jsonResponse({ code: 4004, msg: '条目不存在' });
      let tempUrl = '';
      if (res.data.fileID) {
        const urls = await getTempUrls([res.data.fileID]);
        tempUrl = urls[res.data.fileID] || '';
      }
      return jsonResponse({ code: 0, msg: 'ok', data: { ...res.data, tempUrl } });
    }

    if (action === 'deleteItem') {
      const id = String(body.id || body._id || '').trim();
      if (!id) return jsonResponse({ code: 4002, msg: '缺少 id' });
      const res = await items.doc(id).get();
      if (!res.data || res.data.userId !== ownerId) return jsonResponse({ code: 4004, msg: '条目不存在' });
      if (res.data.fileID) {
        try {
          await cloud.deleteFile({ fileList: [res.data.fileID] });
        } catch (err) {
          console.warn('deleteFile failed:', err.message || err);
        }
      }
      await items.doc(id).remove();
      return jsonResponse({ code: 0, msg: 'deleted' });
    }

    if (action === 'getTempUrls') {
      const fileIDs = Array.isArray(body.fileIDs) ? body.fileIDs : [];
      const tempUrls = await getTempUrls(fileIDs);
      return jsonResponse({ code: 0, msg: 'ok', data: tempUrls });
    }

    return jsonResponse({
      code: 4001,
      msg: '未知操作',
      action,
      supported: [
        'ping',
        'getServiceConfig',
        'registerDevice',
        'sendEmailCode',
        'registerEmail',
        'loginEmail',
        'getAccountProfile',
        'listMemberPlans',
        'getMembershipStatus',
        'createMemberOrder',
        'confirmMemberOrder',
        'queryMemberOrder',
        'prepareUpload',
        'listCategories',
        'saveCategory',
        'deleteCategory',
        'saveItem',
        'listItems',
        'getItem',
        'deleteItem',
        'getTempUrls',
      ],
    });
  } catch (err) {
    console.error('organize_life error:', err);
    return jsonResponse({ code: 9999, msg: err.message || 'internal error' });
  }
};
