import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/gate/presentation/screens/gate_incoming_screen.dart';
import '../../features/gate/presentation/screens/gate_ledger_screen.dart';
import '../../features/parcel/presentation/screens/home_screen.dart';
import '../../features/parcel/presentation/screens/parcel_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGate =
        ref.watch(staffProfileProvider).asData?.value?.isGate ?? false;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TKT Parcel', style: AppTextStyles.title),
                  SizedBox(height: AppSpacing.xs),
                  Text('Counter operations', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              title: 'Home',
              icon: Icons.home_outlined,
              selected: currentRoute == HomeScreen.routeName,
              onTap: () => _navigate(context, HomeScreen.routeName),
            ),
            _DrawerItem(
              title: 'Parcel List',
              icon: Icons.receipt_long_outlined,
              selected: currentRoute == ParcelListScreen.routeName,
              onTap: () => _navigate(context, ParcelListScreen.routeName),
            ),
            if (isGate)
              _DrawerItem(
                title: 'Main Ledger',
                icon: Icons.local_shipping_outlined,
                selected: currentRoute == GateLedgerScreen.routeName,
                onTap: () => _navigate(context, GateLedgerScreen.routeName),
              ),
            if (isGate)
              _DrawerItem(
                title: 'Incoming Parcels',
                icon: Icons.move_to_inbox_outlined,
                selected: currentRoute == GateIncomingScreen.routeName,
                onTap: () => _navigate(context, GateIncomingScreen.routeName),
              ),
            _DrawerItem(
              title: 'Settings',
              icon: Icons.settings_outlined,
              selected: currentRoute == SettingsScreen.routeName,
              onTap: () => _navigate(context, SettingsScreen.routeName),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    if (currentRoute == routeName) {
      return;
    }
    if (routeName == HomeScreen.routeName) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(routeName, (route) => route.isFirst);
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: onTap,
    );
  }
}
