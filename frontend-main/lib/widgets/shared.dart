import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../core/theme.dart';

final dateFormat = DateFormat('dd/MM/yyyy');
final dateTimeFormat = DateFormat('dd/MM/yyyy · HH:mm');
final monthYearFormat = DateFormat('MM/yyyy');

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.onDark = false});

  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? AppColors.onAccent : AppColors.navy;
    return Semantics(
      label: 'BioTracer',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            onDark
                ? 'assets/branding/06-simbolo-branco.png'
                : 'assets/branding/05-simbolo-azul.png',
            height: compact ? 26 : 32,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: compact ? 8 : 10),
          Text(
            'BioTracer',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class BrandWatermark extends StatelessWidget {
  const BrandWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.1,
        child: Image.asset(
          'assets/branding/06-simbolo-branco.png',
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
        ),
      ),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? 'Demo' : 'Demonstração',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.cobalt),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String organizationKindLabel(OrganizationKind kind) {
  switch (kind) {
    case OrganizationKind.manufacturer:
      return 'Fabricante';
    case OrganizationKind.distributor:
      return 'Distribuidor';
    case OrganizationKind.hospital:
      return 'Hospital';
  }
}

String organizationKindHint(OrganizationKind kind) {
  switch (kind) {
    case OrganizationKind.manufacturer:
      return 'Emite o lote e a origem';
    case OrganizationKind.distributor:
      return 'Envia a custódia adiante';
    case OrganizationKind.hospital:
      return 'Confere e fecha o recebimento';
  }
}

String transferStatusLabel(TransferStatus status) {
  switch (status) {
    case TransferStatus.draft:
      return 'Pronto para enviar';
    case TransferStatus.pendingAcceptance:
      return 'Aguardando confirmação';
    case TransferStatus.accepted:
      return 'Aceita';
    case TransferStatus.refused:
      return 'Recusada';
  }
}

Color transferStatusColor(TransferStatus status) {
  switch (status) {
    case TransferStatus.draft:
      return AppColors.cobalt;
    case TransferStatus.pendingAcceptance:
      return AppColors.amber;
    case TransferStatus.accepted:
      return AppColors.green;
    case TransferStatus.refused:
      return AppColors.red;
  }
}

String proofStatusLabel(ProofStatus status) {
  switch (status) {
    case ProofStatus.notCreated:
      return 'Ainda não criado';
    case ProofStatus.pending:
      return 'Aguardando decisão';
    case ProofStatus.registeredOnchain:
      return 'Registrado na Solana · Devnet';
    case ProofStatus.registeredSimulated:
      return 'Registrado · simulado';
    case ProofStatus.registeredLocal:
      return 'Registrado localmente';
    case ProofStatus.failed:
      return 'Não registrado';
  }
}
