import 'dart:typed_data';

import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>((ref) {
  return AdminCatalogRepository(ref.watch(supabaseProvider));
});

final adminCategoriesProvider = FutureProvider<List<Json>>((ref) {
  return ref.watch(adminCatalogRepositoryProvider).categories();
});
final adminPackagesProvider = FutureProvider<List<Json>>((ref) {
  return ref.watch(adminCatalogRepositoryProvider).packages();
});
final adminBannersProvider = FutureProvider<List<Json>>((ref) {
  return ref.watch(adminCatalogRepositoryProvider).banners();
});
final adminCouponsProvider = FutureProvider<List<Json>>((ref) {
  return ref.watch(adminCatalogRepositoryProvider).coupons();
});

class AdminCatalogRepository {
  const AdminCatalogRepository(this.client);
  final SupabaseClient client;

  Future<List<Json>> categories() async => List<Json>.from(await client.from('categories').select('id,name,slug,description,icon,image_url,sort_order,is_active').order('sort_order'));
  Future<List<Json>> packages() async => List<Json>.from(await client.from('packages').select('id,name,slug,description,category_id,price_per_guest,min_guests,max_guests,is_veg,is_active,image_url,package_type,cuisine,event_types,categories(name),package_images(id,image_url,storage_path,sort_order)').order('updated_at', ascending: false));
  Future<List<Json>> banners() async => List<Json>.from(await client.from('banners').select('id,title,subtitle,image_url,banner_type,starts_at,ends_at,is_active').order('created_at', ascending: false));
  Future<List<Json>> coupons() async => List<Json>.from(await client.from('coupons').select('id,code,description,discount_percent,discount_amount,min_order_amount,starts_at,ends_at,usage_limit,used_count,is_active').order('created_at', ascending: false));

  Future<void> saveCategory(Json values, [String? id]) async {
    if (id == null) {
      await client.from('categories').insert(values);
    } else {
      await client.from('categories').update(values).eq('id', id);
    }
  }

  Future<void> deleteCategory(String id) => client.from('categories').delete().eq('id', id);

  Future<void> savePackage(Json values, [String? id]) async {
    if (id == null) {
      final vendor = await client.from('vendors').select('id').eq('is_active', true).limit(1).single();
      await client.from('packages').insert({...values, 'vendor_id': vendor['id']});
    } else {
      await client.from('packages').update(values).eq('id', id);
    }
  }

  Future<void> deletePackage(String id) async {
    final images = await client.from('package_images').select('storage_path').eq('package_id', id);
    await client.from('packages').delete().eq('id', id);
    final paths = [for (final image in images) image['storage_path'] as String];
    if (paths.isNotEmpty) await client.storage.from('package-images').remove(paths);
  }

  Future<void> saveBanner(Json values, [String? id]) async {
    if (id == null) {
      await client.from('banners').insert(values);
    } else {
      await client.from('banners').update(values).eq('id', id);
    }
  }

  Future<void> deleteBanner(String id) async {
    final row = await client.from('banners').select('image_url').eq('id', id).single();
    await client.from('banners').delete().eq('id', id);
    final url = row['image_url'] as String?;
    final marker = '/banner-images/';
    if (url != null && url.contains(marker)) {
      await client.storage.from('banner-images').remove([url.split(marker).last]);
    }
  }

  Future<void> saveCoupon(Json values, [String? id]) async {
    if (id == null) {
      await client.from('coupons').insert(values);
    } else {
      await client.from('coupons').update(values).eq('id', id);
    }
  }

  Future<void> deleteCoupon(String id) => client.from('coupons').delete().eq('id', id);

  Future<String> uploadImage({required String bucket, required String ownerId, required String name, required Uint8List bytes}) async {
    if (bytes.length > 10 * 1024 * 1024) throw StateError('Images must be smaller than 10 MB');
    final extension = name.toLowerCase().split('.').last;
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) throw StateError('Only JPG, PNG, and WebP images are supported');
    final path = '$ownerId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> addPackageImage({required String packageId, required String name, required Uint8List bytes, required int sortOrder}) async {
    final url = await uploadImage(bucket: 'package-images', ownerId: packageId, name: name, bytes: bytes);
    final path = Uri.parse(url).pathSegments.skipWhile((value) => value != 'package-images').skip(1).join('/');
    await client.from('package_images').insert({'package_id': packageId, 'image_url': url, 'storage_path': path, 'sort_order': sortOrder});
    if (sortOrder == 0) await client.from('packages').update({'image_url': url}).eq('id', packageId);
  }
}
