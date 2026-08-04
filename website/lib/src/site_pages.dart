import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final websiteContentProvider = FutureProvider.family<String, ContentKind>((ref, kind) async {
  final key = switch (kind) {
    ContentKind.about => 'about_us',
    ContentKind.privacy => 'privacy_policy',
    ContentKind.terms => 'terms_and_conditions',
  };
  final row = await ref.watch(supabaseClientProvider).from('app_config').select('value').eq('key', key).maybeSingle();
  if (row == null) return '';
  final value = row['value'];
  if (value is String) return value;
  if (value is Map<String, dynamic>) return (value['content'] ?? value['text'] ?? '').toString();
  return value?.toString() ?? '';
});

enum ContentKind { about, privacy, terms }

class WebsiteHomePage extends ConsumerWidget {
  const WebsiteHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannersProvider);
    final packages = ref.watch(packagesProvider(const PackageQuery()));
    return Title(
      title: 'BookMyPlatter | Catering for Every Celebration',
      color: const Color(0xFF3C1285),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(packagesProvider);
          await ref.read(packagesProvider(const PackageQuery()).future);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(banners: banners, onRetry: () => ref.invalidate(bannersProvider))),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Plan your event in minutes',
              subtitle: 'Tell our smart planner about your celebration and receive recommendations from the live BookMyPlatter menu.',
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(onPressed: () => context.go('/planner'), icon: const Icon(Icons.auto_awesome), label: const Text('Start AI Catering Planner')),
                OutlinedButton.icon(onPressed: () => context.go('/search'), icon: const Icon(Icons.tune), label: const Text('Search & filter packages')),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: _PackageSection(title: 'Popular packages', packages: packages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery())))),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.banners, required this.onRetry});
  final AsyncValue<List<HeroBanner>> banners;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).width < 700 ? 430 : 520,
        child: banners.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorPanel(message: 'Promotions could not be loaded', onRetry: onRetry),
          data: (items) {
            final banner = items.isEmpty ? null : items.first;
            return Stack(fit: StackFit.expand, children: [
              if (banner?.imageUrl != null)
                CachedNetworkImage(imageUrl: banner!.imageUrl!, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 250)),
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF250653).withOpacity(.96), const Color(0xFF3C1285).withOpacity(.58), Colors.transparent]))),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 620,
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Chip(label: Text('Premium catering • Live availability')),
                          const SizedBox(height: 18),
                          Text(banner?.title ?? 'Celebrate beautifully with BookMyPlatter', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          Text(banner?.subtitle ?? 'Curated menus, transparent pricing, secure checkout, and live booking updates.', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                          const SizedBox(height: 28),
                          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF5B300), foregroundColor: Colors.black87), onPressed: () => context.go('/planner'), icon: const Icon(Icons.auto_awesome), label: const Text('Plan my event')),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class PackageListingPage extends ConsumerWidget {
  const PackageListingPage({required this.type, required this.title, super.key});
  final String type;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = PackageQuery(packageType: type);
    final packages = ref.watch(packagesProvider(query));
    return Title(
      title: '$title | BookMyPlatter',
      color: const Color(0xFF3C1285),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: _Section(
          title: title,
          subtitle: 'Live availability and pricing managed by BookMyPlatter.',
          child: packages.when(
            loading: () => const _PackageSkeleton(),
            error: (error, _) => _ErrorPanel(message: 'Packages could not be loaded', onRetry: () => ref.invalidate(packagesProvider(query))),
            data: (items) => items.isEmpty
                ? const _EmptyPanel(message: 'No packages are currently available in this collection.')
                : _PackageGrid(items: items),
          ),
        ),
      ),
    );
  }
}

class ContentPage extends ConsumerWidget {
  const ContentPage({required this.kind, super.key});
  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = switch (kind) { ContentKind.about => 'About BookMyPlatter', ContentKind.privacy => 'Privacy Policy', ContentKind.terms => 'Terms & Conditions' };
    final content = ref.watch(websiteContentProvider(kind));
    return Title(
      title: '$heading | BookMyPlatter',
      color: const Color(0xFF3C1285),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: _Section(
          title: heading,
          subtitle: kind == ContentKind.about ? 'Single-brand catering, thoughtfully designed for memorable events.' : 'The latest policy published by BookMyPlatter.',
          child: content.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorPanel(message: 'This content could not be loaded', onRetry: () => ref.invalidate(websiteContentProvider(kind))),
            data: (text) => text.trim().isEmpty
                ? const _EmptyPanel(message: 'This content has not been published yet. Please contact BookMyPlatter for assistance.')
                : SelectableText(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
          ),
        ),
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({required this.title, required this.packages, required this.onRetry});
  final String title;
  final AsyncValue<List<CateringPackage>> packages;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _Section(
        title: title,
        subtitle: 'Customer favourites ranked from the live catalog.',
        child: packages.when(
          loading: () => const _PackageSkeleton(),
          error: (error, _) => _ErrorPanel(message: 'Packages could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty ? const _EmptyPanel(message: 'No packages are available right now.') : _PackageGrid(items: items.take(8).toList()),
        ),
      );
}

class _PackageGrid extends StatelessWidget {
  const _PackageGrid({required this.items});
  final List<CateringPackage> items;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1150 ? 4 : width >= 720 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: columns == 1 ? 1.35 : .78),
      itemCount: items.length,
      itemBuilder: (context, index) => _PackageCard(package: items[index]),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});
  final CateringPackage package;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/package/${package.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: package.imageUrl == null
                    ? const ColoredBox(color: Color(0xFFF1ECF8), child: Icon(Icons.restaurant, size: 56))
                    : CachedNetworkImage(imageUrl: package.imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, children: [Chip(label: Text(package.isVeg ? 'VEG' : 'NON-VEG'), visualDensity: VisualDensity.compact), if (package.rating > 0) Chip(avatar: const Icon(Icons.star, size: 16), label: Text(package.rating.toStringAsFixed(1)), visualDensity: VisualDensity.compact)]),
                const SizedBox(height: 6),
                Text(package.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('₹${package.pricePerGuest.toStringAsFixed(0)} per guest • ${package.minGuests}-${package.maxGuests} guests'),
              ]),
            ),
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 22),
              child,
            ]),
          ),
        ),
      );
}

class _PackageSkeleton extends StatelessWidget {
  const _PackageSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 40), const SizedBox(height: 8), Text(message), if (onRetry != null) TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))]));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Row(children: [const Icon(Icons.info_outline), const SizedBox(width: 12), Expanded(child: Text(message))])));
}
