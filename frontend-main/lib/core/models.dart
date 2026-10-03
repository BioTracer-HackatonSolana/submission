enum OrganizationKind { manufacturer, distributor, hospital }

enum TransferStatus { draft, pendingAcceptance, accepted, refused }

enum ProofStatus {
  notCreated,
  pending,
  registeredOnchain,
  registeredSimulated,
  registeredLocal,
  failed,
}

enum TraceEventType {
  lotRegistered,
  custodyReceived,
  transferSent,
  transferAccepted,
  transferRefused,
  proofRegistered,
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.kind,
    required this.city,
  });

  final String id;
  final String name;
  final OrganizationKind kind;
  final String city;

  String get kindLabel {
    switch (kind) {
      case OrganizationKind.manufacturer:
        return 'Fabricante';
      case OrganizationKind.distributor:
        return 'Distribuidor';
      case OrganizationKind.hospital:
        return 'Hospital';
    }
  }
}

class TraceLot {
  const TraceLot({
    required this.id,
    required this.code,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.manufacturerId,
    required this.manufacturedAt,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final String productName;
  final int quantity;
  final String unit;
  final String manufacturerId;
  final DateTime manufacturedAt;
  final DateTime expiresAt;
}

class CustodyTransfer {
  const CustodyTransfer({
    required this.id,
    required this.lotId,
    required this.fromOrganizationId,
    required this.toOrganizationId,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.proofStatus,
    this.proof,
    this.decidedAt,
    this.decisionReason,
  });

  final String id;
  final String lotId;
  final String fromOrganizationId;
  final String toOrganizationId;
  final int quantity;
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decisionReason;
  final ProofStatus proofStatus;
  final ChainProof? proof;

  CustodyTransfer copyWith({
    TransferStatus? status,
    DateTime? decidedAt,
    String? decisionReason,
    ProofStatus? proofStatus,
    ChainProof? proof,
  }) {
    return CustodyTransfer(
      id: id,
      lotId: lotId,
      fromOrganizationId: fromOrganizationId,
      toOrganizationId: toOrganizationId,
      quantity: quantity,
      status: status ?? this.status,
      createdAt: createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decisionReason: decisionReason ?? this.decisionReason,
      proofStatus: proof?.status ?? proofStatus ?? this.proofStatus,
      proof: proof ?? this.proof,
    );
  }
}

class ChainProof {
  const ChainProof({
    required this.status,
    this.txSignature,
    this.batchPda,
    this.network,
    this.confirmation,
    this.confirmedAt,
    this.explorerUrl,
    this.errorMessage,
  });

  final ProofStatus status;
  final String? txSignature;
  final String? batchPda;
  final String? network;
  final String? confirmation;
  final DateTime? confirmedAt;
  final String? explorerUrl;
  final String? errorMessage;

  const ChainProof.simulated()
    : this(status: ProofStatus.registeredSimulated, network: 'simulação local');

  const ChainProof.local()
    : this(status: ProofStatus.registeredLocal, network: 'registro local');

  factory ChainProof.fromJson(Map<String, dynamic> json) {
    final confirmedAtValue = json['confirmedAt'];
    return ChainProof(
      status: ProofStatus.registeredOnchain,
      txSignature: (json['txSignature'] ?? json['txHash']) as String?,
      batchPda: json['batchPda'] as String?,
      network: json['network'] as String? ?? 'devnet',
      confirmation: json['confirmation'] as String?,
      confirmedAt:
          confirmedAtValue is String
              ? DateTime.tryParse(confirmedAtValue)
              : null,
      explorerUrl: json['explorerUrl'] as String?,
    );
  }
}

class CustodyEvent {
  const CustodyEvent({
    required this.id,
    required this.type,
    required this.organizationId,
    required this.createdAt,
    required this.actorLabel,
    required this.title,
    required this.description,
    this.proofStatus = ProofStatus.notCreated,
  });

  final String id;
  final TraceEventType type;
  final String organizationId;
  final DateTime createdAt;
  final String actorLabel;
  final String title;
  final String description;
  final ProofStatus proofStatus;
}

class DemoScenario {
  const DemoScenario({
    required this.organizations,
    required this.lot,
    required this.currentCustodianId,
    required this.transfer,
    required this.events,
  });

  final List<Organization> organizations;
  final TraceLot lot;
  final String currentCustodianId;
  final CustodyTransfer transfer;
  final List<CustodyEvent> events;

  DemoScenario copyWith({
    TraceLot? lot,
    String? currentCustodianId,
    CustodyTransfer? transfer,
    List<CustodyEvent>? events,
  }) {
    return DemoScenario(
      organizations: organizations,
      lot: lot ?? this.lot,
      currentCustodianId: currentCustodianId ?? this.currentCustodianId,
      transfer: transfer ?? this.transfer,
      events: events ?? this.events,
    );
  }

  Organization organization(String id) =>
      organizations.firstWhere((organization) => organization.id == id);

  Organization get manufacturer => organization(lot.manufacturerId);

  Organization get currentCustodian => organization(currentCustodianId);

  Organization get sender => organization(transfer.fromOrganizationId);

  Organization get recipient => organization(transfer.toOrganizationId);
}

class OperationResult {
  const OperationResult({required this.ok, required this.message});

  const OperationResult.success(String message)
    : this(ok: true, message: message);

  const OperationResult.failure(String message)
    : this(ok: false, message: message);

  final bool ok;
  final String message;
}
