import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/shared.dart';

class TraceFlowScreen extends ConsumerStatefulWidget {
  const TraceFlowScreen({super.key});

  @override
  ConsumerState<TraceFlowScreen> createState() => TraceFlowScreenState();
}

class TraceFlowScreenState extends ConsumerState<TraceFlowScreen> {
  bool _identityChecked = false;
  bool _quantityChecked = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(traceFlowProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1024;
            final horizontal = constraints.maxWidth < 600 ? 20.0 : 32.0;
            return Column(
              children: [
                TopBar(onReset: controller.isBusy ? null : _resetDemo),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      10,
                      horizontal,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IntroHeader(
                              step: controller.step,
                              batchCode: controller.scenario.lot.code,
                              compact: !isWide,
                            ),
                            const SizedBox(height: 26),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 244,
                                    child: ProgressRail(
                                      step: controller.step,
                                      scenario: controller.scenario,
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: _mainContent(
                                      controller,
                                      compact: false,
                                    ),
                                  ),
                                ],
                              )
                            else
                              _mainContent(controller, compact: true),
                            if (controller.feedback != null &&
                                (isWide ||
                                    controller.feedbackIsError ||
                                    controller.step == 1)) ...[
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mainContent(TraceFlowController controller, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.lotIdentified && controller.step < 3) ...[
          StepContext(
            step: controller.step,
            actorLabel: controller.actorLabel,
          ),
          const SizedBox(height: 14),
        ],
        if (!controller.lotIdentified)
          IdentifyStep(
            controller: controller,
            onIdentify: controller.isBusy ? null : controller.identifyMockLot,
            onOpenCamera: controller.isBusy ? null : _openCamera,
            compact: compact,
          )
        else if (controller.step == 1)
          SenderStep(
            controller: controller,
            onSend: controller.isBusy ? null : controller.sendTransfer,
            compact: compact,
          )
        else if (controller.step == 2)
          RecipientStep(
            controller: controller,
            identityChecked: _identityChecked,
            quantityChecked: _quantityChecked,
            onIdentityChanged: (value) {
              setState(() => _identityChecked = value ?? false);
            },
            onQuantityChanged: (value) {
              setState(() => _quantityChecked = value ?? false);
            },
            onAccept:
                controller.isBusy || !_identityChecked || !_quantityChecked
                    ? null
                    : () => controller.decide(accepted: true),
            onRefuse: controller.isBusy ? null : _refuseTransfer,
            compact: compact,
          )
        else
          OutcomeStep(
            controller: controller,
            onReset: controller.isBusy ? null : _resetDemo,
            compact: compact,
          ),
        if (controller.lotIdentified && (!compact || controller.step == 3)) ...[
          const SizedBox(height: 18),
          TimelineCard(scenario: controller.scenario, compact: compact),
        ],
      ],
    );
  }

  Future<void> _openCamera() async {
    final useDemo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              CameraSheet(onUseDemo: () => Navigator.of(context).pop(true)),
    );
    if (useDemo == true && mounted) {
      await ref.read(traceFlowProvider).identifyMockLot();
    }
  }

  Future<void> _refuseTransfer() async {
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
                    hintText: 'Ex.: quantidade divergente na conferência',
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
    await ref.read(traceFlowProvider).decide(accepted: false, reason: reason);
  }

  Future<void> _resetDemo() async {
    setState(() {
      _identityChecked = false;
      _quantityChecked = false;
    });
    await ref.read(traceFlowProvider).reset();
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            children: [
              const BrandMark(compact: true),
              const Spacer(),
              if (compact) ...[
                const DemoBadge(compact: true),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'Abrir menu',
                  icon: const Icon(Icons.menu_rounded),
                  onSelected: (_) => onReset?.call(),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem<String>(
                          value: 'reset',
                          enabled: onReset != null,
                          child: const Text('Reiniciar demonstração'),
                        ),
                      ],
                ),
              ] else ...[
                const DemoBadge(),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Reiniciar demonstração',
                  child: IconButton(
                    onPressed: onReset,
                    tooltip: 'Reiniciar demonstração',
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.navy,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class IntroHeader extends StatelessWidget {
  const IntroHeader({super.key, 
    required this.step,
    required this.batchCode,
    required this.compact,
  });

  final int step;
  final String batchCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayStep = step == 0 ? 1 : step + 1;
    if (compact) {
      final title = switch (step) {
        0 => 'Selecionar lote',
        1 => 'Enviar lote',
        2 => 'Receber lote',
        _ => 'Histórico do lote',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ETAPA $displayStep DE 4',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.cobalt,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROTEIRO DE DEMONSTRAÇÃO · ETAPA $displayStep DE 4',
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.cobalt,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Cada etapa, um registro.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            'Acompanhe a transferência do lote $batchCode entre distribuidor e hospital. Tudo aqui é dado mockado para demonstrar a experiência ponta a ponta.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class ProgressRail extends StatelessWidget {
  const ProgressRail({super.key, required this.step, required this.scenario});

  final int step;
  final DemoScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O roteiro',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 18),
                RailItem(
                  number: '1',
                  title: 'Identificar',
                  subtitle: 'Câmera ou simulação',
                  active: step == 0,
                  complete: step > 0,
                ),
                RailConnector(complete: step > 0),
                RailItem(
                  number: '2',
                  title: 'Enviar',
                  subtitle: 'Distribuidor inicia',
                  active: step == 1,
                  complete: step > 1,
                ),
                RailConnector(complete: step > 1),
                RailItem(
                  number: '3',
                  title: 'Confirmar',
                  subtitle: 'Hospital confere',
                  active: step == 2,
                  complete: step > 2,
                ),
                RailConnector(complete: step > 2),
                RailItem(
                  number: '4',
                  title: 'Histórico',
                  subtitle: 'Registro atualizado',
                  active: step == 3,
                  complete: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: AppColors.navy,
          child: Padding(
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
                const SizedBox(height: 9),
                Text(
                  step == 0 ? '—' : scenario.lot.code,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step == 0
                      ? 'Aguardando identificação'
                      : scenario.lot.productName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Text(
                  step == 0
                      ? 'Câmera pronta'
                      : '${scenario.lot.quantity} ${scenario.lot.unit}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step == 0
                      ? 'Leitura simulada disponível'
                      : 'Validade ${monthYearFormat.format(scenario.lot.expiresAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RailItem extends StatelessWidget {
  const RailItem({super.key, 
    required this.number,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.complete,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = active || complete ? AppColors.cobalt : AppColors.inkMuted;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                complete
                    ? AppColors.cobalt
                    : (active ? AppColors.paleBlue : AppColors.offWhite),
            shape: BoxShape.circle,
            border: Border.all(
              color: active || complete ? AppColors.cobalt : AppColors.rule,
            ),
          ),
          child:
              complete
                  ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  )
                  : Text(
                    number,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RailConnector extends StatelessWidget {
  const RailConnector({super.key, required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      margin: const EdgeInsets.only(left: 13),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: complete ? AppColors.cobalt : AppColors.rule,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class StepContext extends StatelessWidget {
  const StepContext({super.key, required this.step, required this.actorLabel});

  final int step;
  final String actorLabel;

  @override
  Widget build(BuildContext context) {
    final copy =
        step == 1
            ? 'Você está no papel de distribuidor.'
            : 'Você está no papel de hospital.';
    return Row(
      children: [
        StatusBadge(
          label: actorLabel,
          color: step == 1 ? AppColors.cobalt : AppColors.green,
          icon:
              step == 1
                  ? Icons.local_shipping_outlined
                  : Icons.local_hospital_outlined,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            copy,
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class IdentifyStep extends StatelessWidget {
  const IdentifyStep({super.key, 
    required this.controller,
    required this.onIdentify,
    required this.onOpenCamera,
    required this.compact,
  });

  final TraceFlowController controller;
  final VoidCallback? onIdentify;
  final VoidCallback? onOpenCamera;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final camera = OutlinedButton.icon(
      onPressed: onOpenCamera,
      icon: const Icon(Icons.videocam_outlined),
      label: const Text('Abrir câmera'),
    );
    final apiButton = FilledButton.icon(
      onPressed: controller.isBusy
          ? null
          : () async {
              final batches = await controller.fetchAvailableBatches();
              if (batches.isEmpty && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nenhum lote na API ainda.')),
                );
                return;
              }
              if (context.mounted) {
                final selectedBatch = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Lotes da API'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: batches.length,
                          itemBuilder: (context, index) {
                            final batch = batches[index];
                            return ListTile(
                              title: Text(batch['batchId'] ?? ''),
                              subtitle: Text(
                                'Produto: ${batch['productName'] ?? '—'} · ${batch['statusLabel'] ?? batch['status']}',
                              ),
                              onTap: () => Navigator.of(context).pop(batch),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
                if (selectedBatch != null) {
                  await controller.identifyMockLot(selectedBatch);
                }
              }
            },
      icon: controller.isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.cloud_download_rounded),
      label: Text(controller.isBusy ? 'Carregando…' : 'Buscar Lotes da API'),
    );
    final demo = TextButton.icon(
      onPressed: onIdentify,
      icon: const Icon(Icons.qr_code_2_rounded),
      label: const Text('Usar lote demo'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            color: AppColors.navy,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.lime,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Aponte para o QR Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Space Grotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Leitura demonstrativa',
                      style: TextStyle(
                        color: AppColors.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          apiButton,
          const SizedBox(height: 10),
          demo,
          const SizedBox(height: 10),
          camera,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Identifique o lote',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        Text(
          'Comece apontando a câmera para o código do lote. Nesta demonstração, a leitura é representada pelo lote demo para manter o foco na conferência e na custódia.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 180),
                padding: const EdgeInsets.all(24),
                color: AppColors.navy,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.lime,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Câmera pronta para o próximo passo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Space Grotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nenhuma imagem será capturada ou interpretada agora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 460;
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          apiButton,
                          const SizedBox(height: 12),
                          demo,
                          const SizedBox(height: 12),
                          camera,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: camera),
                        const SizedBox(width: 12),
                        Expanded(child: demo),
                        const SizedBox(width: 12),
                        Expanded(child: apiButton),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DemoNotice(
          text:
              'Leitura simulada nesta demo · lote ${controller.scenario.lot.code}.',
        ),
      ],
    );
  }
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paleBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.cobalt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraSheet extends StatefulWidget {
  const CameraSheet({super.key, required this.onUseDemo});

  final VoidCallback onUseDemo;

  @override
  State<CameraSheet> createState() => CameraSheetState();
}

class CameraSheetState extends State<CameraSheet>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraDescription? _description;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera([CameraDescription? description]) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'Nenhuma câmera disponível neste dispositivo.',
        );
      }
      final selected =
          description ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
      final nextController = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await nextController.initialize();
      if (!mounted) {
        await nextController.dispose();
        return;
      }
      await _cameraController?.dispose();
      setState(() {
        _description = selected;
        _cameraController = nextController;
        _loading = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cameraErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível acessar a câmera neste ambiente.';
      });
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Permissão da câmera não concedida.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Permissão da câmera bloqueada.';
      case 'NoCamera':
        return error.description ?? 'Nenhuma câmera encontrada.';
      default:
        return 'Não foi possível abrir a câmera.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed && _description != null) {
      _initializeCamera(_description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: const BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Câmera do lote',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Prévia da câmera · leitura simulada nesta demo',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar câmera',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                CameraUnavailable(message: _error!)
              else if (controller != null && controller.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
                )
              else
                const CameraUnavailable(
                  message: 'A câmera ainda não foi inicializada.',
                ),
              const SizedBox(height: 14),
              const StatusBadge(
                label: 'Leitura simulada nesta demo',
                color: AppColors.cobalt,
                icon: Icons.qr_code_2_rounded,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onUseDemo,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Usar lote demo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraUnavailable extends StatelessWidget {
  const CameraUnavailable({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: AppColors.lime,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'Câmera indisponível',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Space Grotesk',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class SenderStep extends StatelessWidget {
  const SenderStep({super.key, 
    required this.controller,
    required this.onSend,
    required this.compact,
  });

  final TraceFlowController controller;
  final VoidCallback? onSend;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scenario = controller.scenario;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileLotSummary(
            scenario: scenario,
            statusLabel: 'Pronto para enviar',
            statusColor: AppColors.cobalt,
          ),
          const SizedBox(height: 12),
          CompactRouteLine(scenario: scenario),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSend,
              icon:
                  controller.isBusy
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.arrow_forward_rounded),
              label: Text(controller.isBusy ? 'Enviando…' : 'Enviar lote'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Envie a custódia para o hospital',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        Text(
          'O distribuidor inicia a transferência. O lote só muda de responsável depois da confirmação do destinatário.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        LotCard(scenario: scenario),
        const SizedBox(height: 14),
        RouteCard(scenario: scenario),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSend,
            icon:
                controller.isBusy
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              controller.isBusy ? 'Enviando…' : 'Enviar transferência',
            ),
          ),
        ),
      ],
    );
  }
}

class RecipientStep extends StatelessWidget {
  const RecipientStep({super.key, 
    required this.controller,
    required this.identityChecked,
    required this.quantityChecked,
    required this.onIdentityChanged,
    required this.onQuantityChanged,
    required this.onAccept,
    required this.onRefuse,
    required this.compact,
  });

  final TraceFlowController controller;
  final bool identityChecked;
  final bool quantityChecked;
  final ValueChanged<bool?> onIdentityChanged;
  final ValueChanged<bool?> onQuantityChanged;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scenario = controller.scenario;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileLotSummary(
            scenario: scenario,
            statusLabel: 'Aguardando aceite',
            statusColor: AppColors.amber,
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                VerificationRow(
                  title: 'Quantidade conferida',
                  value: '${scenario.lot.quantity} ${scenario.lot.unit}',
                  icon: Icons.inventory_2_outlined,
                  checked: quantityChecked,
                  onTap: () => onQuantityChanged(!quantityChecked),
                ),
                const Divider(height: 1),
                VerificationRow(
                  title: 'Identificação conferida',
                  value: '${scenario.lot.code} · ${scenario.lot.productName}',
                  icon: Icons.badge_outlined,
                  checked: identityChecked,
                  onTap: () => onIdentityChanged(!identityChecked),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAccept,
              icon:
                  controller.isBusy
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                controller.isBusy ? 'Registrando…' : 'Aceitar recebimento',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRefuse,
              child: const Text('Recusar'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confira antes de aceitar',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        Text(
          'O Hospital Piloto recebeu o pedido. Confirme os dois pontos abaixo para concluir a custódia.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        RouteCard(scenario: scenario, pending: true),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                CheckboxListTile(
                  value: identityChecked,
                  onChanged: onIdentityChanged,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Identidade do lote confere'),
                  subtitle: Text(
                    '${scenario.lot.code} · ${scenario.lot.productName}',
                  ),
                ),
                CheckboxListTile(
                  value: quantityChecked,
                  onChanged: onQuantityChanged,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Quantidade recebida confere'),
                  subtitle: Text(
                    '${scenario.lot.quantity} ${scenario.lot.unit}',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 460;
            final accept = FilledButton.icon(
              onPressed: onAccept,
              icon:
                  controller.isBusy
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check_rounded),
              label: Text(
                controller.isBusy ? 'Registrando…' : 'Aceitar transferência',
              ),
            );
            final refuse = OutlinedButton.icon(
              onPressed: onRefuse,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Recusar'),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [accept, const SizedBox(height: 10), refuse],
              );
            }
            return Row(
              children: [
                Expanded(child: accept),
                const SizedBox(width: 10),
                Expanded(child: refuse),
              ],
            );
          },
        ),
      ],
    );
  }
}

class OutcomeStep extends StatelessWidget {
  const OutcomeStep({super.key, 
    required this.controller,
    required this.onReset,
    required this.compact,
  });

  final TraceFlowController controller;
  final VoidCallback? onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scenario = controller.scenario;
    final accepted = scenario.transfer.status == TransferStatus.accepted;
    final color = accepted ? AppColors.green : AppColors.red;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileLotSummary(
            scenario: scenario,
            statusLabel:
                accepted ? 'Recebimento aceito' : 'Transferência recusada',
            statusColor: color,
          ),
          const SizedBox(height: 12),
          Card(
            color: accepted ? AppColors.successWash : AppColors.errorWash,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                              : 'A custódia continua com o distribuidor.',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
          const SizedBox(height: 12),
          ProofDetails(proof: scenario.transfer.proof),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: accepted ? AppColors.successWash : AppColors.errorWash,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  accepted
                      ? Icons.verified_rounded
                      : Icons.assignment_return_rounded,
                  color: color,
                  size: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  accepted ? 'Custódia confirmada' : 'Transferência recusada',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 7),
                Text(
                  accepted
                      ? 'O Hospital Piloto aceitou o lote. O histórico agora mostra a nova responsabilidade.'
                      : 'O Hospital Piloto recusou o lote. A custódia continua com o Distribuidor Piloto.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (scenario.transfer.decisionReason != null) ...[
                  const SizedBox(height: 12),
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
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado final',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 480 ? 1 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      childAspectRatio: columns == 1 ? 2.4 : 2.4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        InfoTile(
                          label: 'Custódia atual',
                          value: scenario.currentCustodian.name,
                          icon: Icons.person_pin_circle_outlined,
                        ),
                        InfoTile(
                          label: 'Prova de integridade',
                          value: proofStatusLabel(
                            scenario.transfer.proofStatus,
                          ),
                          icon: Icons.fingerprint_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reiniciar roteiro'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ProofDetails(proof: scenario.transfer.proof),
      ],
    );
  }
}

class ProofDetails extends StatelessWidget {
  const ProofDetails({super.key, required this.proof});

  final ChainProof? proof;

  @override
  Widget build(BuildContext context) {
    if (proof == null) return const SizedBox.shrink();
    final isOnchain = proof!.status == ProofStatus.registeredOnchain;
    final color = isOnchain ? AppColors.green : AppColors.inkMuted;
    return Card(
      color: isOnchain ? AppColors.successWash : AppColors.offWhite,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOnchain
                      ? Icons.verified_user_outlined
                      : Icons.info_outline_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnchain
                        ? 'Prova confirmada na Solana'
                        : proof!.status == ProofStatus.registeredLocal
                        ? 'Decisão registrada no roteiro'
                        : 'Prova disponível no modo demonstração',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(
                  label: proofStatusLabel(proof!.status),
                  color: color,
                ),
              ],
            ),
            if (proof!.txSignature != null) ...[
              const SizedBox(height: 10),
              Text(
                'Assinatura: ${_shortSignature(proof!.txSignature!)}',
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (proof!.batchPda != null) ...[
              const SizedBox(height: 4),
              Text(
                'PDA do lote: ${_shortSignature(proof!.batchPda!)}',
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (proof!.confirmedAt != null) ...[
              const SizedBox(height: 5),
              Text(
                'Confirmada em: ${dateTimeFormat.format(proof!.confirmedAt!.toLocal())}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
            if (proof!.network != null && !isOnchain) ...[
              const SizedBox(height: 5),
              Text(
                'Ambiente: ${proof!.network}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
            if (proof!.explorerUrl != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(proof!.explorerUrl!);
                  if (uri != null) await launchUrl(uri);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Abrir no Solana Explorer'),
              ),
            ],
            if (!isOnchain) ...[
              const SizedBox(height: 6),
              const Text(
                'A demonstração deixa explícito quando a prova não foi gravada na rede.',
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortSignature(String value) {
    if (value.length <= 20) return value;
    return '${value.substring(0, 10)}…${value.substring(value.length - 8)}';
  }
}

class MobileLotSummary extends StatelessWidget {
  const MobileLotSummary({super.key, 
    required this.scenario,
    required this.statusLabel,
    required this.statusColor,
  });

  final DemoScenario scenario;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final lot = scenario.lot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOTE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lot.code,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lot.quantity} ${lot.unit} · ${lot.productName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatusBadge(
              label: statusLabel,
              color: statusColor,
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class CompactRouteLine extends StatelessWidget {
  const CompactRouteLine({super.key, required this.scenario});

  final DemoScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: AppColors.cobalt),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${scenario.sender.name}  →  ${scenario.recipient.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationRow extends StatelessWidget {
  const VerificationRow({super.key, 
    required this.title,
    required this.value,
    required this.icon,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: checked,
      label: '$title${checked ? ', conferido' : ''}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      checked
                          ? AppColors.cobalt.withValues(alpha: 0.12)
                          : AppColors.paleBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  checked ? Icons.check_rounded : icon,
                  size: 19,
                  color: AppColors.cobalt,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                checked
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: checked ? AppColors.green : AppColors.inkMuted,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LotCard extends StatelessWidget {
  const LotCard({super.key, required this.scenario});

  final DemoScenario scenario;

  @override
  Widget build(BuildContext context) {
    final lot = scenario.lot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final lotHeading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOTE SELECIONADO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lot.code,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lot.productName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
                final badge = StatusBadge(
                  label: transferStatusLabel(scenario.transfer.status),
                  color: transferStatusColor(scenario.transfer.status),
                  icon: Icons.route_rounded,
                );
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [lotHeading, const SizedBox(height: 12), badge],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: lotHeading), badge],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 480 ? 1 : 3;
                return GridView.count(
                  crossAxisCount: columns,
                  childAspectRatio: columns == 1 ? 2.4 : 1.7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    InfoTile(
                      label: 'Quantidade',
                      value: '${lot.quantity} ${lot.unit}',
                      icon: Icons.inventory_2_outlined,
                    ),
                    InfoTile(
                      label: 'Fabricante',
                      value: scenario.manufacturer.name,
                      icon: Icons.factory_outlined,
                    ),
                    InfoTile(
                      label: 'Validade',
                      value: monthYearFormat.format(lot.expiresAt),
                      icon: Icons.event_outlined,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.scenario, this.pending = false});

  final DemoScenario scenario;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 460;
            final sender = OrganizationBlock(
              organization: scenario.sender,
              label: 'ORIGEM',
              icon: Icons.local_shipping_outlined,
            );
            final recipient = OrganizationBlock(
              organization: scenario.recipient,
              label: 'DESTINO',
              icon: Icons.local_hospital_outlined,
            );
            final arrow = Icon(
              stacked ? Icons.south_rounded : Icons.east_rounded,
              color: pending ? AppColors.amber : AppColors.cobalt,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 19,
                      color: AppColors.cobalt,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pending
                            ? 'Pedido de transferência'
                            : 'Rota da custódia',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (stacked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sender,
                      const SizedBox(height: 8),
                      arrow,
                      const SizedBox(height: 8),
                      recipient,
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: sender),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: arrow,
                      ),
                      Expanded(child: recipient),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OrganizationBlock extends StatelessWidget {
  const OrganizationBlock({super.key, 
    required this.organization,
    required this.label,
    required this.icon,
  });

  final Organization organization;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.paleBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.cobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  organization.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  organization.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.scenario, required this.compact});

  final DemoScenario scenario;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico do lote',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    if (!compact)
                      const Text(
                        'Cada evento fica associado à custódia do momento.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                );
                final proof = StatusBadge(
                  label: proofStatusLabel(scenario.transfer.proofStatus),
                  color:
                      scenario.transfer.proofStatus ==
                                  ProofStatus.registeredOnchain ||
                              scenario.transfer.proofStatus ==
                                  ProofStatus.registeredSimulated
                          ? AppColors.green
                          : scenario.transfer.proofStatus ==
                              ProofStatus.registeredLocal
                          ? AppColors.amber
                          : AppColors.inkMuted,
                  icon: Icons.fingerprint_rounded,
                );
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 12), proof],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: heading), proof],
                );
              },
            ),
            const SizedBox(height: 18),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scenario.events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final event = scenario.events[index];
                final isLast = index == scenario.events.length - 1;
                return TimelineEvent(
                  event: event,
                  isLast: isLast,
                  compact: compact,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineEvent extends StatelessWidget {
  const TimelineEvent({super.key, 
    required this.event,
    required this.isLast,
    required this.compact,
  });

  final CustodyEvent event;
  final bool isLast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final eventColor =
        event.proofStatus == ProofStatus.registeredOnchain ||
                event.proofStatus == ProofStatus.registeredSimulated
            ? AppColors.green
            : event.proofStatus == ProofStatus.registeredLocal
            ? AppColors.amber
            : AppColors.cobalt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _eventIcon(event.type),
                  size: 15,
                  color: eventColor,
                ),
              ),
              if (!isLast)
                Container(
                  height: 32,
                  width: 1,
                  color: AppColors.rule,
                  margin: const EdgeInsets.only(top: 4),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final date = Text(
                      dateTimeFormat.format(event.createdAt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    );
                    final title = Text(
                      event.title,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    );
                    if (constraints.maxWidth < 230) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 2), date],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        Flexible(child: date),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.actorLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: eventColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _eventIcon(TraceEventType type) {
    switch (type) {
      case TraceEventType.lotRegistered:
        return Icons.qr_code_2_rounded;
      case TraceEventType.custodyReceived:
        return Icons.inventory_2_outlined;
      case TraceEventType.transferSent:
        return Icons.outbox_rounded;
      case TraceEventType.transferAccepted:
        return Icons.check_rounded;
      case TraceEventType.transferRefused:
        return Icons.close_rounded;
      case TraceEventType.proofRegistered:
        return Icons.fingerprint_rounded;
    }
  }
}

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.red : AppColors.green;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
