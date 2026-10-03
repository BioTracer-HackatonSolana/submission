import { PublicKey, SystemProgram } from '@solana/web3.js';
import * as anchor from '@coral-xyz/anchor';
import {
  cluster,
  connection,
  program,
  programId,
  signerForNode,
  wallet,
} from '../config/solana';
import { ApiError } from '../domain/errors';
import { planTransition, ROLE, STATUS } from '../domain/transitions';
import * as db from './dbService';

const MEDICINE_BATCH_SPACE = 8 + 4 + 1 + 32;

export function getBatchPda(batchId: number): [PublicKey, number] {
  const id = Buffer.alloc(4);
  id.writeUInt32LE(batchId);
  return PublicKey.findProgramAddressSync([Buffer.from('batch'), id], programId);
}

export function previewPda(batchId: number): { pda: string; bump: number } {
  const [pda, bump] = getBatchPda(batchId);
  return { pda: pda.toBase58(), bump };
}

function asNumber(value: unknown): number {
  if (typeof value === 'number') return value;
  if (value && typeof (value as { toNumber?: () => number }).toNumber === 'function') {
    return (value as { toNumber: () => number }).toNumber();
  }
  return Number(value);
}

function asPubkey(value: unknown): string {
  if (value && typeof (value as PublicKey).toBase58 === 'function') {
    return (value as PublicKey).toBase58();
  }
  if (value instanceof Uint8Array) return new PublicKey(value).toBase58();
  return String(value);
}

function explainChainError(error: unknown): string {
  if (!(error instanceof Error)) return 'Falha na transação Solana.';
  const logs = (error as Error & { logs?: string[] }).logs ?? [];
  const anchorLog = logs.find((line) => line.includes('Error Message:') || line.includes('already in use'));
  if (anchorLog) return anchorLog.replace(/^Program log: /, '');
  return error.message;
}

export type OnChainBatch = {
  batchId: number;
  status: number;
  biotracer: string;
  pda: string;
};

export async function fetchBatchAccount(batchId: number): Promise<OnChainBatch> {
  const [pda] = getBatchPda(batchId);
  const account = await (program.account as { medicineBatch: { fetch: (key: PublicKey) => Promise<Record<string, unknown>> } })
    .medicineBatch.fetch(pda);
  return {
    batchId: asNumber(account.batchId ?? account.batch_id),
    status: asNumber(account.status),
    biotracer: asPubkey(account.biotracer),
    pda: pda.toBase58(),
  };
}

type DecodedEvent = {
  batchId: number;
  status: number;
  action: number;
  node: string;
  timestamp: number;
};

async function readTraceEvent(signature: string): Promise<DecodedEvent | null> {
  const tx = await connection.getTransaction(signature, {
    commitment: 'confirmed',
    maxSupportedTransactionVersion: 1,
  });
  const logs = tx?.meta?.logMessages ?? [];
  for (const line of logs) {
    if (!line.startsWith('Program data: ')) continue;
    const decoded = (program.coder.events as { decode: (log: string) => { name?: string; data?: Record<string, unknown> } | null })
      .decode(line.slice('Program data: '.length));
    if (!decoded?.data || decoded.name?.toLowerCase() !== 'traceevent') continue;
    const data = decoded.data;
    return {
      batchId: asNumber(data.batchId ?? data.batch_id),
      status: asNumber(data.status),
      action: asNumber(data.action),
      node: asPubkey(data.node),
      timestamp: asNumber(data.timestamp),
    };
  }
  return null;
}

function txMeta(signature: string, pda: string) {
  return {
    txSignature: signature,
    txHash: signature,
    batchPda: pda,
    network: cluster,
    confirmation: 'confirmed' as const,
    confirmedAt: new Date().toISOString(),
    explorerUrl: `https://explorer.solana.com/tx/${signature}?cluster=${cluster}`,
  };
}

async function sendInitialize(batchId: number, pda: PublicKey, node: anchor.web3.Keypair): Promise<string> {
  const sameSigner = node.publicKey.equals(wallet.publicKey);
  return (program as unknown as {
    methods: {
      initializeBatch: (id: number) => {
        accounts: (accounts: Record<string, PublicKey>) => {
          signers: (signers: anchor.web3.Keypair[]) => { rpc: () => Promise<string> };
        };
      };
    };
  }).methods
    .initializeBatch(batchId)
    .accounts({
      batchAccount: pda,
      biotracer: wallet.publicKey,
      node: node.publicKey,
      systemProgram: SystemProgram.programId,
    })
    .signers(sameSigner ? [] : [node])
    .rpc();
}

async function sendUpdate(pda: PublicKey, node: anchor.web3.Keypair, newStatus: number, action: number): Promise<string> {
  const sameSigner = node.publicKey.equals(wallet.publicKey);
  return (program as unknown as {
    methods: {
      updateStatus: (status: number, action: number) => {
        accounts: (accounts: Record<string, PublicKey>) => {
          signers: (signers: anchor.web3.Keypair[]) => { rpc: () => Promise<string> };
        };
      };
    };
  }).methods
    .updateStatus(newStatus, action)
    .accounts({
      batchAccount: pda,
      biotracer: wallet.publicKey,
      node: node.publicKey,
    })
    .signers(sameSigner ? [] : [node])
    .rpc();
}

function nextCustody(
  batch: db.BatchView,
  node: db.NodeView,
  plan: ReturnType<typeof planTransition>,
): { custodyNodeId: number; transportNodeId: number | null; hospitalNodeId: number | null } {
  let transportNodeId = batch.transportNodeId;
  let hospitalNodeId = batch.hospitalNodeId;
  if (node.role === ROLE.TRANSPORT) transportNodeId = node.id;
  if (node.role === ROLE.HOSPITAL) hospitalNodeId = node.id;

  if (plan.kind === 'initialize' || plan.custody === 'industry') {
    return { custodyNodeId: batch.industryNodeId, transportNodeId, hospitalNodeId };
  }
  if (plan.custody === 'signer') {
    return { custodyNodeId: node.id, transportNodeId, hospitalNodeId };
  }
  if (!transportNodeId) {
    throw new ApiError(409, 'Não há node de transporte para devolver a custódia.');
  }
  return { custodyNodeId: transportNodeId, transportNodeId, hospitalNodeId };
}

export async function confirmSignature(input: {
  batchKey: string;
  nodePubkey: string;
  action: number;
  requestedStatus?: number;
}) {
  const node = await db.getNodeByPubkey(input.nodePubkey);
  if (!node) throw new ApiError(403, 'Node não cadastrado neste relayer.');
  const signer = signerForNode(node.pubkey);
  if (!signer) throw new ApiError(403, 'Este relayer não custodia a chave desse node.');

  const conn = await db.connection();
  let signature: string | null = null;
  let committed = false;
  try {
    await conn.beginTransaction();
    const batch = await db.lockBatch(conn, input.batchKey);
    if (!batch) throw new ApiError(404, 'Lote não encontrado.');
    if (batch.id < 1 || batch.id > 0xffffffff) {
      throw new ApiError(500, 'batch_id fora do u32 do contrato.');
    }
    if (batch.chainStatus === null && node.id !== batch.industryNodeId) {
      throw new ApiError(403, 'Só a indústria que solicitou o lote pode assinar a abertura.');
    }

    const plan = planTransition({
      onChain: batch.chainStatus !== null,
      chainStatus: batch.chainStatus,
      nodeRole: node.role,
      action: input.action,
      requestedStatus: input.requestedStatus,
      industryOwner: node.id === batch.industryNodeId,
    });

    const [pda, bump] = getBatchPda(batch.id);
    try {
      signature = plan.kind === 'initialize'
        ? await sendInitialize(batch.id, pda, signer)
        : await sendUpdate(pda, signer, plan.newStatus, plan.action);
    } catch (error) {
      const message = explainChainError(error);
      const status = /already in use/i.test(message) ? 409 : 400;
      throw new ApiError(status, message);
    }

    let decoded: DecodedEvent | null = null;
    try {
      decoded = await readTraceEvent(signature);
    } catch (error) {
      console.error('Evento TraceEvent não lido; o índice usa os argumentos enviados.', error);
    }
    const chainStatus = decoded?.status ?? (plan.kind === 'initialize' ? STATUS.INDUSTRY : plan.newStatus);
    const action = decoded?.action ?? (plan.kind === 'initialize' ? 0 : plan.action);
    const reversed = plan.kind === 'update' && plan.reversed;
    const links = nextCustody(batch, node, plan);
    const event = {
      batchId: batch.id,
      chainStatus,
      action,
      nodePubkey: decoded?.node ?? node.pubkey,
      chainTimestamp: decoded?.timestamp ?? Math.floor(Date.now() / 1000),
      txSignature: signature,
      reversed,
    };

    await db.saveProgress(conn, {
      id: batch.id,
      pda: pda.toBase58(),
      bump,
      chainStatus,
      ...links,
    });
    await db.insertEvent(conn, event);
    await conn.commit();
    committed = true;

    const fresh = await db.findBatch(String(batch.id));
    if (!fresh) throw new ApiError(500, `Transação confirmada (${signature}), mas o lote não foi relido.`);
    return {
      batch: fresh,
      action,
      reversed,
      event,
      bump,
      ...txMeta(signature, pda.toBase58()),
    };
  } catch (error) {
    if (!committed) {
      try {
        await conn.rollback();
      } catch (rollbackError) {
        console.error(rollbackError);
      }
    }
    if (signature && !committed && !(error instanceof ApiError && error.status < 500)) {
      throw new ApiError(500, `Transação confirmada (${signature}), mas o índice MariaDB não foi atualizado.`);
    }
    throw error;
  } finally {
    conn.release();
  }
}

export async function getHealth() {
  const balance = await connection.getBalance(wallet.publicKey);
  await db.ping();
  return {
    status: 'ok',
    database: 'mariadb',
    relayerPubkey: wallet.publicKey.toBase58(),
    biotracer: wallet.publicKey.toBase58(),
    relayerBalanceSOL: balance / anchor.web3.LAMPORTS_PER_SOL,
    network: cluster,
    programId: programId.toBase58(),
    batchSpaceBytes: MEDICINE_BATCH_SPACE,
  };
}
