import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart'
    show ChangeNotifierProvider, StateProvider;

import 'models.dart';
import 'mock_data.dart';
import 'api_service.dart';

final activeRoleProvider = StateProvider<OrganizationKind>((ref) {
  return OrganizationKind.manufacturer;
});

final traceFlowProvider = ChangeNotifierProvider<TraceFlowController>(
  (ref) => TraceFlowController(_createRepository()),
);

abstract interface class TraceRepository {
  DemoScenario get scenario;

  Future<OperationResult> registerLot({
    required String code,
    required String name,
    required int quantity,
    required String unit,
    required String expiresAt,
  });

  Future<OperationResult> sendTransfer();

  Future<OperationResult> decideTransfer({
    required bool accepted,
    String? reason,
    ChainProof? proof,
  });

  Future<List<Map<String, dynamic>>> fetchAvailableBatches();

  void setBatch(Map<String, dynamic> batchData);

  Future<void> resetScenario();

  void configure({bool? slowMode, bool? failNextOperation});
}

TraceRepository _createRepository() {
  const mode = String.fromEnvironment(
    'BIOTRACER_MODE',
    defaultValue: 'devnet',
  );
  if (mode.toLowerCase() != 'devnet') return DemoTraceRepository();
  const apiUrl = String.fromEnvironment(
    'BIOTRACER_API_URL',
    defaultValue: 'https://hackasolana.smartlinksbot.cloud',
  );
  const hospitalPubkey = String.fromEnvironment(
    'BIOTRACER_HOSPITAL_PUBKEY',
    defaultValue: 'CbZV5rZRJWuvKtYnHvZ6dKbfD7VzFivmcHPhdRYxCyLm',
  );
  const manufacturerPubkey = String.fromEnvironment(
    'BIOTRACER_MANUFACTURER_PUBKEY',
    defaultValue: '4PyD6SqXSp2aNo3kJNujvTZNTAkRy4iuuWxHFgD6tnR3',
  );
  const distributorPubkey = String.fromEnvironment(
    'BIOTRACER_DISTRIBUTOR_PUBKEY',
    defaultValue: '4bVut114wPf36jWW9aT9T37jgZoY95xf7XqGFhfmPvVR',
  );
  const apiKey = String.fromEnvironment(
    'BIOTRACER_API_KEY',
    defaultValue: 'senhamuitofodaaaaa',
  );

  return ApiTraceRepository(
    apiUrl: apiUrl.replaceFirst(RegExp(r'/$'), ''),
    apiKey: apiKey,
    hospitalPubkey: hospitalPubkey,
    manufacturerPubkey: manufacturerPubkey,
    distributorPubkey: distributorPubkey,
  );
}

class TraceFlowController extends ChangeNotifier {
  TraceFlowController(this.repository) : _scenario = repository.scenario;

  final TraceRepository repository;
  DemoScenario _scenario;
  bool _lotIdentified = false;
  bool isBusy = false;
  String? feedback;
  bool feedbackIsError = false;

  DemoScenario get scenario => _scenario;

  bool get lotIdentified => _lotIdentified;

  int get step {
    if (!_lotIdentified) return 0;
    switch (_scenario.transfer.status) {
      case TransferStatus.draft:
        return 1;
      case TransferStatus.pendingAcceptance:
        return 2;
      case TransferStatus.accepted:
      case TransferStatus.refused:
        return 3;
    }
  }

  String get actorLabel => step == 1 ? 'Distribuidor' : 'Hospital';

  Future<void> identifyMockLot([Map<String, dynamic>? forcedBatch]) async {
    if (isBusy || _lotIdentified) return;
    isBusy = true;
    feedback = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    
    if (forcedBatch != null) {
      repository.setBatch(forcedBatch);
      _scenario = repository.scenario;
    }
    
    _lotIdentified = true;
    feedback =
        'Lote ${_scenario.lot.code} identificado. Confira os dados antes de enviar.';
    feedbackIsError = false;
    isBusy = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchAvailableBatches() async {
    return repository.fetchAvailableBatches();
  }

  Future<void> registerProduct({
    required String name,
    required String quantity,
    required String unit,
    required String expiresAt,
  }) async {
    final parsedQuantity = int.tryParse(quantity) ?? 1;
    // Geração de código simples para a demo (ex: LOTE-8A2F)
    final code =
        'LOTE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    await _perform(
      () => repository.registerLot(
        code: code,
        name: name,
        quantity: parsedQuantity,
        unit: unit,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> sendTransfer() async {
    await _perform(repository.sendTransfer);
  }

  Future<void> decide({required bool accepted, String? reason}) async {
    await _perform(
      () => repository.decideTransfer(accepted: accepted, reason: reason),
    );
  }

  Future<void> reset() async {
    isBusy = true;
    feedback = null;
    notifyListeners();
    await repository.resetScenario();
    _scenario = repository.scenario;
    _lotIdentified = false;
    isBusy = false;
    notifyListeners();
  }

  void setScenario({bool? slow, bool? failNext}) {
    repository.configure(slowMode: slow, failNextOperation: failNext);
    notifyListeners();
  }

  Future<void> _perform(Future<OperationResult> Function() action) async {
    if (isBusy) return;
    isBusy = true;
    feedback = null;
    notifyListeners();
    final result = await action();
    if (result.ok) {
      _scenario = repository.scenario;
    }
    feedback = result.message;
    feedbackIsError = !result.ok;
    isBusy = false;
    notifyListeners();
  }
}
