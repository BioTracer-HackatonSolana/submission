import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/shared.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeRoleProvider);
    final controller = ref.watch(traceFlowProvider);

    String orgId = '';
    if (activeRole == OrganizationKind.manufacturer) {
      orgId = 'org-manufacturer';
    } else if (activeRole == OrganizationKind.hospital) {
      orgId = 'org-hospital';
    } else {
      orgId = 'org-distributor';
    }

    final organization = controller.scenario.organization(orgId);
    final events =
        controller.scenario.events
            .where((e) => e.organizationId == orgId)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'Minha conta',
                subtitle:
                    'Registros recentes da organização neste roteiro de demonstração.',
              ),
              const SizedBox(height: 22),
              Card(
                color: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organizationKindLabel(activeRole).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        organization.name,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: AppColors.onAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        organization.city,
                        style: TextStyle(
                          color: AppColors.onAccent.withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Nenhuma atividade recente registrada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                )
              else
                ...events.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.paleBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: AppColors.cobalt,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.description,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    dateTimeFormat.format(event.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
