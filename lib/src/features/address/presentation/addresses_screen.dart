import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.read(addressControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No saved addresses'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final address = items[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(address.label == 'Work' ? Icons.work_outline : Icons.home_outlined),
                      title: Row(children: [
                        Text(address.label),
                        if (address.isDefault) const Padding(padding: EdgeInsets.only(left: 8), child: Chip(label: Text('Default'))),
                      ]),
                      subtitle: Text('${address.line1}${address.line2 == null ? '' : ', ${address.line2}'}, ${address.area}, ${address.city} ${address.pincode}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') await _edit(context, ref, address);
                          if (value == 'delete') await ref.read(addressControllerProvider.notifier).remove(address.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Address? address]) async {
    final areas = await ref.read(serviceAreasProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddressForm(address: address, areas: areas),
    );
  }
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.address, required this.areas});
  final Address? address;
  final List<ServiceArea> areas;
  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  static const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  final formKey = GlobalKey<FormState>();
  late final line1 = TextEditingController(text: widget.address?.line1);
  late final line2 = TextEditingController(text: widget.address?.line2);
  late String label = widget.address?.label ?? 'Home';
  late String? areaId = widget.address?.areaId ?? (widget.areas.isEmpty ? null : widget.areas.first.id);
  late bool isDefault = widget.address?.isDefault ?? false;
  bool saving = false;
  LatLng? selectedLocation;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.address?.latitude != null && widget.address?.longitude != null) {
      selectedLocation = LatLng(widget.address!.latitude!, widget.address!.longitude!);
    }
  }

  @override
  void dispose() { line1.dispose(); line2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.address == null ? 'Add address' : 'Edit address', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Home', label: Text('Home')),
                  ButtonSegment(value: 'Work', label: Text('Work')),
                  ButtonSegment(value: 'Other', label: Text('Other')),
                ],
                selected: {label},
                onSelectionChanged: (value) => setState(() => label = value.first),
              ),
              const SizedBox(height: 16),
              TextFormField(controller: line1, decoration: const InputDecoration(labelText: 'Address line 1', border: OutlineInputBorder()), validator: (v) => (v?.trim().length ?? 0) < 5 ? 'Enter a complete address' : null),
              const SizedBox(height: 12),
              TextFormField(controller: line2, decoration: const InputDecoration(labelText: 'Address line 2 (optional)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: locating || googleMapsKey.isEmpty ? null : _pickLocation, icon: const Icon(Icons.map_outlined), label: Text(googleMapsKey.isEmpty ? 'Google Maps is not configured' : selectedLocation == null ? 'Choose location on map' : 'Location selected • Change')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: areaId,
                decoration: const InputDecoration(labelText: 'Service area', border: OutlineInputBorder()),
                items: [for (final area in widget.areas) DropdownMenuItem(value: area.id, child: Text('${area.name}, ${area.city} ${area.pincode}'))],
                onChanged: (value) => setState(() => areaId = value),
                validator: (value) => value == null ? 'Select a service area' : null,
              ),
              SwitchListTile(value: isDefault, title: const Text('Set as default'), onChanged: (v) => setState(() => isDefault = v)),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save address'),
                ),
              ),
            ]),
          ),
        ),
      );

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || areaId == null) return;
    final area = widget.areas.firstWhere((item) => item.id == areaId);
    setState(() => saving = true);
    try {
      await ref.read(addressControllerProvider.notifier).save(Address(
        id: widget.address?.id ?? '', label: label, line1: line1.text.trim(), line2: line2.text.trim().isEmpty ? null : line2.text.trim(),
        areaId: area.id, area: area.name, city: area.city, pincode: area.pincode, isDefault: isDefault,
        latitude: selectedLocation?.latitude, longitude: selectedLocation?.longitude,
      ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickLocation() async {
    setState(() => locating = true);
    try {
      var initial = selectedLocation;
      if (initial == null) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('Location permission is required');
        final position = await Geolocator.getCurrentPosition();
        initial = LatLng(position.latitude, position.longitude);
      }
      if (!mounted) return;
      final result = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => _LocationPicker(initial: initial!)));
      if (result == null) return;
      final marks = await placemarkFromCoordinates(result.latitude, result.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        line1.text = [p.name, p.street, p.subLocality]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(', ');
      }
      setState(() => selectedLocation = result);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { if (mounted) setState(() => locating = false); }
  }
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.initial});
  final LatLng initial;
  @override State<_LocationPicker> createState() => _LocationPickerState();
}
class _LocationPickerState extends State<_LocationPicker> {
  late LatLng point = widget.initial;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Pin event location')), body: Stack(children: [GoogleMap(initialCameraPosition: CameraPosition(target: point, zoom: 17), myLocationEnabled: true, myLocationButtonEnabled: true, markers: {Marker(markerId: const MarkerId('event'), position: point, draggable: true, onDragEnd: (value) => setState(() => point = value))}, onTap: (value) => setState(() => point = value)), Positioned(left: 16, right: 16, bottom: 24, child: FilledButton.icon(onPressed: () => Navigator.pop(context, point), icon: const Icon(Icons.check), label: const Text('Use this location')))]));
}
