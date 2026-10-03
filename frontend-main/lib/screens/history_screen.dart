import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_state.dart';
import '../widgets/app_chrome.dart';
import '../widgets/legacy_flow_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(traceFlowProvider);
    final proof = controller.scenario.transfer.proof;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'Histórico do produto',
                subtitle:
                    'Acompanhe a cadeia de custódia e os registros on-chain.',
              ),
              const SizedBox(height: 22),
              if (proof != null) ...[
                ProofDetails(proof: proof),
                const SizedBox(height: 14),
              ],
              TimelineCard(
                scenario: controller.scenario,
                compact: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
