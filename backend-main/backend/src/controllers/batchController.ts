import { Request, Response } from 'express';
import { PublicKey } from '@solana/web3.js';
import { wallet } from '../config/solana';
import { ApiError } from '../domain/errors';
import { ACTION, ROLE_LABEL, STATUS, STATUS_LABEL } from '../domain/transitions';
import * as db from '../services/dbService';
import * as solana from '../services/solanaService';

function sendError(res: Response, error: unknown): void {
  if (error instanceof ApiError) {
    if (error.status >= 500) console.error(error);
    res.status(error.status).json({ error: error.message });
    return;
  }
  console.error(error);
  const message = error instanceof Error ? error.message : 'Erro interno.';
  res.status(500).json({ error: message });
}

function bodyOf(req: Request): Record<string, unknown> {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    throw new ApiError(400, 'JSON inválido.');
  }
  return req.body as Record<string, unknown>;
}

function requirePubkey(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(400, `${field} é obrigatório.`);
  }
  try {
    return new PublicKey(value.trim()).toBase58();
  } catch {
    throw new ApiError(400, `${field} não é uma pubkey Solana.`);
  }
}

function optionalCode(value: unknown): string | null {
  if (value == null || value === '') return null;
  if (typeof value !== 'string' && typeof value !== 'number') {
    throw new ApiError(400, 'code/batchId deve ser texto.');
  }
  const code = String(value).trim();
  if (!code || code.length > 64) throw new ApiError(400, 'code/batchId deve ter entre 1 e 64 caracteres.');
  return code;
}

function parseQuantity(value: unknown): number {
  if (value == null || value === '') return 0;
  const quantity = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new ApiError(400, 'quantity deve ser um inteiro >= 0.');
  }
  return quantity;
}

function parseText(value: unknown, field: string, max: number, fallback = ''): string {
  if (value == null || value === '') return fallback;
  if (typeof value !== 'string') throw new ApiError(400, `${field} deve ser texto.`);
  const text = value.trim();
  if (text.length > max) throw new ApiError(400, `${field} passa de ${max} caracteres.`);
  return text;
}

function parseExpires(value: unknown): string | null {
  if (value == null || value === '') return null;
  if (typeof value !== 'string') throw new ApiError(400, 'expiresAt deve ser uma data AAAA-MM-DD.');
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (!match) throw new ApiError(400, 'expiresAt deve ser uma data AAAA-MM-DD.');
  const stamp = Date.parse(`${match[1]}-${match[2]}-${match[3]}T00:00:00Z`);
  if (Number.isNaN(stamp)) throw new ApiError(400, 'expiresAt inválido.');
  return `${match[1]}-${match[2]}-${match[3]}`;
}

function parseAction(value: unknown): number {
  const action = typeof value === 'number' ? value : Number(value);
  if (action !== ACTION.APPROVED && action !== ACTION.REJECTED) {
    throw new ApiError(400, 'action deve ser 0 (aprovado) ou 1 (reprovado).');
  }
  return action;
}

function parseStatus(value: unknown): number | undefined {
  if (value == null || value === '') return undefined;
  const status = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(status) || status < 0 || status > 4) {
    throw new ApiError(400, 'status deve ser 0, 1, 2, 3 ou 4.');
  }
  return status;
}

function batchKey(req: Request): string {
  const raw = req.params.batchId;
  const key = Array.isArray(raw) ? raw[0] : raw;
  if (!key) throw new ApiError(400, 'Identificador do lote ausente.');
  return key;
}

function presentBatch(batch: db.BatchView, onChain?: solana.OnChainBatch | null) {
  const preview = solana.previewPda(batch.id);
  const status = onChain?.status ?? batch.chainStatus ?? STATUS.INDUSTRY;
  return {
    id: batch.id,
    batchId: batch.code ?? String(batch.id),
    chainBatchId: batch.id,
    productName: batch.productName,
    quantity: batch.quantity,
    unit: batch.unit,
    expiresAt: batch.expiresAt,
    manufacturerPubkey: batch.industryPubkey,
    industryPubkey: batch.industryPubkey,
    transportPubkey: batch.transportPubkey,
    hospitalPubkey: batch.hospitalPubkey,
    custodyPubkey: batch.custodyPubkey,
    custodyRole: batch.custodyRole,
    custodyLabel: ROLE_LABEL[batch.custodyRole] ?? null,
    status,
    statusLabel: batch.chainStatus == null && !onChain ? 'aguardando assinatura' : STATUS_LABEL[status],
    chainStatus: batch.chainStatus,
    pendingSignature: batch.chainStatus == null && !onChain,
    batchPda: batch.pda ?? onChain?.pda ?? preview.pda,
    pda: batch.pda ?? onChain?.pda ?? preview.pda,
    bump: batch.bump ?? preview.bump,
    biotracer: onChain?.biotracer ?? wallet.publicKey.toBase58(),
    onChain: onChain ?? null,
    createdAt: batch.createdAt,
    updatedAt: batch.updatedAt,
  };
}

async function loadBatch(key: string): Promise<db.BatchView> {
  const batch = await db.findBatch(key);
  if (!batch) throw new ApiError(404, 'Lote não encontrado.');
  return batch;
}

async function openAndSign(body: Record<string, unknown>, requireName: boolean) {
  const industryPubkey = requirePubkey(
    body.nodePubkey ?? body.industryPubkey ?? body.manufacturerPubkey,
    'nodePubkey',
  );
  const code = optionalCode(body.code ?? body.batchId);
  const productName = parseText(body.productName, 'productName', 160);
  if (requireName && !productName) throw new ApiError(400, 'productName é obrigatório.');

  const batch = await db.requestBatch({
    code,
    productName,
    quantity: parseQuantity(body.quantity),
    unit: parseText(body.unit, 'unit', 32),
    expiresAt: parseExpires(body.expiresAt),
    industryPubkey,
  });
  if (batch.chainStatus !== null) {
    throw new ApiError(409, 'Esse lote já está na blockchain.');
  }

  return solana.confirmSignature({
    batchKey: String(batch.id),
    nodePubkey: industryPubkey,
    action: ACTION.APPROVED,
  });
}

function presentReceipt(receipt: Awaited<ReturnType<typeof solana.confirmSignature>>) {
  return {
    ...presentBatch(receipt.batch),
    txHash: receipt.txHash,
    txSignature: receipt.txSignature,
    batchPda: receipt.batchPda,
    network: receipt.network,
    confirmation: receipt.confirmation,
    confirmedAt: receipt.confirmedAt,
    explorerUrl: receipt.explorerUrl,
    action: receipt.action,
    reversed: receipt.reversed,
    event: receipt.event,
  };
}

export const requestBatch = async (req: Request, res: Response): Promise<void> => {
  try {
    const receipt = await openAndSign(bodyOf(req), true);
    res.status(200).json(presentReceipt(receipt));
  } catch (error) {
    sendError(res, error);
  }
};

export const signBatch = async (req: Request, res: Response): Promise<void> => {
  try {
    const body = bodyOf(req);
    const receipt = await solana.confirmSignature({
      batchKey: batchKey(req),
      nodePubkey: requirePubkey(body.nodePubkey, 'nodePubkey'),
      action: parseAction(body.action),
      requestedStatus: parseStatus(body.status),
    });
    const { batch, ...proof } = receipt;
    res.status(200).json({ ...presentBatch(batch), ...proof });
  } catch (error) {
    sendError(res, error);
  }
};

export const initializeBatch = async (req: Request, res: Response): Promise<void> => {
  try {
    const body = bodyOf(req);
    if (!optionalCode(body.batchId ?? body.code)) throw new ApiError(400, 'batchId é obrigatório.');
    const receipt = await openAndSign(body, false);
    res.status(200).json(presentReceipt(receipt));
  } catch (error) {
    sendError(res, error);
  }
};

export const transferCustody = async (req: Request, res: Response): Promise<void> => {
  try {
    const body = bodyOf(req);
    const key = optionalCode(body.batchId);
    if (!key) throw new ApiError(400, 'batchId é obrigatório.');
    const status = parseStatus(body.status);
    if (status === undefined) throw new ApiError(400, 'status é obrigatório.');
    const rejecting = status === STATUS.REJECTED || status === STATUS.DISCARDED;
    const signerValue = body.nodePubkey
      ?? (rejecting ? body.currentOwnerPubkey ?? body.newOwnerPubkey : body.newOwnerPubkey ?? body.currentOwnerPubkey);
    const signerField = body.nodePubkey ? 'nodePubkey' : rejecting ? 'currentOwnerPubkey' : 'newOwnerPubkey';
    const receipt = await solana.confirmSignature({
      batchKey: key,
      nodePubkey: requirePubkey(signerValue, signerField),
      action: rejecting ? ACTION.REJECTED : ACTION.APPROVED,
      requestedStatus: status,
    });
    res.status(200).json(presentReceipt(receipt));
  } catch (error) {
    sendError(res, error);
  }
};

export const listBatches = async (_req: Request, res: Response): Promise<void> => {
  try {
    const batches = await db.listBatches();
    res.status(200).json(batches.map((batch) => presentBatch(batch)));
  } catch (error) {
    sendError(res, error);
  }
};

export const getBatch = async (req: Request, res: Response): Promise<void> => {
  try {
    const batch = await loadBatch(batchKey(req));
    let onChain: solana.OnChainBatch | null = null;
    let chainReadError: string | undefined;
    try {
      onChain = await solana.fetchBatchAccount(batch.id);
    } catch (error) {
      if (batch.pda) {
        chainReadError = error instanceof Error ? error.message : 'Falha ao ler a conta.';
      }
    }
    res.status(200).json({ ...presentBatch(batch, onChain), chainReadError });
  } catch (error) {
    sendError(res, error);
  }
};

export const listEvents = async (req: Request, res: Response): Promise<void> => {
  try {
    const batch = await loadBatch(batchKey(req));
    const events = await db.listEvents(batch.id);
    res.status(200).json(events.map((event) => ({
      ...event,
      statusLabel: STATUS_LABEL[event.chainStatus] ?? null,
      actionLabel: event.action === ACTION.APPROVED ? 'aprovado' : 'reprovado',
    })));
  } catch (error) {
    sendError(res, error);
  }
};

export const listNodes = async (_req: Request, res: Response): Promise<void> => {
  try {
    const nodes = await db.listNodes();
    res.status(200).json(nodes.map((node) => ({
      ...node,
      roleLabel: ROLE_LABEL[node.role] ?? null,
    })));
  } catch (error) {
    sendError(res, error);
  }
};

export const getHealth = async (_req: Request, res: Response): Promise<void> => {
  try {
    res.status(200).json(await solana.getHealth());
  } catch (error) {
    sendError(res, error);
  }
};
