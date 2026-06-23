import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  bool _loading = true;
  bool _paying = false;
  String _selectedPlan = 'lifetime';
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cloud = ref.read(cloudApiProvider);
      await cloud.init();
      if (!cloud.session.isLoggedIn) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final plansRes = await cloud.listMemberPlans();
      final status = await cloud.getMembershipStatus();
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(plansRes['plans'] ?? []);
          _status = status;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _planPrice(Map<String, dynamic> plan, AppLocalizations l10n) {
    final fen = plan['priceFen'] as int? ?? 0;
    return '¥${(fen / 100).toStringAsFixed(2)}';
  }

  String _planSubtitle(String id, AppLocalizations l10n) {
    switch (id) {
      case 'monthly':
        return l10n.planNoAutoRenew;
      case 'yearly':
        return l10n.planDiscount50;
      case 'lifetime':
        return l10n.planOneTime;
      default:
        return '';
    }
  }

  String _planName(String id, AppLocalizations l10n) {
    switch (id) {
      case 'monthly':
        return l10n.planMonthly;
      case 'yearly':
        return l10n.planYearly;
      case 'lifetime':
        return l10n.planLifetime;
      default:
        return id;
    }
  }

  Future<void> _upgrade() async {
    final l10n = AppLocalizations.of(context)!;
    final cloud = ref.read(cloudApiProvider);
    if (!cloud.session.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberLoginRequired)));
      return;
    }

    final channel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.selectPayMethod, style: Theme.of(ctx).textTheme.titleMedium)),
            ListTile(
              leading: const Icon(Icons.wechat, color: Color(0xFF07C160)),
              title: Text(l10n.payWechat),
              onTap: () => Navigator.pop(ctx, 'wechat'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1677FF)),
              title: Text(l10n.payAlipay),
              onTap: () => Navigator.pop(ctx, 'alipay'),
            ),
          ],
        ),
      ),
    );
    if (channel == null || !mounted) return;

    setState(() => _paying = true);
    try {
      final order = await cloud.createMemberOrder(planId: _selectedPlan, channel: channel);
      final orderId = order['orderId']?.toString() ?? '';

      if (order['mockPay'] == true) {
        await cloud.confirmMemberOrder(orderId: orderId, mockPaid: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberUpgradeSuccess)));
          await _load();
        }
        return;
      }

      final payment = ref.read(paymentServiceProvider);
      if (channel == 'wechat') {
        final wechat = Map<String, dynamic>.from(order['wechat'] ?? {});
        final ok = await payment.payWechat(wechat);
        if (!ok) throw Exception(l10n.memberPayFailed);
      } else {
        final orderString = order['orderString']?.toString() ?? '';
        if (orderString.isEmpty) throw Exception(l10n.memberPayFailed);
        final result = await payment.payAlipay(orderString);
        if (!payment.isAlipaySuccess(result)) throw Exception(l10n.memberPayFailed);
      }

      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final q = await cloud.queryMemberOrder(orderId);
        if (q['status'] == 'paid' || (q['member'] as Map?)?['isMember'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberUpgradeSuccess)));
            await _load();
          }
          return;
        }
      }
      final confirmed = await cloud.confirmMemberOrder(orderId: orderId);
      if ((confirmed['member'] as Map?)?['isMember'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberUpgradeSuccess)));
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberPayPending)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cloud = ref.watch(cloudApiProvider);
    final isMember = _status?['isMember'] == true || cloud.session.isMember;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.membership)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !cloud.session.isLoggedIn
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.memberLoginRequired, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      l10n.memberSlogan,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMember ? l10n.memberActive : l10n.memberNotMember,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isMember ? Colors.green[700] : Colors.grey[600]),
                    ),
                    if (isMember && (_status?['expireAt']?.toString().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.memberExpireAt(_status!['expireAt'].toString()),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 4, height: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.memberExclusive, style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FeatureTable(l10n: l10n),
                    const SizedBox(height: 24),
                    Row(
                      children: _plans.map((plan) {
                        final id = plan['id']?.toString() ?? '';
                        final selected = _selectedPlan == id;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPlan = id),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(_planName(id, l10n), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text(_planPrice(plan, l10n), style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      _planSubtitle(id, l10n),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _paying ? null : _upgrade,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: _paying
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isMember ? l10n.memberRenew : l10n.upgradeNow),
                    ),
                  ],
                ),
    );
  }
}

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      border: TableBorder.all(color: Colors.grey.shade200),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            const SizedBox.shrink(),
            Padding(padding: const EdgeInsets.all(8), child: Text(l10n.memberRegularUser, style: const TextStyle(fontSize: 12))),
            Padding(padding: const EdgeInsets.all(8), child: Text(l10n.memberMember, style: const TextStyle(fontSize: 12))),
          ],
        ),
        _row(l10n.memberFeatureItems, '30', l10n.memberUnlimited),
        _row(l10n.memberCloudBackup, '✕', '✓', freeBad: true, memberGood: true),
        _row(l10n.memberNewFeatures, '✕', '✓', freeBad: true, memberGood: true),
      ],
    );
  }

  TableRow _row(String label, String free, String member, {bool freeBad = false, bool memberGood = false}) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(10), child: Text(label, style: const TextStyle(fontSize: 13))),
        Center(
          child: Text(
            free,
            style: TextStyle(color: freeBad ? Colors.grey : null, fontWeight: FontWeight.w500),
          ),
        ),
        Center(
          child: Text(
            member,
            style: TextStyle(color: memberGood ? Colors.blue : null, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
