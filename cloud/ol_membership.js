'use strict';

const crypto = require('crypto');
const https = require('https');

const CODE_TTL_MS = 5 * 60 * 1000;
const CODE_COOLDOWN_MS = 60 * 1000;
const FREE_ITEM_LIMIT = 30;

const MEMBER_PLANS = {
  monthly: { id: 'monthly', name: '月会员', priceFen: 800, days: 30 },
  yearly: { id: 'yearly', name: '年会员', priceFen: 4800, days: 365 },
  lifetime: { id: 'lifetime', name: '永久会员', priceFen: 8800, days: 36500 },
};

function resolveNotifyUrl(type) {
  const explicit = type === 'wechat' ? process.env.WECHAT_NOTIFY_URL : process.env.ALIPAY_NOTIFY_URL;
  if (explicit) return explicit;
  const base = (process.env.OL_API_BASE_URL || '').replace(/\/$/, '');
  if (!base) return '';
  return `${base}?notify=${type}`;
}

function createMembershipHelpers(ctx) {
  const {
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
  } = ctx;

  const emailCodes = db.collection('ol_email_codes');
  const orders = db.collection('ol_orders');

  function randomDigits(n) {
    let s = '';
    for (let i = 0; i < n; i++) s += Math.floor(Math.random() * 10);
    return s;
  }

  function memberSnapshot(account) {
    if (!account) {
      return { isMember: false, planId: '', expireAt: '', itemLimit: FREE_ITEM_LIMIT, cloudBackup: false };
    }
    const planId = account.memberPlanId || '';
    const expireAt = account.memberExpireAt || '';
    let isMember = false;
    if (planId === 'lifetime') {
      isMember = true;
    } else if (expireAt) {
      isMember = Date.parse(String(expireAt).replace(' ', 'T')) > Date.now();
    }
    return {
      isMember,
      planId: isMember ? planId : '',
      expireAt: isMember ? expireAt : '',
      itemLimit: isMember ? -1 : FREE_ITEM_LIMIT,
      cloudBackup: isMember,
    };
  }

  async function sendVerificationEmail(email, code) {
    const subject = '整理人生 - 注册验证码';
    const html = `<p>您的验证码是 <b style="font-size:20px">${code}</b>，5 分钟内有效。</p><p>如非本人操作请忽略。</p>`;

    const sendCloudUser = process.env.SENDCLOUD_API_USER;
    const sendCloudKey = process.env.SENDCLOUD_API_KEY;
    if (sendCloudUser && sendCloudKey) {
      const form = new URLSearchParams();
      form.append('apiUser', sendCloudUser);
      form.append('apiKey', sendCloudKey);
      form.append('from', process.env.SENDCLOUD_FROM || 'noreply@organize-life.app');
      form.append('to', email);
      form.append('subject', subject);
      form.append('html', html);
      const r = await fetch('https://api.sendcloud.net/apiv2/mail/send', { method: 'POST', body: form });
      const j = await r.json();
      if (!j.result) throw new Error(j.message || 'SendCloud 发送失败');
      return;
    }

    const webhook = process.env.OL_EMAIL_WEBHOOK_URL;
    if (webhook) {
      const r = await fetch(webhook, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: email, subject, html, code }),
      });
      if (!r.ok) throw new Error(`邮件 Webhook 失败: HTTP ${r.status}`);
      return;
    }

    if (process.env.OL_DEBUG_EMAIL === '1') {
      console.log('[DEBUG EMAIL]', email, code);
      return;
    }

    throw new Error('邮件服务未配置（SENDCLOUD_* 或 OL_EMAIL_WEBHOOK_URL）');
  }

  async function verifyEmailCode(email, code) {
    const res = await emailCodes.where({ email, code, used: false }).limit(20).get();
    const rows = res.data || [];
    const now = Date.now();
    for (const row of rows) {
      const exp = typeof row.expireAt === 'number' ? row.expireAt : Date.parse(String(row.expireAt));
      if (exp && now > exp) continue;
      await emailCodes.doc(row._id).update({ data: { used: true, usedAt: beijingNow() } });
      return true;
    }
    return false;
  }

  async function handleSendEmailCode(body) {
    const email = normalizeEmail(body.email);
    if (!validateEmail(email)) return jsonResponse({ code: 4002, msg: '邮箱格式不正确' });
    if (await findAccountByEmail(email)) return jsonResponse({ code: 4006, msg: '该邮箱已注册' });

    const recent = await emailCodes.where({ email }).limit(5).get();
    const now = Date.now();
    for (const row of recent.data || []) {
      const created = Date.parse(String(row.createdAt || '').replace(' ', 'T'));
      if (created && now - created < CODE_COOLDOWN_MS) {
        return jsonResponse({ code: 4029, msg: '发送过于频繁，请稍后再试' });
      }
    }

    const code = randomDigits(6);
    await emailCodes.add({
      data: {
        email,
        code,
        expireAt: now + CODE_TTL_MS,
        used: false,
        createdAt: beijingNow(),
      },
    });

    try {
      await sendVerificationEmail(email, code);
    } catch (err) {
      return jsonResponse({ code: 5001, msg: `验证码发送失败: ${err.message}` });
    }

    const data = { expireIn: Math.floor(CODE_TTL_MS / 1000) };
    if (process.env.OL_DEBUG_EMAIL === '1') data.debugCode = code;
    return jsonResponse({ code: 0, msg: 'sent', data });
  }

  function alipaySign(content, privateKeyPem) {
    const signer = crypto.createSign('RSA-SHA256');
    signer.update(content, 'utf8');
    return signer.sign(privateKeyPem, 'base64');
  }

  function buildAlipayOrderString(orderId, amountFen, subject) {
    const appId = process.env.ALIPAY_APP_ID;
    const privateKey = (process.env.ALIPAY_PRIVATE_KEY || '').replace(/\\n/g, '\n');
    if (!appId || !privateKey) return null;

    const bizContent = JSON.stringify({
      out_trade_no: orderId,
      total_amount: (amountFen / 100).toFixed(2),
      subject,
      product_code: 'QUICK_MSECURITY_PAY',
    });

    const params = {
      app_id: appId,
      method: 'alipay.trade.app.pay',
      charset: 'utf-8',
      sign_type: 'RSA2',
      timestamp: beijingNow(),
      version: '1.0',
      notify_url: resolveNotifyUrl('alipay'),
      biz_content: bizContent,
    };

    const signContent = Object.keys(params)
      .sort()
      .map((k) => `${k}=${params[k]}`)
      .join('&');
    params.sign = alipaySign(signContent, privateKey);

    return Object.keys(params)
      .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`)
      .join('&');
  }

  function buildXml(obj) {
    let s = '<xml>';
    for (const [k, v] of Object.entries(obj)) {
      if (v === undefined || v === null || v === '') continue;
      s += `<${k}><![CDATA[${v}]]></${k}>`;
    }
    s += '</xml>';
    return s;
  }

  function parseXmlSimple(xml) {
    const out = {};
    const re = /<(\w+)>(?:<!\[CDATA\[([^\]]*)\]\]|([^<]*))<\/\1>/g;
    let m;
    while ((m = re.exec(xml))) out[m[1]] = m[2] ?? m[3];
    return out;
  }

  function wechatSign(params, apiKey) {
    const keys = Object.keys(params)
      .filter((k) => params[k] !== '' && k !== 'sign')
      .sort();
    const str = `${keys.map((k) => `${k}=${params[k]}`).join('&')}&key=${apiKey}`;
    return crypto.createHash('md5').update(str, 'utf8').digest('hex').toUpperCase();
  }

  function httpsPostXml(url, xml) {
    return new Promise((resolve, reject) => {
      const u = new URL(url);
      const req = https.request(
        {
          hostname: u.hostname,
          path: u.pathname,
          method: 'POST',
          headers: { 'Content-Type': 'text/xml', 'Content-Length': Buffer.byteLength(xml) },
        },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => resolve(data));
        },
      );
      req.on('error', reject);
      req.write(xml);
      req.end();
    });
  }

  async function buildWechatAppPay(orderId, amountFen, description) {
    const appId = process.env.WECHAT_APP_ID;
    const mchId = process.env.WECHAT_MCH_ID;
    const apiKey = process.env.WECHAT_API_KEY;
    if (!appId || !mchId || !apiKey) return null;

    const notifyUrl = resolveNotifyUrl('wechat');
    if (!notifyUrl) throw new Error('请配置 WECHAT_NOTIFY_URL 或 OL_API_BASE_URL');

    const unified = {
      appid: appId,
      mch_id: mchId,
      nonce_str: crypto.randomBytes(16).toString('hex'),
      body: description,
      out_trade_no: orderId,
      total_fee: String(amountFen),
      spbill_create_ip: '127.0.0.1',
      notify_url: notifyUrl,
      trade_type: 'APP',
    };
    unified.sign = wechatSign(unified, apiKey);
    const xmlResp = await httpsPostXml('https://api.mch.weixin.qq.com/pay/unifiedorder', buildXml(unified));
    const parsed = parseXmlSimple(xmlResp);
    if (parsed.return_code !== 'SUCCESS' || parsed.result_code !== 'SUCCESS') {
      throw new Error(parsed.return_msg || parsed.err_code_des || '微信下单失败');
    }

    const ts = String(Math.floor(Date.now() / 1000));
    const appParams = {
      appid: appId,
      partnerid: mchId,
      prepayid: parsed.prepay_id,
      package: 'Sign=WXPay',
      noncestr: crypto.randomBytes(16).toString('hex'),
      timestamp: ts,
    };
    appParams.sign = wechatSign(appParams, apiKey);
    return appParams;
  }

  function verifyWechatNotifySign(params, apiKey) {
    if (!apiKey || !params.sign) return false;
    const sign = params.sign;
    const copy = { ...params };
    delete copy.sign;
    return wechatSign(copy, apiKey) === sign;
  }

  function verifyAlipayNotifySign(params) {
    const publicKey = (process.env.ALIPAY_PUBLIC_KEY || '').replace(/\\n/g, '\n');
    const sign = params.sign;
    const signType = params.sign_type || 'RSA2';
    if (!publicKey || !sign || signType !== 'RSA2') return false;
    const keys = Object.keys(params)
      .filter((k) => k !== 'sign' && k !== 'sign_type' && params[k] !== '' && params[k] != null)
      .sort();
    const content = keys.map((k) => `${k}=${params[k]}`).join('&');
    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(content, 'utf8');
    return verifier.verify(publicKey, sign, 'base64');
  }

  async function findOrderByOrderId(orderId) {
    const res = await orders.where({ orderId }).limit(1).get();
    return res.data?.[0] || null;
  }

  async function markOrderPaid(orderId, channel, extra = {}) {
    const order = await findOrderByOrderId(orderId);
    if (!order) return { ok: false, reason: 'order_not_found' };
    if (order.status === 'paid') return { ok: true, already: true, accountId: order.accountId };

    const amountFen = parseInt(order.amountFen, 10);
    if (extra.amountFen != null && extra.amountFen !== amountFen) {
      return { ok: false, reason: 'amount_mismatch' };
    }

    await orders.doc(order._id).update({
      data: {
        status: 'paid',
        paidAt: beijingNow(),
        updatedAt: beijingNow(),
        payChannel: channel,
        tradeNo: extra.tradeNo || '',
        notifyRaw: extra.notifyRaw || '',
      },
    });
    await activateMembership(order.accountId, order.planId);
    return { ok: true, accountId: order.accountId, planId: order.planId };
  }

  async function handleWechatPayNotify(rawXml) {
    const apiKey = process.env.WECHAT_API_KEY;
    if (!apiKey) {
      return xmlResponse(buildXml({ return_code: 'FAIL', return_msg: 'wechat not configured' }));
    }

    const params = parseXmlSimple(rawXml || '');
    if (params.return_code !== 'SUCCESS') {
      return xmlResponse(buildXml({ return_code: 'FAIL', return_msg: 'return_code fail' }));
    }
    if (!verifyWechatNotifySign(params, apiKey)) {
      console.warn('wechat notify sign invalid', params.out_trade_no);
      return xmlResponse(buildXml({ return_code: 'FAIL', return_msg: 'sign invalid' }));
    }
    if (params.result_code !== 'SUCCESS') {
      return xmlResponse(buildXml({ return_code: 'SUCCESS', return_msg: 'OK' }));
    }

    const orderId = params.out_trade_no;
    const amountFen = parseInt(params.total_fee || '0', 10);
    const result = await markOrderPaid(orderId, 'wechat', {
      amountFen,
      tradeNo: params.transaction_id || '',
      notifyRaw: rawXml.slice(0, 2000),
    });

    if (!result.ok && result.reason === 'amount_mismatch') {
      return xmlResponse(buildXml({ return_code: 'FAIL', return_msg: 'amount mismatch' }));
    }
    return xmlResponse(buildXml({ return_code: 'SUCCESS', return_msg: 'OK' }));
  }

  async function handleAlipayPayNotify(params) {
    const appId = process.env.ALIPAY_APP_ID;
    if (!appId) return textResponse('failure');

    if (params.app_id && params.app_id !== appId) {
      console.warn('alipay notify app_id mismatch', params.app_id);
      return textResponse('failure');
    }
    if (!verifyAlipayNotifySign(params)) {
      console.warn('alipay notify sign invalid', params.out_trade_no);
      return textResponse('failure');
    }

    const tradeStatus = params.trade_status || '';
    if (tradeStatus !== 'TRADE_SUCCESS' && tradeStatus !== 'TRADE_FINISHED') {
      return textResponse('success');
    }

    const orderId = params.out_trade_no;
    const amountYuan = parseFloat(params.total_amount || '0');
    const amountFen = Math.round(amountYuan * 100);
    const result = await markOrderPaid(orderId, 'alipay', {
      amountFen,
      tradeNo: params.trade_no || '',
      notifyRaw: JSON.stringify(params).slice(0, 2000),
    });

    if (!result.ok && result.reason === 'amount_mismatch') return textResponse('failure');
    return textResponse('success');
  }

  async function handleGetServiceConfig() {
    const emailReady = !!(
      (process.env.SENDCLOUD_API_USER && process.env.SENDCLOUD_API_KEY) ||
      process.env.OL_EMAIL_WEBHOOK_URL
    );
    const wechatReady = !!(
      process.env.WECHAT_APP_ID &&
      process.env.WECHAT_MCH_ID &&
      process.env.WECHAT_API_KEY
    );
    const alipayReady = !!(process.env.ALIPAY_APP_ID && process.env.ALIPAY_PRIVATE_KEY && process.env.ALIPAY_PUBLIC_KEY);

    return jsonResponse({
      code: 0,
      msg: 'ok',
      data: {
        version: '1.5.1',
        email: {
          configured: emailReady,
          sendcloud: !!(process.env.SENDCLOUD_API_USER && process.env.SENDCLOUD_API_KEY),
          webhook: !!process.env.OL_EMAIL_WEBHOOK_URL,
          debug: process.env.OL_DEBUG_EMAIL === '1',
          requireCode: process.env.OL_REQUIRE_EMAIL_CODE === '1',
          canSend: emailReady || process.env.OL_DEBUG_EMAIL === '1',
        },
        pay: {
          wechat: wechatReady,
          alipay: alipayReady,
          debug: process.env.OL_PAY_DEBUG === '1',
          canPay: wechatReady || alipayReady || process.env.OL_PAY_DEBUG === '1',
          wechatNotifyUrl: resolveNotifyUrl('wechat'),
          alipayNotifyUrl: resolveNotifyUrl('alipay'),
        },
        hints: [
          '默认邮箱+密码即可注册，无需验证码（免费）',
          '若需邮箱验证码：配置 SendCloud 并设 OL_REQUIRE_EMAIL_CODE=1',
          '商户号/AppId 未就绪时可设 OL_PAY_DEBUG=1 联调会员',
        ],
      },
    });
  }

  async function activateMembership(accountId, planId) {
    const plan = MEMBER_PLANS[planId];
    if (!plan) throw new Error('invalid plan');
    const account = await findAccountById(accountId);
    if (!account) throw new Error('account missing');

    let expireAt = '';
    if (planId === 'lifetime') {
      expireAt = '2099-12-31 23:59:59';
    } else {
      const base = memberSnapshot(account).isMember && account.memberExpireAt
        ? Date.parse(String(account.memberExpireAt).replace(' ', 'T'))
        : Date.now();
      expireAt = new Date(Math.max(Date.now(), base) + plan.days * 86400000)
        .toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false })
        .replace(/\//g, '-');
    }

    await accounts.doc(account._id).update({
      data: {
        memberPlanId: planId,
        memberExpireAt: expireAt,
        updatedAt: beijingNow(),
      },
    });
    return { planId, expireAt };
  }

  async function handleListMemberPlans() {
    return jsonResponse({
      code: 0,
      msg: 'ok',
      data: {
        plans: Object.values(MEMBER_PLANS),
        freeItemLimit: FREE_ITEM_LIMIT,
        features: [
          { key: 'items', free: '30', member: '无限' },
          { key: 'cloudBackup', free: false, member: true },
          { key: 'autoBackup', free: false, member: true },
        ],
      },
    });
  }

  async function handleGetMembershipStatus(body, event, resolveOwner) {
    const { ownerId, isLoggedIn } = await resolveOwner(body, event);
    if (!isLoggedIn) return jsonResponse({ code: 4010, msg: '请先登录' });
    const account = await findAccountById(ownerId);
    const member = memberSnapshot(account);
    const itemCount = (await items.where({ userId: ownerId }).count()).total || 0;
    return jsonResponse({
      code: 0,
      msg: 'ok',
      data: { ...member, itemCount, plans: Object.values(MEMBER_PLANS) },
    });
  }

  async function handleCreateMemberOrder(body, event, resolveOwner) {
    const { ownerId, isLoggedIn } = await resolveOwner(body, event);
    if (!isLoggedIn) return jsonResponse({ code: 4010, msg: '请先登录' });

    const planId = String(body.planId || '').trim();
    const channel = String(body.channel || '').trim();
    const plan = MEMBER_PLANS[planId];
    if (!plan) return jsonResponse({ code: 4002, msg: '无效的会员套餐' });
    if (channel !== 'wechat' && channel !== 'alipay') {
      return jsonResponse({ code: 4002, msg: 'channel 需为 wechat 或 alipay' });
    }

    const orderId = `ol_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const now = beijingNow();
    await orders.add({
      data: {
        orderId,
        accountId: ownerId,
        planId,
        amountFen: plan.priceFen,
        channel,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      },
    });

    const payDebug = process.env.OL_PAY_DEBUG === '1';
    if (payDebug) {
      return jsonResponse({
        code: 0,
        msg: 'mock',
        data: {
          orderId,
          planId,
          amountFen: plan.priceFen,
          channel,
          mockPay: true,
        },
      });
    }

    try {
      if (channel === 'alipay') {
        const orderString = buildAlipayOrderString(orderId, plan.priceFen, `整理人生-${plan.name}`);
        if (!orderString) return jsonResponse({ code: 5002, msg: '支付宝未配置（ALIPAY_APP_ID / ALIPAY_PRIVATE_KEY）' });
        return jsonResponse({ code: 0, msg: 'ok', data: { orderId, channel, orderString } });
      }

      const wechatParams = await buildWechatAppPay(orderId, plan.priceFen, `整理人生-${plan.name}`);
      if (!wechatParams) return jsonResponse({ code: 5002, msg: '微信支付未配置（WECHAT_APP_ID / WECHAT_MCH_ID / WECHAT_API_KEY）' });
      return jsonResponse({ code: 0, msg: 'ok', data: { orderId, channel, wechat: wechatParams } });
    } catch (err) {
      return jsonResponse({ code: 5002, msg: `创建支付失败: ${err.message}` });
    }
  }

  async function handleConfirmMemberOrder(body, event, resolveOwner) {
    const { ownerId, isLoggedIn } = await resolveOwner(body, event);
    if (!isLoggedIn) return jsonResponse({ code: 4010, msg: '请先登录' });

    const orderId = String(body.orderId || '').trim();
    if (!orderId) return jsonResponse({ code: 4002, msg: '缺少 orderId' });

    const res = await orders.where({ orderId, accountId: ownerId }).limit(1).get();
    const order = res.data?.[0];
    if (!order) return jsonResponse({ code: 4004, msg: '订单不存在' });
    if (order.status === 'paid') {
      const account = await findAccountById(ownerId);
      return jsonResponse({ code: 0, msg: 'ok', data: { member: memberSnapshot(account) } });
    }

    if (process.env.OL_PAY_DEBUG === '1' && body.mockPaid === true) {
      await orders.doc(order._id).update({ data: { status: 'paid', paidAt: beijingNow(), updatedAt: beijingNow() } });
      const member = await activateMembership(ownerId, order.planId);
      return jsonResponse({ code: 0, msg: 'paid', data: { member: { ...memberSnapshot(await findAccountById(ownerId)), ...member } } });
    }

    return jsonResponse({ code: 4028, msg: '订单待支付，请完成支付后查询' });
  }

  async function handleQueryMemberOrder(body, event, resolveOwner) {
    const { ownerId, isLoggedIn } = await resolveOwner(body, event);
    if (!isLoggedIn) return jsonResponse({ code: 4010, msg: '请先登录' });
    const orderId = String(body.orderId || '').trim();
    const res = await orders.where({ orderId, accountId: ownerId }).limit(1).get();
    const order = res.data?.[0];
    if (!order) return jsonResponse({ code: 4004, msg: '订单不存在' });
    const account = await findAccountById(ownerId);
    return jsonResponse({
      code: 0,
      msg: 'ok',
      data: { status: order.status, member: memberSnapshot(account) },
    });
  }

  return {
    MEMBER_PLANS,
    FREE_ITEM_LIMIT,
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
    activateMembership,
    resolveNotifyUrl,
  };
}

module.exports = { createMembershipHelpers, MEMBER_PLANS, FREE_ITEM_LIMIT, resolveNotifyUrl };
