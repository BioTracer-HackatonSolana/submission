import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/legacy_flow_widgets.dart';
import '../widgets/shared.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeRoleProvider);
    final scenario = ref.watch(traceFlowProvider).scenario;
    final transfer = scenario.transfer;
    final custodian = scenario.currentCustodian;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Visão geral',
                subtitle:
                    '${organizationKindLabel(activeRole)} · ${organizationKindHint(activeRole)}',
              ),
              const SizedBox(height: 22),
              LotFocusCard(scenario: scenario),
              const SizedBox(height: 14),
              FactCard(
                label: 'Custódia atual',
                value: custodian.name,
                detail:
                    '${custodian.kindLabel} · ${custodian.city}',
                icon: Icons.person_pin_circle_outlined,
              ),
              const SizedBox(height: 14),
              FactCard(
                label: 'Transferência',
                value: transferStatusLabel(transfer.status),
                detail:
                    '${scenario.sender.name} → ${scenario.recipient.name}',
                icon: Icons.sync_alt_rounded,
                tone: transferStatusColor(transfer.status),
              ),
              const SizedBox(height: 14),
              FactCard(
                label: 'Prova de integridade',
                value: proofStatusLabel(transfer.proofStatus),
                detail:
                    transfer.proof == null
                        ? 'A prova aparece aqui depois da decisão on-chain'
                        : transfer.proof?.txSignature != null
                        ? 'Assinatura disponível no comprovante abaixo'
                        : 'Comprovante on-chain disponível abaixo',
                icon: Icons.fingerprint_rounded,
                tone:
                    transfer.proofStatus == ProofStatus.registeredOnchain ||
                            transfer.proofStatus ==
                                ProofStatus.registeredSimulated
                        ? AppColors.green
                        : AppColors.inkMuted,
              ),
              if (transfer.proof != null) ...[
                const SizedBox(height: 14),
                ProofDetails(proof: transfer.proof),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
