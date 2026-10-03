import { ApiError } from './errors';

/** Espelha MedicineBatch.status / TraceEvent.status no contrato. */
export const STATUS = {
  INDUSTRY: 0,
  TRANSPORT: 1,
  HOSPITAL: 2,
  REJECTED: 3,
  DISCARDED: 4,
} as const;

/** TraceEvent.action */
export const ACTION = {
  APPROVED: 0,
  REJECTED: 1,
} as const;

/** nodes.role. O contrato não conhece o papel; a API sim. */
export const ROLE = {
  INDUSTRY: 0,
  TRANSPORT: 1,
  HOSPITAL: 2,
} as const;

export const STATUS_LABEL: Record<number, string> = {
  0: 'indústria',
  1: 'transporte',
  2: 'hospital',
  3: 'recusado',
  4: 'descartado',
};

export const ROLE_LABEL: Record<number, string> = {
  0: 'indústria',
  1: 'transporte',
  2: 'hospital',
};

type Custody = 'signer' | 'industry' | 'transport';

type Rule = {
  from: number;
  to: number;
  role: number;
  action: 0 | 1;
  /** Só a indústria que abriu o lote. */
  ownerOnly?: boolean;
  custody: Custody;
};

/**
 * O programa só exige new_status > status atual (e <= 4) e biotracer == conta.
 * Esta tabela é a trava de papel do node. Recusa (3) e descarte (4) são o
 * processo reverso: o número sobe e a custódia operacional volta ou encerra.
 */
const RULES: Rule[] = [
  { from: STATUS.INDUSTRY, to: STATUS.TRANSPORT, role: ROLE.TRANSPORT, action: ACTION.APPROVED, custody: 'signer' },
  { from: STATUS.INDUSTRY, to: STATUS.REJECTED, role: ROLE.TRANSPORT, action: ACTION.REJECTED, custody: 'industry' },
  { from: STATUS.INDUSTRY, to: STATUS.DISCARDED, role: ROLE.INDUSTRY, action: ACTION.REJECTED, ownerOnly: true, custody: 'signer' },
  { from: STATUS.TRANSPORT, to: STATUS.HOSPITAL, role: ROLE.HOSPITAL, action: ACTION.APPROVED, custody: 'signer' },
  { from: STATUS.TRANSPORT, to: STATUS.REJECTED, role: ROLE.HOSPITAL, action: ACTION.REJECTED, custody: 'transport' },
  { from: STATUS.TRANSPORT, to: STATUS.DISCARDED, role: ROLE.TRANSPORT, action: ACTION.REJECTED, custody: 'signer' },
  { from: STATUS.HOSPITAL, to: STATUS.REJECTED, role: ROLE.HOSPITAL, action: ACTION.REJECTED, custody: 'transport' },
  { from: STATUS.HOSPITAL, to: STATUS.DISCARDED, role: ROLE.HOSPITAL, action: ACTION.REJECTED, custody: 'signer' },
  { from: STATUS.REJECTED, to: STATUS.DISCARDED, role: ROLE.HOSPITAL, action: ACTION.REJECTED, custody: 'signer' },
];

export type TransitionPlan =
  | { kind: 'initialize' }
  | {
      kind: 'update';
      newStatus: number;
      action: 0 | 1;
      reversed: boolean;
      custody: Custody;
    };

export function planTransition(input: {
  onChain: boolean;
  chainStatus: number | null;
  nodeRole: number;
  action: number;
  requestedStatus?: number;
  industryOwner: boolean;
}): TransitionPlan {
  const { onChain, chainStatus, nodeRole, action, requestedStatus, industryOwner } = input;

  if (action !== ACTION.APPROVED && action !== ACTION.REJECTED) {
    throw new ApiError(400, 'action deve ser 0 (aprovado) ou 1 (reprovado).');
  }

  if (!onChain || chainStatus === null) {
    if (nodeRole !== ROLE.INDUSTRY || !industryOwner) {
      throw new ApiError(403, 'Só a indústria que solicitou o lote pode assinar a abertura.');
    }
    if (action !== ACTION.APPROVED) {
      throw new ApiError(400, 'A abertura do lote só pode ser aprovada (action 0).');
    }
    if (requestedStatus !== undefined && requestedStatus !== STATUS.INDUSTRY) {
      throw new ApiError(400, 'A abertura grava status 0 (indústria).');
    }
    return { kind: 'initialize' };
  }

  if (chainStatus === STATUS.DISCARDED) {
    throw new ApiError(409, 'Lote descartado na blockchain.');
  }

  const candidates = RULES.filter((rule) => {
    if (rule.from !== chainStatus || rule.role !== nodeRole || rule.action !== action) return false;
    if (rule.ownerOnly && !industryOwner) return false;
    if (requestedStatus !== undefined && rule.to !== requestedStatus) return false;
    return true;
  });

  if (candidates.length === 1) {
    const rule = candidates[0];
    return {
      kind: 'update',
      newStatus: rule.to,
      action: rule.action,
      reversed: rule.action === ACTION.REJECTED,
      custody: rule.custody,
    };
  }

  if (candidates.length > 1) {
    const options = candidates.map((rule) => `${rule.to} (${STATUS_LABEL[rule.to]})`).join(' ou ');
    throw new ApiError(400, `Informe status: ${options}.`);
  }

  const role = ROLE_LABEL[nodeRole] ?? 'node';
  const from = STATUS_LABEL[chainStatus] ?? String(chainStatus);
  if (requestedStatus !== undefined) {
    const to = STATUS_LABEL[requestedStatus] ?? String(requestedStatus);
    throw new ApiError(403, `O node de ${role} não pode assinar a passagem de ${from} para ${to}.`);
  }
  throw new ApiError(403, `O node de ${role} não pode assinar um lote em ${from} com action ${action}.`);
}
