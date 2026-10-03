import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'shared.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.activeRole,
    required this.onRoleChanged,
    this.onReset,
  });

  final OrganizationKind activeRole;
  final ValueChanged<OrganizationKind> onRoleChanged;
  final VoidCallback? onReset;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.offWhite,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxWidth < 480;
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: BrandMark(compact: true),
                      ),
                    ),
                  ),
                  if (!tight) ...[
                    const DemoBadge(compact: true),
                    const SizedBox(width: 6),
                  ],
                  RoleSwitcher(
                    value: activeRole,
                    onChanged: onRoleChanged,
                    compact: tight,
                  ),
                  IconButton(
                    onPressed: onReset,
                    tooltip: 'Reiniciar demonstração',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.navy,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final OrganizationKind value;
  final ValueChanged<OrganizationKind> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<OrganizationKind>(
      tooltip: 'Trocar papel da demo',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.rule),
      ),
      itemBuilder:
          (context) =>
              OrganizationKind.values.map((kind) {
                return PopupMenuItem<OrganizationKind>(
                  value: kind,
                  child: Text(organizationKindLabel(kind)),
                );
              }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_roleIcon(value), size: 16, color: AppColors.cobalt),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                organizationKindLabel(value),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
            const Icon(Icons.expand_more_rounded, color: AppColors.cobalt),
          ],
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.role,
    required this.onChanged,
  });

  final int index;
  final OrganizationKind role;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final actionLabel =
        role == OrganizationKind.manufacturer ? 'Registrar' : 'Receber';
    final actionIcon =
        role == OrganizationKind.manufacturer
            ? Icons.add_box_outlined
            : (role == OrganizationKind.hospital
                ? Icons.verified_outlined
                : Icons.local_shipping_outlined);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onChanged,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(actionIcon),
            selectedIcon: Icon(
              role == OrganizationKind.manufacturer
                  ? Icons.add_box
                  : (role == OrganizationKind.hospital
                      ? Icons.verified
                      : Icons.local_shipping),
            ),
            label: actionLabel,
          ),
          const NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Histórico',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_rounded),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showSlogan = true,
  });

  final String title;
  final String subtitle;
  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSlogan) ...[
          const Text(
            'Cada etapa, um registro.',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.cobalt,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class LotFocusCard extends StatelessWidget {
  const LotFocusCard({super.key, required this.scenario});

  final DemoScenario scenario;

  @override
  Widget build(BuildContext context) {
    final lot = scenario.lot;
    return Card(
      color: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            const Positioned(
              right: -12,
              top: -8,
              width: 140,
              height: 140,
              child: BrandWatermark(),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lote em foco',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lot.code,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: AppColors.onAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lot.productName,
                    style: const TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${lot.quantity} ${lot.unit}',
                    style: const TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Validade ${monthYearFormat.format(lot.expiresAt)}',
                    style: TextStyle(
                      color: AppColors.onAccent.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FactCard extends StatelessWidget {
  const FactCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.cobalt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _roleIcon(OrganizationKind kind) {
  switch (kind) {
    case OrganizationKind.manufacturer:
      return Icons.precision_manufacturing_outlined;
    case OrganizationKind.distributor:
      return Icons.local_shipping_outlined;
    case OrganizationKind.hospital:
      return Icons.local_hospital_outlined;
  }
}
