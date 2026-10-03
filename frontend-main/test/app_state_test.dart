import 'package:flutter_test/flutter_test.dart';

import 'package:biotracer/core/app_state.dart';
import 'package:biotracer/core/models.dart';
import 'package:biotracer/core/mock_data.dart';

void main() {
  test('identificação simulada libera o envio do lote', () async {
    final controller = TraceFlowController(DemoTraceRepository());

    expect(controller.step, 0);
    await controller.identifyMockLot();

    expect(controller.lotIdentified, isTrue);
    expect(controller.step, 1);
    expect(controller.feedback, contains('BT-2048'));
  });

  test('envio move o roteiro para a confirmação do hospital', () async {
    final repository = DemoTraceRepository();
    final result = await repository.sendTransfer();

    expect(result.ok, isTrue);
    expect(
      repository.scenario.transfer.status,
      TransferStatus.pendingAcceptance,
    );
    expect(repository.scenario.events.last.type, TraceEventType.transferSent);
  });

  test('aceitação atualiza a custódia e registra prova simulada', () async {
    final repository = DemoTraceRepository();
    await repository.sendTransfer();
    final result = await repository.decideTransfer(accepted: true);

    expect(result.ok, isTrue);
    expect(repository.scenario.transfer.status, TransferStatus.accepted);
    expect(repository.scenario.currentCustodianId, 'org-hospital');
    expect(
      repository.scenario.transfer.proofStatus,
      ProofStatus.registeredSimulated,
    );
    expect(
      repository.scenario.events.last.type,
      TraceEventType.proofRegistered,
    );
  });

  test(
    'recusa exige motivo e preserva o distribuidor como custodiante',
    () async {
      final repository = DemoTraceRepository();
      await repository.sendTransfer();
      final missingReason = await repository.decideTransfer(accepted: false);
      final result = await repository.decideTransfer(
        accepted: false,
        reason: 'Quantidade divergente',
      );

      expect(missingReason.ok, isFalse);
      expect(result.ok, isTrue);
      expect(repository.scenario.transfer.status, TransferStatus.refused);
      expect(repository.scenario.currentCustodianId, 'org-distributor');
      expect(
        repository.scenario.transfer.decisionReason,
        'Quantidade divergente',
      );
      expect(
        repository.scenario.transfer.proofStatus,
        ProofStatus.registeredLocal,
      );
    },
  );

  test('prova on-chain preserva assinatura e rede retornadas pela API', () {
    final proof = ChainProof.fromJson({
      'txSignature': '5kP-test',
      'batchPda': 'PDA-test',
      'network': 'devnet',
      'confirmation': 'confirmed',
      'confirmedAt': '2026-09-05T15:30:00.000Z',
      'explorerUrl': 'https://explorer.solana.com/tx/5kP-test?cluster=devnet',
    });

    expect(proof.status, ProofStatus.registeredOnchain);
    expect(proof.txSignature, '5kP-test');
    expect(proof.network, 'devnet');
  });

  test('reset volta ao cenário inicial e bloqueia duplo envio', () async {
    final repository = DemoTraceRepository();
    await repository.sendTransfer();
    final duplicate = await repository.sendTransfer();
    await repository.resetScenario();

    expect(duplicate.ok, isFalse);
    expect(repository.scenario.transfer.status, TransferStatus.draft);
    expect(repository.scenario.events, hasLength(2));
  });
}
