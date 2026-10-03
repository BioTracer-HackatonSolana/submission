import 'models.dart';
import 'app_state.dart' show TraceRepository;

class DemoTraceRepository implements TraceRepository {
  DemoTraceRepository() : _scenario = _seedScenario();

  static final DateTime demoNow = DateTime(2026, 9, 5, 10);

  DemoScenario _scenario;
  bool slowMode = false;
  bool failNextOperation = false;

  @override
  DemoScenario get scenario => _scenario;

  @override
  Future<OperationResult> registerLot({
    required String code,
    required String name,
    required int quantity,
    required String unit,
    required String expiresAt,
  }) async {
    return _run(() {
      final lot = TraceLot(
        id: 'lot-${code.toLowerCase()}',
        code: code,
        productName: name,
        quantity: quantity,
        unit: unit,
        manufacturerId: 'org-manufacturer',
        manufacturedAt: demoNow,
        expiresAt: DateTime.tryParse(expiresAt) ?? DateTime(2027, 12, 31),
      );
      
      final transfer = CustodyTransfer(
        id: 'transfer-${code.toLowerCase()}',
        lotId: lot.id,
        fromOrganizationId: 'org-manufacturer',
        toOrganizationId: 'org-distributor',
        quantity: quantity,
        status: TransferStatus.draft,
        createdAt: demoNow,
        proofStatus: ProofStatus.notCreated,
      );

      _scenario = _scenario.copyWith(
        lot: lot,
        currentCustodianId: 'org-manufacturer',
        transfer: transfer,
        events: [
          CustodyEvent(
            id: 'event-registered-${code.toLowerCase()}',
            type: TraceEventType.lotRegistered,
            organizationId: 'org-manufacturer',
            createdAt: demoNow,
            actorLabel: 'Fabricante São Paulo',
            title: 'Lote registrado',
            description: 'O lote $code foi cadastrado e emitido.',
          ),
        ],
      );
      return const OperationResult.success('Produto registrado e lote emitido com sucesso!');
    });
  }

  @override
  Future<OperationResult> sendTransfer() async {
    return _run(() {
      if (_scenario.transfer.status != TransferStatus.draft) {
        return const OperationResult.failure(
          'Esta transferência já foi iniciada.',
        );
      }
      final transfer = _scenario.transfer.copyWith(
        status: TransferStatus.pendingAcceptance,
        proofStatus: ProofStatus.pending,
      );
      _scenario = _scenario.copyWith(
        transfer: transfer,
        events: [
          ..._scenario.events,
          CustodyEvent(
            id: 'event-sent',
            type: TraceEventType.transferSent,
            organizationId: transfer.fromOrganizationId,
            createdAt: demoNow.add(const Duration(minutes: 3)),
            actorLabel: 'Distribuidor Piloto',
            title: 'Transferência iniciada',
            description:
                'O lote foi enviado para conferência do Hospital Piloto.',
            proofStatus: ProofStatus.pending,
          ),
        ],
      );
      return const OperationResult.success(
        'Transferência enviada. O hospital precisa conferir o lote.',
      );
    });
  }

  @override
  Future<OperationResult> decideTransfer({
    required bool accepted,
    String? reason,
    ChainProof? proof,
  }) async {
    return _run(() {
      // Remover a validação local de TransferStatus para permitir testar com a API
      // onde o estado real está no backend.
      final normalizedReason = reason?.trim();
      if (!accepted && (normalizedReason == null || normalizedReason.isEmpty)) {
        return const OperationResult.failure(
          'Informe o motivo da recusa para registrar a decisão.',
        );
      }
      final nextStatus =
          accepted ? TransferStatus.accepted : TransferStatus.refused;
      final decisionProof = proof ??
          (accepted ? const ChainProof.simulated() : const ChainProof.local());
      final transfer = _scenario.transfer.copyWith(
        status: nextStatus,
        decidedAt: demoNow.add(const Duration(minutes: 6)),
        decisionReason: accepted ? null : normalizedReason,
        proof: decisionProof,
      );
      final decisionTitle =
          accepted ? 'Transferência aceita' : 'Transferência recusada';
      final decisionDescription =
          accepted
              ? 'Hospital Piloto confirmou a identidade e as ${transfer.quantity} unidades.'
              : 'Hospital Piloto devolveu a transferência para o distribuidor.';
      _scenario = _scenario.copyWith(
        currentCustodianId:
            accepted ? transfer.toOrganizationId : transfer.fromOrganizationId,
        transfer: transfer,
        events: [
          ..._scenario.events,
          CustodyEvent(
            id: accepted ? 'event-accepted' : 'event-refused',
            type:
                accepted
                    ? TraceEventType.transferAccepted
                    : TraceEventType.transferRefused,
            organizationId: transfer.toOrganizationId,
            createdAt: transfer.decidedAt!,
            actorLabel: 'Hospital Piloto',
            title: decisionTitle,
            description:
                accepted
                    ? decisionDescription
                    : '$decisionDescription Motivo: $normalizedReason',
            proofStatus: decisionProof.status,
          ),
          CustodyEvent(
            id: accepted ? 'event-proof-accepted' : 'event-proof-refused',
            type: TraceEventType.proofRegistered,
            organizationId: transfer.toOrganizationId,
            createdAt: demoNow.add(const Duration(minutes: 7)),
            actorLabel: 'BioTracer',
            title: 'Registro de integridade criado',
            description:
                decisionProof.status == ProofStatus.registeredOnchain
                    ? 'Transação confirmada na Solana Devnet.'
                    : accepted
                        ? 'Prova on-chain simulada para esta demonstração.'
                        : 'Decisão registrada localmente.',
            proofStatus: decisionProof.status,
          ),
        ],
      );
      final onChain = decisionProof.status == ProofStatus.registeredOnchain;
      return OperationResult.success(
        accepted
            ? onChain
                ? 'Recebimento aceito. A transferência foi confirmada na Solana Devnet.'
                : 'Recebimento aceito. A custódia agora está com o hospital.'
            : onChain
                ? 'Recebimento recusado na Solana. A custódia volta para o transporte.'
                : 'Recebimento recusado. A custódia continua com o distribuidor.',
      );
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableBatches() async {
    return [
      {
        'batchId': _scenario.lot.code,
        'status': 0,
      }
    ];
  }

  @override
  void setBatch(Map<String, dynamic> batchData) {
    final int backendStatus = batchData['status'] as int? ?? 0;
    TransferStatus newStatus;
    switch (backendStatus) {
      case 1:
        newStatus = TransferStatus.pendingAcceptance;
        break;
      case 2:
        newStatus = TransferStatus.accepted;
        break;
      case 3:
      case 4:
        newStatus = TransferStatus.refused;
        break;
      case 0:
      default:
        newStatus = TransferStatus.draft;
        break;
    }

    _scenario = _scenario.copyWith(
      lot: TraceLot(
        id: _scenario.lot.id,
        code: batchData['batchId'] as String,
        productName: (batchData['productName'] as String?)?.isNotEmpty == true ? batchData['productName'] : _scenario.lot.productName,
        quantity: (batchData['quantity'] as num?)?.toInt() ?? _scenario.lot.quantity,
        unit: (batchData['unit'] as String?)?.isNotEmpty == true ? batchData['unit'] : _scenario.lot.unit,
        manufacturerId: _scenario.lot.manufacturerId,
        manufacturedAt: _scenario.lot.manufacturedAt,
        expiresAt: (batchData['expiresAt'] as String?)?.isNotEmpty == true ? DateTime.tryParse(batchData['expiresAt']) ?? _scenario.lot.expiresAt : _scenario.lot.expiresAt,
      ),
      transfer: _scenario.transfer.copyWith(
        status: newStatus,
      )
    );
  }

  void attachChainProof(
    ChainProof proof, {
    required String title,
    required String description,
  }) {
    _scenario = _scenario.copyWith(
      transfer: _scenario.transfer.copyWith(proof: proof),
      events: [
        ..._scenario.events,
        CustodyEvent(
          id: 'event-chain-${proof.txSignature ?? _scenario.events.length}',
          type: TraceEventType.proofRegistered,
          organizationId: _scenario.currentCustodianId,
          createdAt: DateTime.now(),
          actorLabel: 'BioTracer',
          title: title,
          description: description,
          proofStatus: proof.status,
        ),
      ],
    );
  }

  @override
  void configure({bool? slowMode, bool? failNextOperation}) {
    if (slowMode != null) this.slowMode = slowMode;
    if (failNextOperation != null) this.failNextOperation = failNextOperation;
  }

  @override
  Future<void> resetScenario() async {
    _scenario = _seedScenario();
  }

  Future<OperationResult> _run(OperationResult Function() operation) async {
    if (slowMode) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (failNextOperation) {
      failNextOperation = false;
      return const OperationResult.failure(
        'Falha simulada. A operação não foi aplicada.',
      );
    }
    return operation();
  }

  static DemoScenario _seedScenario() {
    const demoBatchCode = String.fromEnvironment(
      'DEMO_BATCH_ID',
      defaultValue: 'BT-2048',
    );
    const organizations = [
      Organization(
        id: 'org-manufacturer',
        name: 'Fabricante São Paulo',
        kind: OrganizationKind.manufacturer,
        city: 'São Paulo, SP',
      ),
      Organization(
        id: 'org-distributor',
        name: 'Distribuidor Piloto',
        kind: OrganizationKind.distributor,
        city: 'Curitiba, PR',
      ),
      Organization(
        id: 'org-hospital',
        name: 'Hospital Piloto',
        kind: OrganizationKind.hospital,
        city: 'Porto Alegre, RS',
      ),
    ];
    final lot = TraceLot(
      id: 'lot-${demoBatchCode.toLowerCase()}',
      code: demoBatchCode,
      productName: 'Equipo de infusão',
      quantity: 120,
      unit: 'unidades',
      manufacturerId: 'org-manufacturer',
      manufacturedAt: DateTime(2026, 3, 12),
      expiresAt: DateTime(2027, 3),
    );
    final transfer = CustodyTransfer(
      id: 'transfer-bt-2048',
      lotId: lot.id,
      fromOrganizationId: 'org-distributor',
      toOrganizationId: 'org-hospital',
      quantity: lot.quantity,
      status: TransferStatus.draft,
      createdAt: demoNow,
      proofStatus: ProofStatus.notCreated,
    );
    return DemoScenario(
      organizations: organizations,
      lot: lot,
      currentCustodianId: 'org-distributor',
      transfer: transfer,
      events: [
        CustodyEvent(
          id: 'event-registered',
          type: TraceEventType.lotRegistered,
          organizationId: 'org-manufacturer',
          createdAt: DateTime(2026, 3, 12, 8, 20),
          actorLabel: 'Fabricante São Paulo',
          title: 'Lote registrado',
          description: 'O fabricante cadastrou o lote e sua origem.',
        ),
        CustodyEvent(
          id: 'event-received',
          type: TraceEventType.custodyReceived,
          organizationId: 'org-distributor',
          createdAt: DateTime(2026, 3, 15, 14, 10),
          actorLabel: 'Distribuidor Piloto',
          title: 'Custódia recebida',
          description: 'O distribuidor conferiu o lote ao receber a remessa.',
        ),
      ],
    );
  }
}
