import 'package:bookmyplatter_admin/src/features/catalog/admin_catalog_repository.dart';
import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminCatalogScreen extends ConsumerWidget {
  const AdminCatalogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(adminIdentityProvider).valueOrNull;
    if (identity == null || !identity.canManage) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_outline, size: 52), SizedBox(height: 12), Text('Administrator permission is required')]));
    }
    return DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: MediaQuery.sizeOf(context).width < 720,
                tabs: const [Tab(text: 'Packages'), Tab(text: 'Categories'), Tab(text: 'Banners'), Tab(text: 'Coupons')],
              ),
            ),
            Expanded(child: TabBarView(children: [_packages(context, ref), _categories(context, ref), _banners(context, ref), _coupons(context, ref)])),
          ],
        ),
      );
  }

  Widget _packages(BuildContext context, WidgetRef ref) => _AsyncList(
        value: ref.watch(adminPackagesProvider),
        title: 'Package management',
        addLabel: 'Add package',
        onAdd: () => _packageForm(context, ref),
        onRetry: () => ref.invalidate(adminPackagesProvider),
        itemBuilder: (item) => ListTile(
          leading: CircleAvatar(child: Icon(item['is_veg'] as bool ? Icons.eco_outlined : Icons.restaurant)),
          title: Text(item['name'] as String),
          subtitle: Text('${item['package_type'].toString().replaceAll('_', ' ')} • ₹${item['price_per_guest']} / guest • ${item['min_guests']}-${item['max_guests']} guests'),
          trailing: Wrap(spacing: 4, children: [
            IconButton(tooltip: 'Upload gallery images', onPressed: () => _uploadPackageImages(context, ref, item), icon: const Icon(Icons.add_photo_alternate_outlined)),
            IconButton(tooltip: 'Edit package', onPressed: () => _packageForm(context, ref, item), icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'Delete package', onPressed: () => _delete(context, () => ref.read(adminCatalogRepositoryProvider).deletePackage(item['id'] as String), () => ref.invalidate(adminPackagesProvider)), icon: const Icon(Icons.delete_outline)),
          ]),
        ),
      );

  Widget _categories(BuildContext context, WidgetRef ref) => _AsyncList(
        value: ref.watch(adminCategoriesProvider),
        title: 'Category management',
        addLabel: 'Add category',
        onAdd: () => _categoryForm(context, ref),
        onRetry: () => ref.invalidate(adminCategoriesProvider),
        itemBuilder: (item) => ListTile(
          leading: CircleAvatar(child: Text(item['icon'] as String)),
          title: Text(item['name'] as String),
          subtitle: Text('Display order ${item['sort_order']} • ${item['is_active'] as bool ? 'Active' : 'Hidden'}'),
          trailing: Wrap(children: [
            IconButton(onPressed: () => _categoryForm(context, ref, item), icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: () => _delete(context, () => ref.read(adminCatalogRepositoryProvider).deleteCategory(item['id'] as String), () => ref.invalidate(adminCategoriesProvider)), icon: const Icon(Icons.delete_outline)),
          ]),
        ),
      );

  Widget _banners(BuildContext context, WidgetRef ref) => _AsyncList(
        value: ref.watch(adminBannersProvider),
        title: 'Banner management',
        addLabel: 'Add banner',
        onAdd: () => _bannerForm(context, ref),
        onRetry: () => ref.invalidate(adminBannersProvider),
        itemBuilder: (item) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
          title: Text(item['title'] as String),
          subtitle: Text('${item['banner_type']} • ${item['is_active'] as bool ? 'Active' : 'Inactive'}'),
          trailing: Wrap(children: [
            IconButton(onPressed: () => _bannerForm(context, ref, item), icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: () => _delete(context, () => ref.read(adminCatalogRepositoryProvider).deleteBanner(item['id'] as String), () => ref.invalidate(adminBannersProvider)), icon: const Icon(Icons.delete_outline)),
          ]),
        ),
      );

  Widget _coupons(BuildContext context, WidgetRef ref) => _AsyncList(
        value: ref.watch(adminCouponsProvider),
        title: 'Coupon management',
        addLabel: 'Add coupon',
        onAdd: () => _couponForm(context, ref),
        onRetry: () => ref.invalidate(adminCouponsProvider),
        itemBuilder: (item) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
          title: Text(item['code'] as String),
          subtitle: Text('${item['discount_percent'] == null ? '₹${item['discount_amount']}' : '${item['discount_percent']}%'} off • Used ${item['used_count']}${item['usage_limit'] == null ? '' : '/${item['usage_limit']}'}'),
          trailing: Wrap(children: [
            IconButton(onPressed: () => _couponForm(context, ref, item), icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: () => _delete(context, () => ref.read(adminCatalogRepositoryProvider).deleteCoupon(item['id'] as String), () => ref.invalidate(adminCouponsProvider)), icon: const Icon(Icons.delete_outline)),
          ]),
        ),
      );

  Future<void> _categoryForm(BuildContext context, WidgetRef ref, [Json? item]) async {
    final name = TextEditingController(text: item?['name'] as String?);
    final description = TextEditingController(text: item?['description'] as String?);
    final icon = TextEditingController(text: item?['icon'] as String? ?? '🍽️');
    final image = TextEditingController(text: item?['image_url'] as String?);
    final order = TextEditingController(text: '${item?['sort_order'] ?? 0}');
    var active = item?['is_active'] as bool? ?? true;
    final saved = await _formDialog(context, title: item == null ? 'Add category' : 'Edit category', builder: (setState) => [
      _field(name, 'Name', mandatory: true), _field(description, 'Description', mandatory: true, lines: 3), _field(icon, 'Icon', mandatory: true), _field(image, 'Image URL'), _field(order, 'Display order', number: true),
      SwitchListTile(value: active, title: const Text('Visible to customers'), onChanged: (value) => setState(() => active = value)),
    ]);
    if (!saved || !context.mounted) return;
    await _run(context, () => ref.read(adminCatalogRepositoryProvider).saveCategory({'name': name.text.trim(), 'slug': _slug(name.text), 'description': description.text.trim(), 'icon': icon.text.trim(), 'image_url': image.text.trim().isEmpty ? null : image.text.trim(), 'sort_order': int.parse(order.text), 'is_active': active}, item?['id'] as String?), () => ref.invalidate(adminCategoriesProvider));
  }

  Future<void> _packageForm(BuildContext context, WidgetRef ref, [Json? item]) async {
    final categories = await ref.read(adminCategoriesProvider.future);
    if (!context.mounted) return;
    final name = TextEditingController(text: item?['name'] as String?);
    final description = TextEditingController(text: item?['description'] as String?);
    final price = TextEditingController(text: '${item?['price_per_guest'] ?? ''}');
    final minimum = TextEditingController(text: '${item?['min_guests'] ?? 10}');
    final maximum = TextEditingController(text: '${item?['max_guests'] ?? 500}');
    final cuisine = TextEditingController(text: item?['cuisine'] as String? ?? 'Multi-cuisine');
    var categoryId = item?['category_id'] as String? ?? (categories.isEmpty ? null : categories.first['id'] as String);
    var type = item?['package_type'] as String? ?? 'veg';
    var active = item?['is_active'] as bool? ?? true;
    final saved = await _formDialog(context, title: item == null ? 'Add package' : 'Edit package', builder: (setState) => [
      _field(name, 'Package name', mandatory: true), _field(description, 'Description', mandatory: true, lines: 3),
      DropdownButtonFormField<String>(value: categoryId, decoration: const InputDecoration(labelText: 'Category'), items: [for (final category in categories) DropdownMenuItem(value: category['id'] as String, child: Text(category['name'] as String))], onChanged: (value) => setState(() => categoryId = value), validator: (value) => value == null ? 'Select a category' : null),
      DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Package type'), items: const [DropdownMenuItem(value: 'veg', child: Text('Veg')), DropdownMenuItem(value: 'non_veg', child: Text('Non-Veg')), DropdownMenuItem(value: 'platter_box', child: Text('Platter Box')), DropdownMenuItem(value: 'catering_combo', child: Text('Catering Combo'))], onChanged: (value) => setState(() => type = value ?? 'veg')),
      _field(cuisine, 'Cuisine', mandatory: true), _field(price, 'Price per guest', number: true), Row(children: [Expanded(child: _field(minimum, 'Minimum guests', number: true)), const SizedBox(width: 12), Expanded(child: _field(maximum, 'Maximum guests', number: true))]),
      SwitchListTile(value: active, title: const Text('Available for booking'), onChanged: (value) => setState(() => active = value)),
    ]);
    if (!saved || !context.mounted || categoryId == null) return;
    if (double.parse(price.text) <= 0 || int.parse(minimum.text) <= 0 || int.parse(maximum.text) < int.parse(minimum.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid pricing and guest limits')));
      return;
    }
    await _run(context, () => ref.read(adminCatalogRepositoryProvider).savePackage({'name': name.text.trim(), 'slug': item?['slug'] as String? ?? '${_slug(name.text)}-${DateTime.now().millisecondsSinceEpoch}', 'description': description.text.trim(), 'category_id': categoryId, 'package_type': type, 'is_veg': type != 'non_veg', 'cuisine': cuisine.text.trim(), 'price_per_guest': double.parse(price.text), 'min_guests': int.parse(minimum.text), 'max_guests': int.parse(maximum.text), 'is_active': active}, item?['id'] as String?), () => ref.invalidate(adminPackagesProvider));
  }

  Future<void> _bannerForm(BuildContext context, WidgetRef ref, [Json? item]) async {
    final title = TextEditingController(text: item?['title'] as String?);
    final subtitle = TextEditingController(text: item?['subtitle'] as String?);
    final image = TextEditingController(text: item?['image_url'] as String?);
    var type = item?['banner_type'] as String? ?? 'home';
    var active = item?['is_active'] as bool? ?? true;
    final saved = await _formDialog(context, title: item == null ? 'Add banner' : 'Edit banner', builder: (setState) => [
      _field(title, 'Title', mandatory: true), _field(subtitle, 'Subtitle', mandatory: true, lines: 2), _field(image, 'Image URL'),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () async { try { final file = await FilePicker.platform.pickFiles(type: FileType.image, withData: true); if (file?.files.single.bytes == null) return; final selected = file!.files.single; final url = await ref.read(adminCatalogRepositoryProvider).uploadImage(bucket: 'banner-images', ownerId: item?['id'] as String? ?? 'new', name: selected.name, bytes: selected.bytes!); image.text = url; setState(() {}); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } }, icon: const Icon(Icons.upload_outlined), label: const Text('Upload image'))),
      DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Placement'), items: const [DropdownMenuItem(value: 'home', child: Text('Home')), DropdownMenuItem(value: 'festival', child: Text('Festival')), DropdownMenuItem(value: 'promotion', child: Text('Promotion')), DropdownMenuItem(value: 'popup', child: Text('Popup'))], onChanged: (value) => setState(() => type = value ?? 'home')),
      SwitchListTile(value: active, title: const Text('Active'), onChanged: (value) => setState(() => active = value)),
    ]);
    if (!saved || !context.mounted) return;
    await _run(context, () => ref.read(adminCatalogRepositoryProvider).saveBanner({'title': title.text.trim(), 'subtitle': subtitle.text.trim(), 'image_url': image.text.trim().isEmpty ? null : image.text.trim(), 'banner_type': type, 'is_active': active}, item?['id'] as String?), () => ref.invalidate(adminBannersProvider));
  }

  Future<void> _couponForm(BuildContext context, WidgetRef ref, [Json? item]) async {
    final code = TextEditingController(text: item?['code'] as String?);
    final description = TextEditingController(text: item?['description'] as String?);
    final discount = TextEditingController(text: '${item?['discount_percent'] ?? item?['discount_amount'] ?? ''}');
    final minimum = TextEditingController(text: '${item?['min_order_amount'] ?? 0}');
    final limit = TextEditingController(text: '${item?['usage_limit'] ?? ''}');
    var percentage = item == null || item['discount_percent'] != null;
    var active = item?['is_active'] as bool? ?? true;
    var starts = item == null ? DateTime.now() : DateTime.parse(item['starts_at'] as String).toLocal();
    var ends = item == null ? DateTime.now().add(const Duration(days: 30)) : DateTime.parse(item['ends_at'] as String).toLocal();
    final saved = await _formDialog(context, title: item == null ? 'Add coupon' : 'Edit coupon', builder: (setState) => [
      _field(code, 'Coupon code', mandatory: true), _field(description, 'Description', mandatory: true),
      SwitchListTile(value: percentage, title: Text(percentage ? 'Percentage discount' : 'Flat discount'), onChanged: (value) => setState(() => percentage = value)),
      _field(discount, percentage ? 'Discount percent' : 'Discount amount', number: true), _field(minimum, 'Minimum order', number: true), _field(limit, 'Usage limit (optional)', number: true, optional: true),
      ListTile(title: const Text('Starts'), subtitle: Text(DateFormat('d MMM yyyy').format(starts)), onTap: () async { final value = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: starts); if (value != null) setState(() => starts = value); }),
      ListTile(title: const Text('Expires'), subtitle: Text(DateFormat('d MMM yyyy').format(ends)), onTap: () async { final value = await showDatePicker(context: context, firstDate: starts.add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: ends.isAfter(starts) ? ends : starts.add(const Duration(days: 1))); if (value != null) setState(() => ends = value); }),
      SwitchListTile(value: active, title: const Text('Active'), onChanged: (value) => setState(() => active = value)),
    ]);
    if (!saved || !context.mounted) return;
    final discountValue = double.parse(discount.text);
    if (discountValue <= 0 || (percentage && discountValue > 100) || !ends.isAfter(starts)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid discount and expiry date')));
      return;
    }
    await _run(context, () => ref.read(adminCatalogRepositoryProvider).saveCoupon({'code': code.text.trim().toUpperCase(), 'description': description.text.trim(), 'discount_percent': percentage ? double.parse(discount.text) : null, 'discount_amount': percentage ? null : double.parse(discount.text), 'min_order_amount': double.parse(minimum.text), 'usage_limit': limit.text.trim().isEmpty ? null : int.parse(limit.text), 'starts_at': starts.toUtc().toIso8601String(), 'ends_at': ends.add(const Duration(hours: 23, minutes: 59)).toUtc().toIso8601String(), 'is_active': active}, item?['id'] as String?), () => ref.invalidate(adminCouponsProvider));
  }

  Future<void> _uploadPackageImages(BuildContext context, WidgetRef ref, Json item) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result == null || !context.mounted) return;
    try {
      final existing = (item['package_images'] as List?)?.length ?? 0;
      for (var index = 0; index < result.files.length; index++) {
        final file = result.files[index];
        if (file.bytes == null) throw StateError('Unable to read ${file.name}');
        await ref.read(adminCatalogRepositoryProvider).addPackageImage(packageId: item['id'] as String, name: file.name, bytes: file.bytes!, sortOrder: existing + index);
      }
      ref.invalidate(adminPackagesProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.files.length} images uploaded')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _field(TextEditingController controller, String label, {bool mandatory = false, bool number = false, bool optional = false, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: controller, maxLines: lines, keyboardType: number ? TextInputType.number : null, decoration: InputDecoration(labelText: label), validator: (value) { if (optional && (value?.trim().isEmpty ?? true)) return null; if (mandatory && (value?.trim().isEmpty ?? true)) return '$label is required'; if (number && num.tryParse(value ?? '') == null) return 'Enter a valid number'; return null; }),
      );

  Future<bool> _formDialog(BuildContext context, {required String title, required List<Widget> Function(StateSetter) builder}) async {
    final key = GlobalKey<FormState>();
    return await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: Text(title), content: SizedBox(width: 560, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: builder(setState))))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(context, true); }, child: const Text('Save'))]))) ?? false;
  }

  Future<void> _run(BuildContext context, Future<void> Function() operation, VoidCallback refresh) async {
    try { await operation(); refresh(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved'))); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }

  Future<void> _delete(BuildContext context, Future<void> Function() operation, VoidCallback refresh) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete permanently?'), content: const Text('This action cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (confirmed == true && context.mounted) await _run(context, operation, refresh);
  }

  String _slug(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
}

class _AsyncList extends StatelessWidget {
  const _AsyncList({required this.value, required this.title, required this.addLabel, required this.onAdd, required this.onRetry, required this.itemBuilder});
  final AsyncValue<List<Json>> value;
  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final VoidCallback onRetry;
  final Widget Function(Json) itemBuilder;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel))]), const SizedBox(height: 16), Expanded(child: value.when(loading: () => const Center(child: CircularProgressIndicator()), error: (error, _) => Center(child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))), data: (items) => items.isEmpty ? const Center(child: Text('No records found')) : ListView.separated(itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 6), itemBuilder: (_, index) => Card(child: itemBuilder(items[index])))))]));
}
