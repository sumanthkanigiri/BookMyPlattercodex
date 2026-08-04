import 'dart:convert';

import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('profiles').select(
    'id,full_name,phone,created_at,orders(id),'
    'loyalty_accounts(points,wallet_balance)',
  ).eq('role', 'customer').order('created_at', ascending: false).limit(500);
  return List<Map<String, dynamic>>.from(rows);
});
final reportProvider = FutureProvider<Map<String,double>>((ref) async { final c=ref.watch(supabaseProvider); final payments=await c.from('payments').select('amount,status'); final expenses=await c.from('business_expenses').select('amount'); double paid=0,pending=0,refund=0,cost=0; for(final r in payments){final v=(r['amount'] as num).toDouble(); if(r['status']=='paid')paid+=v;else if(r['status']=='refunded')refund+=v;else pending+=v;} for(final r in expenses)cost+=(r['amount'] as num).toDouble(); return {'Revenue':paid,'Pending':pending,'Refunds':refund,'Expenses':cost,'Profit':paid-refund-cost};});
final configProvider = FutureProvider<List<Map<String,dynamic>>>((ref) async => List<Map<String,dynamic>>.from(await ref.watch(supabaseProvider).from('app_config').select('key,value,is_public,updated_at').order('key')));

class ManagementScreen extends ConsumerWidget { const ManagementScreen({super.key});
 @override Widget build(BuildContext context,WidgetRef ref)=>DefaultTabController(length:4,child:Column(children:[const TabBar(isScrollable:true,tabs:[Tab(icon:Icon(Icons.people_outline),text:'Customers'),Tab(icon:Icon(Icons.analytics_outlined),text:'Reports'),Tab(icon:Icon(Icons.notifications_outlined),text:'Notifications'),Tab(icon:Icon(Icons.settings_outlined),text:'Settings')]),Expanded(child:TabBarView(children:[_Customers(),_Reports(),_Notify(),_Settings()]))]));}
class _Customers extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(customersProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(
        error,
        () => ref.invalidate(customersProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No customers found.'));
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(customersProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final row = rows[index];
              final orders = (row['orders'] as List?)?.length ?? 0;
              final loyalty = _relatedRecord(row['loyalty_accounts']);
              final name = (row['full_name'] as String?)?.trim();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    name == null || name.isEmpty ? 'Unnamed customer' : name,
                  ),
                  subtitle: Text('${row['phone'] ?? 'No phone'} • $orders bookings'),
                  trailing: Text('${loyalty?['points'] ?? 0} points'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Map<String, dynamic>? _relatedRecord(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}
class _Reports extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(reportProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(error, () => ref.invalidate(reportProvider)),
      data: (values) {
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 1100 ? 3 : width >= 650 ? 2 : 1;
        return GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: columns,
          childAspectRatio: columns == 1 ? 3 : 2,
          children: [
            for (final entry in values.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key),
                      Text(
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                            .format(entry.value),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
class _Notify extends ConsumerStatefulWidget{@override ConsumerState<_Notify> createState()=>_NotifyState();} class _NotifyState extends ConsumerState<_Notify>{final user=TextEditingController(),title=TextEditingController(),body=TextEditingController();bool sending=false;@override void dispose(){user.dispose();title.dispose();body.dispose();super.dispose();}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(24),children:[TextField(controller:user,decoration:const InputDecoration(labelText:'Customer profile UUID')),const SizedBox(height:12),TextField(controller:title,maxLength:100,decoration:const InputDecoration(labelText:'Title')),TextField(controller:body,maxLength:1000,maxLines:5,decoration:const InputDecoration(labelText:'Message')),FilledButton(onPressed:sending?null:()async{if(!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(user.text)||title.text.trim().length<2||body.text.trim().length<2){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Complete all fields')));return;}setState(()=>sending=true);try{final r=await ref.read(supabaseProvider).functions.invoke('operations-notify',body:{'userId':user.text.trim(),'title':title.text.trim(),'message':body.text.trim(),'channels':['push']});if(r.status>=300)throw StateError('Delivery failed');if(c.mounted){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Notification queued')));title.clear();body.clear();}}catch(error){if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('Unable to send notification: $error')));}finally{if(mounted)setState(()=>sending=false);}},child:const Text('Send notification'))]);}}
class _Settings extends ConsumerWidget{@override Widget build(BuildContext c,WidgetRef ref)=>ref.watch(configProvider).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>_Retry(e,()=>ref.invalidate(configProvider)),data:(rows)=>ListView(padding:const EdgeInsets.all(20),children:[for(final r in rows)Card(child:ListTile(title:Text(r['key'] as String),subtitle:SelectableText(jsonEncode(r['value'])),trailing:const Icon(Icons.edit_outlined),onTap:()=>_edit(c,ref,r)))])); Future<void> _edit(BuildContext c,WidgetRef ref,Map<String,dynamic> row)async{final controller=TextEditingController(text:const JsonEncoder.withIndent('  ').convert(row['value']));final value=await showDialog<String>(context:c,builder:(d)=>AlertDialog(title:Text('Edit ${row['key']}'),content:SizedBox(width:520,child:TextField(controller:controller,minLines:8,maxLines:18,decoration:const InputDecoration(labelText:'JSON value'))),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:(){try{jsonDecode(controller.text);Navigator.pop(d,controller.text);}catch(_){ScaffoldMessenger.of(d).showSnackBar(const SnackBar(content:Text('Enter valid JSON')));}},child:const Text('Save'))]));controller.dispose();if(value==null)return;await ref.read(supabaseProvider).from('app_config').update({'value':jsonDecode(value)}).eq('key',row['key']);ref.invalidate(configProvider);}}
class _Retry extends StatelessWidget{const _Retry(this.error,this.retry);final Object error;final VoidCallback retry;@override Widget build(BuildContext c)=>Center(child:FilledButton.icon(onPressed:retry,icon:const Icon(Icons.refresh),label:Text(error.toString())));}
