import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SiteShell extends StatelessWidget {
  const SiteShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: InkWell(
          onTap: () => context.go('/'),
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.room_service_rounded, color: Color(0xFFF5B300)),
              SizedBox(width: 8),
              Text('BookMyPlatter', style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        actions: [
          if (wide) ...[
            _Nav(label: 'Home', path: '/'),
            _Nav(label: 'Veg', path: '/packages/veg'),
            _Nav(label: 'Non-Veg', path: '/packages/non-veg'),
            _Nav(label: 'Platter Box', path: '/packages/platter-box'),
            _Nav(label: 'Combos', path: '/packages/catering-combos'),
            _Nav(label: 'About', path: '/about'),
          ],
          IconButton(tooltip: 'Search', onPressed: () => context.go('/search'), icon: const Icon(Icons.search)),
          IconButton(tooltip: 'Cart', onPressed: () => context.go('/cart'), icon: const Icon(Icons.shopping_bag_outlined)),
          IconButton(tooltip: 'Account', onPressed: () => context.go('/profile'), icon: const Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 12),
        ],
      ),
      drawer: wide ? null : const _MobileMenu(),
      body: child,
      bottomNavigationBar: const _Footer(),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.label, required this.path});
  final String label;
  final String path;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => context.go(path), child: Text(label));
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu();
  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: ListView(children: [
            const ListTile(title: Text('BookMyPlatter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            for (final item in const [
              ('Home', '/'), ('AI Catering Planner', '/planner'), ('Veg Packages', '/packages/veg'),
              ('Non-Veg Packages', '/packages/non-veg'), ('Platter Box', '/packages/platter-box'),
              ('Catering Combos', '/packages/catering-combos'), ('My Orders', '/orders'),
              ('Saved Addresses', '/addresses'), ('Contact Us', '/contact'), ('FAQ', '/faq'),
            ])
              ListTile(title: Text(item.$1), onTap: () { Navigator.pop(context); context.go(item.$2); }),
          ]),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF281052),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 20, runSpacing: 8, children: [
              const Text('© BookMyPlatter • Premium catering', style: TextStyle(color: Colors.white)),
              Wrap(spacing: 8, children: [
                TextButton(onPressed: () => context.go('/privacy'), child: const Text('Privacy', style: TextStyle(color: Colors.white))),
                TextButton(onPressed: () => context.go('/terms'), child: const Text('Terms', style: TextStyle(color: Colors.white))),
                TextButton(onPressed: () => context.go('/contact'), child: const Text('Contact', style: TextStyle(color: Colors.white))),
              ]),
            ]),
          ),
        ),
      );
}
