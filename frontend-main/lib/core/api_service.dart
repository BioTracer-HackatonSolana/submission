import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_state.dart' show TraceRepository;
import 'mock_data.dart';
import 'models.dart';

/// Cliente da API BioTracer.
///
/// Abertura: indústria assina `initialize_batch` (status 0).
/// Envio: transporte assina status 1.
/// Aceite: hospital assina status 2.
/// Recusa: hospital assina status 3 e a custódia volta para o transporte.
class ApiTraceRepository implements TraceRepository {
  ApiTraceRepository({
    required this.apiUrl,
    required this.apiKey,
    required this.hospitalPubkey,
    required this.manufacturerPubkey,
    required this.distributorPubkey,
  }) : _local = DemoTraceRepository();

  final String apiUrl;
  final String apiKey;
  final String hospitalPubkey;
  final String manufacturerPubkey;
  final String distributorPubkey;
  final DemoTraceRepository _local;

  static const _chainTimeout = Duration(seconds: 60);

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
  };

  @override
  DemoScenario get scenario => _local.scenario;

  @override
  Future<OperationResult> registerLot({
    required String code,
    required String name,
    required int quantity,
    required String unit,
    required String expiresAt,
  }) async {
    if (manufacturerPubkey.trim().isEmpty) {
      return const OperationResult.failure(
        'A carteira da indústria não foi configurada.',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('$apiUrl/api/batches'),
            headers: _headers,
            body: jsonEncode({
              'code': code,
              'nodePubkey': manufacturerPubkey,
              'productName': name,
              'quantity': quantity,
              'unit': unit,
              if (expiresAt.trim().isNotEmpty) 'expiresAt': expiresAt.trim(),
            }),
          )
          .timeout(_chainTimeout);
      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return OperationResult.failure(
          _errorMessage(body, 'A indústria não conseguiu abrir o lote.'),
        );
      }
      final proof = ChainProof.fromJson(body);
      final local = await _local.registerLot(
        code: code,
        name: name,
        quantity: quantity,
        unit: unit,
        expiresAt: expiresAt,
      );
      if (!local.ok) return local;
      _local.attachChainProof(
        proof,
        title: 'Lote aberto na Solana',
        description: _proofDescription(proof, 'Status 0, indústria.'),
      );
      return OperationResult.success(
        'Lote aberto na Solana. ${_short(proof.batchPda, 'PDA')} ${_short(proof.txSignature, 'tx')}',
      );
    } catch (_) {
      return const OperationResult.failure(
        'Sem resposta da API ao abrir o lote. Nada foi confirmado.',
      );
    }
  }

  @override
  Future<OperationResult> sendTransfer() async {
    if (distributorPubkey.trim().isEmpty) {
      return const OperationResult.failure(
        'A carteira do transporte não foi configurada.',
      );
    }
    return _sign(
      nodePubkey: distributorPubkey,
      status: 1,
      action: 0,
      failure: 'O transporte não conseguiu assinar o lote.',
      offline: 'Sem resposta da API no envio. A custódia não mudou.',
      title: 'Transporte assinou o lote',
      detail: 'Status 1, transporte.',
      success: 'Transporte confirmado na Solana. O hospital pode receber o lote.',
      applyLocal: (_) => _local.sendTransfer(),
    );
  }

  @override
  Future<OperationResult> decideTransfer({
    required bool accepted,
    String? reason,
    ChainProof? proof,
  }) async {
    if (!accepted) {
      final normalized = reason?.trim();
      if (normalized == null || normalized.isEmpty) {
        return const OperationResult.failure(
          'Informe o motivo da recusa para registrar a decisão.',
        );
      }
      if (hospitalPubkey.trim().isEmpty) {
        return const OperationResult.failure(
          'A carteira do hospital não foi configurada para registrar a recusa.',
        );
      }
      return _sign(
        nodePubkey: hospitalPubkey,
        status: 3,
        action: 1,
        failure: 'O hospital não conseguiu registrar a recusa.',
        offline: 'Sem resposta da API na recusa. A custódia não mudou.',
        title: 'Hospital recusou o lote',
        detail: 'Status 3. A custódia operacional volta para o transporte.',
        attachProof: false,
        applyLocal: (chainProof) => _local.decideTransfer(
          accepted: false,
          reason: normalized,
          proof: chainProof,
        ),
      );
    }

    if (hospitalPubkey.trim().isEmpty) {
      return const OperationResult.failure(
        'A carteira do hospital não foi configurada para a prova Devnet.',
      );
    }
    return _sign(
      nodePubkey: hospitalPubkey,
      status: 2,
      action: 0,
      failure: 'O hospital não conseguiu aceitar o lote.',
      offline: 'Sem resposta da API no aceite. A custódia não mudou.',
      title: 'Hospital aceitou o lote',
      detail: 'Status 2, hospital.',
      attachProof: false,
      applyLocal: (chainProof) =>
          _local.decideTransfer(accepted: true, proof: chainProof),
    );
  }

  Future<OperationResult> _sign({
    required String nodePubkey,
    required int status,
    required int action,
    required String failure,
    required String offline,
    required String title,
    required String detail,
    String success = '',
    bool attachProof = true,
    required Future<OperationResult> Function(ChainProof proof) applyLocal,
  }) async {
    final code = _local.scenario.lot.code;
    try {
      final response = await http
          .post(
            Uri.parse('$apiUrl/api/batches/${Uri.encodeComponent(code)}/sign'),
            headers: _headers,
            body: jsonEncode({
              'nodePubkey': nodePubkey,
              'status': status,
              'action': action,
            }),
          )
          .timeout(_chainTimeout);
      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return OperationResult.failure(_errorMessage(body, failure));
      }
      final chainProof = ChainProof.fromJson(body);
      final local = await applyLocal(chainProof);
      if (!local.ok) return local;
      if (attachProof) {
        _local.attachChainProof(
          chainProof,
          title: title,
          description: _proofDescription(chainProof, detail),
        );
      }
      return attachProof ? OperationResult.success(success) : local;
    } catch (_) {
      return OperationResult.failure(offline);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableBatches() async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/api/batches'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  void setBatch(Map<String, dynamic> batchData) => _local.setBatch(batchData);

  @override
  Future<void> resetScenario() => _local.resetScenario();

  @override
  void configure({bool? slowMode, bool? failNextOperation}) {
    _local.configure(slowMode: slowMode, failNextOperation: failNextOperation);
  }

  Map<String, dynamic> _decodeBody(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    final error = body['error'] ?? body['message'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return fallback;
  }

  String _proofDescription(ChainProof proof, String detail) {
    final pda = proof.batchPda;
    final tx = proof.txSignature;
    final link = proof.explorerUrl;
    return [
      detail,
      if (pda != null && pda.isNotEmpty) 'PDA $pda',
      if (tx != null && tx.isNotEmpty) 'tx $tx',
      if (link != null && link.isNotEmpty) link,
    ].join(' ');
  }

  String _short(String? value, String label) {
    if (value == null || value.isEmpty) return '';
    if (value.length <= 12) return '$label $value.';
    return '$label ${value.substring(0, 4)}…${value.substring(value.length - 4)}.';
  }
}
