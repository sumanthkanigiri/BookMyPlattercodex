import 'package:bookmyplatter_admin/src/features/operations/operations_repository.dart';
import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(operationsRealtimeProvider);
    final role = ref.watch(adminIdentityProvider).valueOrNull?.role;
    final financeAccess = role == 'admin' || role == 'support';
    final tabs = <Tab>[
      const Tab(icon: Icon(Icons.soup_kitchen_outlined), text: 'Kitchen'),
      const Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Delivery'),
      const Tab(icon: Icon(Icons.inventory_outlined), text: 'Inventory'),
      const Tab(icon: Icon(Icons.badge_outlined), text: 'Staff'),
      const Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar'),
      if (financeAccess) const Tab(icon: Icon(Icons.account_balance_outlined), text: 'Finance'),
    ];
    final views = <Widget>[const _KitchenTab(), const _DeliveryTab(), const _InventoryTab(), const _StaffTab(), const _CalendarTab(), if (financeAccess) const _FinanceTab()];
    return DefaultTabController(
        length: tabs.length,
        child: Column(children: [
          Material(
            color: Colors.white,
            child: TabBar(isScrollable: true, tabs: tabs),
          ),
          Expanded(child: TabBarView(children: views)),
        ]),
      );
  }
}

class _KitchenTab extends ConsumerWidget {
  const _KitchenTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kitchenOrdersProvider);
    return _Page(title: 'Kitchen dashboard', action: IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(kitchenOrdersProvider), icon: const Icon(Icons.refresh)), child: state.when(
      loading: () => const _Loading(),
      error: (error, _) => _Failure(error: error, retry: () => ref.invalidate(kitchenOrdersProvider)),
      data: (orders) {
        final groups = <String, List<KitchenOrder>>{
          'Today': orders.where((o) => DateUtils.isSameDay(o.eventAt, DateTime.now()) && !const {'delivered','cancelled','refunded'}.contains(o.status)).toList(),
          'Preparation queue': orders.where((o) => const {'confirmed','preparing'}.contains(o.status)).toList(),
          'Ready for dispatch': orders.where((o) => o.status == 'packing').toList(),
          'Upcoming': orders.where((o) => o.eventAt.isAfter(DateTime.now()) && !DateUtils.isSameDay(o.eventAt, DateTime.now())).toList(),
          'Completed': orders.where((o) => o.status == 'delivered').toList(),
          'Cancelled': orders.where((o) => const {'cancelled','refunded'}.contains(o.status)).toList(),
        };
        return ListView(children: [for (final group in groups.entries) ExpansionTile(initiallyExpanded: group.key == 'Today' || group.key == 'Preparation queue', title: Text('${group.key} (${group.value.length})'), children: group.value.isEmpty ? const [ListTile(title: Text('No orders in this queue'))] : [for (final order in group.value) _KitchenOrderTile(order: order)])]);
      },
    ));
  }
}

class _KitchenOrderTile extends ConsumerWidget {
  const _KitchenOrderTile({required this.order});
  final KitchenOrder order;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(child: ListTile(
    leading: CircleAvatar(child: Text('${order.guests}')),
    title: Text('${order.packageName} • ${order.customer}'),
    subtitle: Text('${DateFormat('d MMM, h:mm a').format(order.eventAt)} • ${order.status.replaceAll('_', ' ')}\n${order.kitchenNotes?.isNotEmpty == true ? order.kitchenNotes : order.notes ?? 'No kitchen notes'}'),
    isThreeLine: true,
    trailing: Wrap(children: [IconButton(tooltip: 'Notify customer', icon: const Icon(Icons.notifications_active_outlined), onPressed: () => _notifyCustomer(context, ref, order)), IconButton(tooltip: 'Edit kitchen notes', icon: const Icon(Icons.edit_note), onPressed: () async {
      final notes = await _textDialog(context, 'Kitchen notes', initial: order.kitchenNotes ?? order.notes ?? '', maxLength: 2000);
      if (notes == null) return;
      try { await ref.read(operationsRepositoryProvider).saveKitchenNotes(order.id, notes); ref.invalidate(kitchenOrdersProvider); if (context.mounted) _success(context, 'Kitchen notes saved'); } catch (error) { if (context.mounted) _error(context, error); }
    })]),
  ));

  Future<void> _notifyCustomer(BuildContext context, WidgetRef ref, KitchenOrder order) async {
    final title = TextEditingController(text: 'BookMyPlatter order update');
    final message = TextEditingController(text: 'Your ${order.packageName} booking is ${order.status.replaceAll('_', ' ')}.');
    final selected = <String>{'push'};
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Notify customer'), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'Title')), const SizedBox(height: 8), TextField(controller: message, maxLength: 1000, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')), Wrap(spacing: 8, children: [for (final channel in const ['push','sms','email','whatsapp']) FilterChip(label: Text(channel.toUpperCase()), selected: selected.contains(channel), onSelected: (value) => setState(() => value ? selected.add(channel) : selected.remove(channel)))])])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: selected.isEmpty || title.text.trim().length < 2 || message.text.trim().length < 2 ? null : () => Navigator.pop(dialogContext, true), child: const Text('Send'))])));
    if (accepted != true || !context.mounted) return;
    try { final result = await ref.read(operationsRepositoryProvider).notifyCustomer(userId: order.customerId, orderId: order.id, title: title.text, message: message.text, channels: selected.toList()); if (context.mounted) _success(context, 'Delivered through ${(result['delivered'] as List).join(', ')}'); } catch (error) { if (context.mounted) _error(context, error); }
  }
}

class _DeliveryTab extends ConsumerWidget {
  const _DeliveryTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveriesProvider);
    final orders = ref.watch(kitchenOrdersProvider);
    final staff = ref.watch(staffProvider);
    final role = ref.watch(adminIdentityProvider).valueOrNull?.role;
    final canAssign = role == 'admin' || role == 'support';
    return _Page(title: 'Delivery management', action: canAssign ? FilledButton.icon(onPressed: orders.hasValue && staff.hasValue ? () => _assign(context, ref, orders.requireValue, staff.requireValue) : null, icon: const Icon(Icons.add), label: const Text('Assign delivery')) : null, child: deliveries.when(
      loading: () => const _Loading(),
      error: (error, _) => _Failure(error: error, retry: () => ref.invalidate(deliveriesProvider)),
      data: (items) => items.isEmpty ? const _Empty(icon: Icons.local_shipping_outlined, message: 'No delivery assignments') : ListView(children: [for (final item in items) Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.delivery_dining)), title: Text(item.staffName),
        subtitle: Text('${item.address}\n${item.eta == null ? 'ETA not set' : 'ETA ${DateFormat('d MMM, h:mm a').format(item.eta!)}'}'), isThreeLine: true,
        trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Chip(label: Text(item.status.replaceAll('_', ' '))), IconButton(tooltip: 'Open route', onPressed: item.address.isEmpty ? null : () => launchUrl(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': item.address}), mode: LaunchMode.externalApplication), icon: const Icon(Icons.route)), IconButton(tooltip: 'Verify delivery OTP', onPressed: item.status == 'completed' ? null : () => _verify(context, ref, item.orderId), icon: const Icon(Icons.pin_outlined))]),
      ))]),
    ));
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, List<KitchenOrder> orders, List<StaffMember> staff) async {
    final eligibleOrders = orders.where((o) => const {'confirmed','preparing','packing','out_for_delivery'}.contains(o.status)).toList();
    final drivers = staff.where((s) => s.department == 'delivery' && s.active).toList();
    if (eligibleOrders.isEmpty || drivers.isEmpty) { _error(context, 'An active order and delivery employee are required'); return; }
    String orderId = eligibleOrders.first.id, staffId = drivers.first.id;
    DateTime eta = DateTime.now().add(const Duration(hours: 1));
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Assign delivery'), content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField(value: orderId, decoration: const InputDecoration(labelText: 'Order'), items: [for (final o in eligibleOrders) DropdownMenuItem(value: o.id, child: Text('${o.packageName} • ${o.customer}'))], onChanged: (v) => setState(() => orderId = v!)),
      const SizedBox(height: 12), DropdownButtonFormField(value: staffId, decoration: const InputDecoration(labelText: 'Delivery person'), items: [for (final s in drivers) DropdownMenuItem(value: s.id, child: Text('${s.name} • ${s.employeeCode}'))], onChanged: (v) => setState(() => staffId = v!)),
      const SizedBox(height: 12), ListTile(title: const Text('Estimated arrival'), subtitle: Text(DateFormat('d MMM, h:mm a').format(eta)), trailing: const Icon(Icons.schedule), onTap: () async { final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(eta)); if (time != null) setState(() => eta = DateTime(eta.year, eta.month, eta.day, time.hour, time.minute)); }),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Assign'))])));
    if (accepted != true || !context.mounted) return;
    try { final otp = await ref.read(operationsRepositoryProvider).assignDelivery(orderId: orderId, staffId: staffId, eta: eta); ref.invalidate(deliveriesProvider); if (context.mounted) await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Delivery assigned'), content: Text('Secure venue verification OTP: $otp\n\nSend it only to the customer through an approved communication channel.'), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))])); } catch (error) { if (context.mounted) _error(context, error); }
  }

  Future<void> _verify(BuildContext context, WidgetRef ref, String orderId) async {
    final otp = await _textDialog(context, 'Delivery OTP', maxLength: 6, keyboardType: TextInputType.number);
    if (otp == null || otp.length != 6) { if (otp != null) _error(context, 'Enter the six-digit OTP'); return; }
    try { final verified = await ref.read(operationsRepositoryProvider).verifyOtp(orderId, otp); if (!verified) throw StateError('OTP is invalid or was already used'); ref.invalidate(deliveriesProvider); if (context.mounted) _success(context, 'Delivery confirmed'); } catch (error) { if (context.mounted) _error(context, error); }
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);
    return _Page(title: 'Inventory', action: FilledButton.icon(onPressed: () => _editItem(context, ref), icon: const Icon(Icons.add), label: const Text('Ingredient')), child: state.when(
      loading: () => const _Loading(), error: (error, _) => _Failure(error: error, retry: () => ref.invalidate(inventoryProvider)),
      data: (items) => items.isEmpty ? const _Empty(icon: Icons.inventory_2_outlined, message: 'No ingredients have been added') : ListView(children: [for (final item in items) Card(color: item.lowStock ? const Color(0xFFFFF3E0) : null, child: ListTile(leading: Icon(item.lowStock ? Icons.warning_amber : Icons.inventory_2_outlined, color: item.lowStock ? Colors.deepOrange : null), title: Text(item.name), subtitle: Text('${item.quantity.toStringAsFixed(2)} ${item.unit} • Reorder at ${item.reorderLevel.toStringAsFixed(2)}'), trailing: Wrap(children: [if (item.lowStock) const Chip(label: Text('LOW STOCK')), IconButton(tooltip: 'Stock movement', onPressed: () => _movement(context, ref, item), icon: const Icon(Icons.swap_vert)), IconButton(tooltip: 'Edit', onPressed: () => _editItem(context, ref, item), icon: const Icon(Icons.edit_outlined))])))]),
    ));
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref, [InventoryItem? item]) async {
    final name = TextEditingController(text: item?.name); final reorder = TextEditingController(text: item?.reorderLevel.toString()); final cost = TextEditingController(text: item?.unitCost.toString()); var unit = item?.unit ?? 'kg';
    final ok = await _formDialog(context, item == null ? 'Add ingredient' : 'Edit ingredient', (setState) => [TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Ingredient'), validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter an ingredient name' : null), const SizedBox(height: 12), DropdownButtonFormField(value: unit, decoration: const InputDecoration(labelText: 'Unit'), items: [for (final u in const ['kg','g','l','ml','piece','pack']) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setState(() => unit = v!)), const SizedBox(height: 12), TextFormField(controller: reorder, decoration: const InputDecoration(labelText: 'Reorder level'), keyboardType: TextInputType.number, validator: _nonNegative), const SizedBox(height: 12), TextFormField(controller: cost, decoration: const InputDecoration(labelText: 'Unit cost'), keyboardType: TextInputType.number, validator: _nonNegative)]);
    if (ok != true || !context.mounted) return; try { await ref.read(operationsRepositoryProvider).saveInventoryItem(id: item?.id, name: name.text, unit: unit, reorderLevel: double.parse(reorder.text), unitCost: double.parse(cost.text)); ref.invalidate(inventoryProvider); } catch (error) { if (context.mounted) _error(context, error); }
  }

  Future<void> _movement(BuildContext context, WidgetRef ref, InventoryItem item) async {
    final quantity = TextEditingController(); final reference = TextEditingController(); var type = 'stock_in';
    final ok = await _formDialog(context, 'Update ${item.name}', (setState) => [DropdownButtonFormField(value: type, decoration: const InputDecoration(labelText: 'Movement'), items: const [DropdownMenuItem(value: 'stock_in', child: Text('Stock in')), DropdownMenuItem(value: 'stock_out', child: Text('Stock out')), DropdownMenuItem(value: 'adjustment', child: Text('Positive adjustment'))], onChanged: (v) => setState(() => type = v!)), const SizedBox(height: 12), TextFormField(controller: quantity, decoration: InputDecoration(labelText: 'Quantity (${item.unit})'), keyboardType: TextInputType.number, validator: _positive), const SizedBox(height: 12), TextFormField(controller: reference, maxLength: 120, decoration: const InputDecoration(labelText: 'Invoice / reason'))]);
    if (ok != true || !context.mounted) return; try { await ref.read(operationsRepositoryProvider).moveStock(itemId: item.id, type: type, quantity: double.parse(quantity.text), reference: reference.text); ref.invalidate(inventoryProvider); } catch (error) { if (context.mounted) _error(context, error); }
  }
}

class _StaffTab extends ConsumerWidget {
  const _StaffTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) { final state = ref.watch(staffProvider); final isAdmin = ref.watch(adminIdentityProvider).valueOrNull?.role == 'admin'; return _Page(title: 'Staff & permissions', action: isAdmin ? FilledButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.person_add_alt), label: const Text('Link staff profile')) : null, child: state.when(loading: () => const _Loading(), error: (error, _) => _Failure(error: error, retry: () => ref.invalidate(staffProvider)), data: (items) => items.isEmpty ? const _Empty(icon: Icons.groups_outlined, message: 'No staff profiles linked') : ListView(children: [for (final s in items) Card(child: ListTile(leading: CircleAvatar(child: Text(s.name.characters.first.toUpperCase())), title: Text(s.name), subtitle: Text('${s.employeeCode} • ${s.jobTitle}\n${s.phone}'), isThreeLine: true, trailing: Chip(label: Text(s.department)) ))]))); }
  Future<void> _add(BuildContext context, WidgetRef ref) async { final profile = TextEditingController(); final code = TextEditingController(); final title = TextEditingController(); final phone = TextEditingController(); var department = 'kitchen'; final ok = await _formDialog(context, 'Link existing staff account', (setState) => [TextFormField(controller: profile, decoration: const InputDecoration(labelText: 'Supabase profile UUID'), validator: (v) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid profile UUID'), const SizedBox(height: 12), TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Employee code'), validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Required' : null), const SizedBox(height: 12), DropdownButtonFormField(value: department, decoration: const InputDecoration(labelText: 'Department'), items: [for (final d in const ['kitchen','delivery','operations','support','finance']) DropdownMenuItem(value: d, child: Text(d))], onChanged: (v) => setState(() => department = v!)), const SizedBox(height: 12), TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Job title'), validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Required' : null), const SizedBox(height: 12), TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, validator: (v) => RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid phone')]); if (ok != true || !context.mounted) return; try { await ref.read(operationsRepositoryProvider).saveStaff(profileId: profile.text.trim(), employeeCode: code.text, department: department, jobTitle: title.text, phone: phone.text); ref.invalidate(staffProvider); } catch (error) { if (context.mounted) _error(context, error); } }
}

class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) { final state = ref.watch(kitchenOrdersProvider); return _Page(title: 'Event & delivery calendar', child: state.when(loading: () => const _Loading(), error: (e, _) => _Failure(error: e, retry: () => ref.invalidate(kitchenOrdersProvider)), data: (orders) { final grouped = <DateTime,List<KitchenOrder>>{}; for (final o in orders) { final day=DateTime(o.eventAt.year,o.eventAt.month,o.eventAt.day); grouped.putIfAbsent(day,()=>[]).add(o); } final days=grouped.keys.toList()..sort(); return days.isEmpty ? const _Empty(icon: Icons.event_busy, message: 'No scheduled events') : ListView(children: [for(final day in days) Card(child: ExpansionTile(initiallyExpanded: DateUtils.isSameDay(day, DateTime.now()), title: Text(DateFormat('EEEE, d MMMM').format(day)), subtitle: Text('${grouped[day]!.length} event(s)'), children: [for(final o in grouped[day]!) ListTile(leading: Text(DateFormat('h:mm a').format(o.eventAt)), title: Text(o.packageName), subtitle: Text('${o.customer} • ${o.guests} guests • ${o.address}'), trailing: Chip(label: Text(o.status.replaceAll('_',' '))))]))]); })); }
}

class _FinanceTab extends ConsumerWidget {
  const _FinanceTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) { final state=ref.watch(financeProvider); return _Page(title:'Finance & GST',action: FilledButton.icon(onPressed:()=>_expense(context,ref),icon:const Icon(Icons.add_card),label:const Text('Expense')), child: state.when(loading:()=>const _Loading(),error:(e,_)=>_Failure(error:e,retry:()=>ref.invalidate(financeProvider)),data:(f)=>GridView.count(crossAxisCount:MediaQuery.sizeOf(context).width>1000?3:2,crossAxisSpacing:16,mainAxisSpacing:16,childAspectRatio:2.1,children:[_Metric('Paid revenue',f.paid,Colors.green),_Metric('Pending payments',f.pending,Colors.orange),_Metric('Refunds',f.refunded,Colors.red),_Metric('Expenses',f.expenses,Colors.deepOrange),_Metric('GST on expenses',f.gst,Colors.indigo),_Metric('Operating profit',f.profit,f.profit>=0?Colors.green:Colors.red)]))); }
  Future<void> _expense(BuildContext context,WidgetRef ref) async { final category=TextEditingController(),description=TextEditingController(),amount=TextEditingController(),gst=TextEditingController(text:'0'); final ok=await _formDialog(context,'Record expense',(setState)=>[TextFormField(controller:category,decoration:const InputDecoration(labelText:'Category'),validator:(v)=>(v?.trim().length??0)<2?'Required':null),const SizedBox(height:12),TextFormField(controller:description,decoration:const InputDecoration(labelText:'Description'),validator:(v)=>(v?.trim().length??0)<2?'Required':null),const SizedBox(height:12),TextFormField(controller:amount,decoration:const InputDecoration(labelText:'Amount'),keyboardType:TextInputType.number,validator:_positive),const SizedBox(height:12),TextFormField(controller:gst,decoration:const InputDecoration(labelText:'GST amount'),keyboardType:TextInputType.number,validator:_nonNegative)]); if(ok!=true||!context.mounted)return; try{await ref.read(operationsRepositoryProvider).addExpense(category:category.text,description:description.text,amount:double.parse(amount.text),gst:double.parse(gst.text));ref.invalidate(financeProvider);}catch(e){if(context.mounted)_error(context,e);}}
}

class _Metric extends StatelessWidget { const _Metric(this.label,this.value,this.color); final String label; final double value; final Color color; @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(label),const SizedBox(height:8),Text('₹${NumberFormat.compactCurrency(locale:'en_IN',symbol:'').format(value)}',style:Theme.of(context).textTheme.headlineSmall?.copyWith(color:color,fontWeight:FontWeight.bold))]))); }
class _Page extends StatelessWidget { const _Page({required this.title,required this.child,this.action}); final String title; final Widget child; final Widget? action; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.headlineMedium)),if(action!=null)action!]),const SizedBox(height:16),Expanded(child:child)])); }
class _Loading extends StatelessWidget { const _Loading(); @override Widget build(BuildContext context)=>const Center(child:CircularProgressIndicator()); }
class _Empty extends StatelessWidget { const _Empty({required this.icon,required this.message}); final IconData icon; final String message; @override Widget build(BuildContext context)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:52),const SizedBox(height:12),Text(message)])); }
class _Failure extends StatelessWidget { const _Failure({required this.error,required this.retry}); final Object error; final VoidCallback retry; @override Widget build(BuildContext context)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off,size:48),const SizedBox(height:8),Text(error.toString(),textAlign:TextAlign.center),TextButton.icon(onPressed:retry,icon:const Icon(Icons.refresh),label:const Text('Retry'))])); }

String? _positive(String? value) { final parsed=double.tryParse(value??''); return parsed==null||parsed<=0?'Enter a value greater than zero':null; }
String? _nonNegative(String? value) { final parsed=double.tryParse(value??''); return parsed==null||parsed<0?'Enter zero or more':null; }
void _error(BuildContext context,Object error)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString()),backgroundColor:Colors.red.shade700));
void _success(BuildContext context,String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));

Future<String?> _textDialog(BuildContext context,String title,{String initial='',int maxLength=500,TextInputType? keyboardType}) async { final controller=TextEditingController(text:initial); final result=await showDialog<String>(context:context,builder:(dialogContext)=>AlertDialog(title:Text(title),content:TextField(controller:controller,maxLength:maxLength,maxLines:keyboardType==null?5:1,keyboardType:keyboardType,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,controller.text.trim()),child:const Text('Save'))])); controller.dispose(); return result; }
Future<bool?> _formDialog(BuildContext context,String title,List<Widget> Function(StateSetter) fields) { final key=GlobalKey<FormState>(); return showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(title:Text(title),content:SizedBox(width:480,child:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:fields(setState))))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:(){if(key.currentState!.validate())Navigator.pop(dialogContext,true);},child:const Text('Save'))]))); }
