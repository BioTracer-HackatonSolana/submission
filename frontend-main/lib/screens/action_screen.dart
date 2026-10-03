import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/legacy_flow_widgets.dart';

class ActionScreen extends ConsumerStatefulWidget {
  const ActionScreen({super.key});

  @override
  ConsumerState<ActionScreen> createState() => _ActionScreenState();
}

class _ActionScreenState extends ConsumerState<ActionScreen> {
  bool _identityChecked = false;
  bool _quantityChecked = false;

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _expiresAtController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _expiresAtController.dispose();
    super.dispose();
  }

  bool _isDecided(CustodyTransfer transfer) {
    return transfer.status == TransferStatus.accepted ||
        transfer.status == TransferStatus.refused;
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = ref.watch(activeRoleProvider);
    final controller = ref.watch(traceFlowProvider);
    final isWide = MediaQuery.of(context).size.width >= 1024;

    if (activeRole == OrganizationKind.manufacturer) {
      return _buildManufacturerForm(context, controller);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!controller.lotIdentified)
                IdentifyStep(
                  controller: controller,
                  onIdentify:
                      controller.isBusy ? null : controller.identifyMockLot,
                  onOpenCamera:
                      controller.isBusy ? null : () => _openCamera(controller),
                  compact: !isWide,
                )
              else if (_isDecided(controller.scenario.transfer))
                _ActionOutcome(controller: controller)
              else if (activeRole == OrganizationKind.distributor)
                SenderStep(
                  controller: controller,
                  onSend: controller.isBusy ? null : controller.sendTransfer,
                  compact: !isWide,
                )
              else if (activeRole == OrganizationKind.hospital)
                RecipientStep(
                  controller: controller,
                  identityChecked: _identityChecked,
                  quantityChecked: _quantityChecked,
                  onIdentityChanged:
                      (val) => setState(() => _identityChecked = val ?? false),
                  onQuantityChanged:
                      (val) => setState(() => _quantityChecked = val ?? false),
                  onAccept:
                      controller.isBusy ||
                              !_identityChecked ||
                              !_quantityChecked
                          ? null
                          : () => controller.decide(accepted: true),
                  onRefuse:
                      controller.isBusy
                          ? null
                          : () => _refuseTransfer(controller),
                  compact: !isWide,
                ),
              if (controller.feedback != null) ...[
                const SizedBox(height: 18),
                FeedbackBanner(
                  message: controller.feedback!,
                  isError: controller.feedbackIsError,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManufacturerForm(
    BuildContext context,
    TraceFlowController controller,
  ) {
    final showResult =
        controller.feedback != null && !controller.feedbackIsError;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'Registrar novo produto',
                subtitle: 'Preencha as informações para emitir o lote on-chain.',
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Produto',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unidade (ex: caixas)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _expiresAtController,
                        decoration: const InputDecoration(
                          labelText: 'Validade (AAAA-MM-DD)',
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed:
                            controller.isBusy
                                ? null
                                : () async {
                                  if (_nameController.text.trim().isEmpty) {
                                    return;
                                  }
                                  await controller.registerProduct(
                                    name: _nameController.text,
                                    quantity: _quantityController.text,
                                    unit: _unitController.text,
                                    expiresAt: _expiresAtController.text,
                                  );
                                  if (!context.mounted) return;
                                  if (controller.feedbackIsError) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          controller.feedback ?? 'Erro.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Produto registrado com sucesso!',
                                        ),
                                      ),
                                    );
                                    _nameController.clear();
                                    _quantityController.clear();
                                    _unitController.clear();
                                    _expiresAtController.clear();
                                  }
                                },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child:
                            controller.isBusy
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onAccent,
                                  ),
                                )
                                : const Text('Registrar e Emitir Lote'),
                      ),
                    ],
                  ),
                ),
              ),
              if (showResult) ...[
                const SizedBox(height: 18),
                LotFocusCard(scenario: controller.scenario),
                const SizedBox(height: 12),
                ProofDetails(proof: controller.scenario.transfer.proof),
                const SizedBox(height: 12),
                FeedbackBanner(
                  message: controller.feedback!,
                  isError: false,
                ),
              ] else if (controller.feedback != null &&
                  controller.feedbackIsError) ...[
                const SizedBox(height: 18),
                FeedbackBanner(
                  message: controller.feedback!,
                  isError: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCamera(TraceFlowController controller) async {
    final useDemo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CameraSheet(onUseDemo: () => Navigator.of(context).pop(true)),
    );
    if (useDemo == true && mounted) {
      await controller.identifyMockLot();
    }
  }

  Future<void> _refuseTransfer(TraceFlowController controller) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String? validationError;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Recusar transferência'),
                content: TextField(
                  controller: reasonController,
                  autofocus: true,
                  maxLines: 3,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Motivo da recusa',
                    hintText: 'Ex.: quantidade divergente',
                    errorText: validationError,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (reasonController.text.trim().isEmpty) {
                        setDialogState(
                          () =>
                              validationError =
                                  'Informe o motivo para continuar.',
                        );
                        return;
                      }
                      Navigator.of(context).pop(reasonController.text);
                    },
                    child: const Text('Registrar recusa'),
                  ),
                ],
              ),
        );
      },
    );
    reasonController.dispose();
    if (!mounted || reason == null) return;
    await controller.decide(accepted: false, reason: reason);
  }
}

class _ActionOutcome extends StatelessWidget {
  const _ActionOutcome({required this.controller});

  final TraceFlowController controller;

  @override
  Widget build(BuildContext context) {
    final scenario = controller.scenario;
    final accepted = scenario.transfer.status == TransferStatus.accepted;
    final color = accepted ? AppColors.green : AppColors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPageHeader(
          title: 'Decisão registrada',
          subtitle: 'A prova desta etapa fica visível aqui e no histórico.',
        ),
        const SizedBox(height: 22),
        Card(
          color: accepted ? AppColors.successWash : AppColors.errorWash,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  accepted
                      ? Icons.verified_rounded
                      : Icons.assignment_return_rounded,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accepted
                            ? 'Custódia confirmada'
                            : 'Transferência recusada',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        accepted
                            ? 'O hospital agora é o responsável pelo lote.'
                            : 'A custódia continua com o remetente.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (scenario.transfer.decisionReason != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Motivo: ${scenario.transfer.decisionReason}',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LotFocusCard(scenario: scenario),
        const SizedBox(height: 14),
        ProofDetails(proof: scenario.transfer.proof),
      ],
    );
  }
}
