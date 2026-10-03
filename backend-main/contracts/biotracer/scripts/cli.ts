/**
 * Cliente de terminal para o programa BioTracer (lib.rs atual).
 *
 * Uso (na pasta contracts/biotracer):
 *   npx tsx scripts/cli.ts pda 42
 *   npx tsx scripts/cli.ts init 42
 *   npx tsx scripts/cli.ts update 42 1 0
 *   npx tsx scripts/cli.ts fetch 42
 *   npx tsx scripts/cli.ts tx <assinatura>
 *   npx tsx scripts/cli.ts cost
 *   npx tsx scripts/cli.ts cost <assinatura>
 *
 * Carteiras (opcional):
 *   BIOTRACER_KEYPAIR=~/.config/solana/id.json   # payer (biotracer)
 *   NODE_KEYPAIR=~/.config/solana/id.json        # indústria / transporte / hospital
 *   RPC_URL=https://api.devnet.solana.com
 */
import * as anchor from "@coral-xyz/anchor";
import { PublicKey, SystemProgram, Keypair, Connection, LAMPORTS_PER_SOL } from "@solana/web3.js";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PROGRAM_ID = new PublicKey("CyD2G9sdMQnGm2GKnQJcEvMKQYdGiLB4mqurK1ustrHL");
const RPC_URL = process.env.RPC_URL ?? "https://api.devnet.solana.com";
const CLUSTER = RPC_URL.includes("devnet")
  ? "devnet"
  : RPC_URL.includes("localhost") || RPC_URL.includes("127.0.0.1")
    ? "custom"
    : "mainnet-beta";

const STATUS_LABEL: Record<number, string> = {
  0: "Indústria",
  1: "Transporte",
  2: "Hospital",
  3: "Recusado",
  4: "Descartado",
};

const ACTION_LABEL: Record<number, string> = {
  0: "Aprovado",
  1: "Reprovado",
};

/** 8 (discriminator) + 4 (batch_id) + 1 (status) + 32 (biotracer) */
const MEDICINE_BATCH_SPACE = 8 + 4 + 1 + 32;
const LAMPORTS_PER_SIGNATURE = 5_000;

/** IDL alinhado com programs/biotracer/src/lib.rs (não use o target/idl antigo). */
const IDL = {
  address: PROGRAM_ID.toBase58(),
  metadata: { name: "biotracer", version: "0.1.0", spec: "0.1.0" },
  instructions: [
    {
      name: "initializeBatch",
      discriminator: [126, 44, 205, 90, 220, 105, 105, 193],
      accounts: [
        { name: "batchAccount", writable: true },
        { name: "biotracer", writable: true, signer: true },
        { name: "node", signer: true },
        { name: "systemProgram", address: SystemProgram.programId.toBase58() },
      ],
      args: [{ name: "batchId", type: "u32" }],
    },
    {
      name: "updateStatus",
      discriminator: [147, 215, 74, 174, 55, 191, 42, 0],
      accounts: [
        { name: "batchAccount", writable: true },
        { name: "biotracer", writable: true, signer: true },
        { name: "node", signer: true },
      ],
      args: [
        { name: "newStatus", type: "u8" },
        { name: "action", type: "u8" },
      ],
    },
  ],
  accounts: [
    {
      name: "MedicineBatch",
      discriminator: [99, 128, 119, 187, 209, 100, 213, 118],
    },
  ],
  events: [
    {
      name: "TraceEvent",
      discriminator: [83, 247, 97, 132, 226, 82, 75, 118],
    },
  ],
  errors: [
    {
      code: 6000,
      name: "InvalidStatus",
      msg: "Invalid status. Must be 0 (Indústria), 1 (Transporte), 2 (Hospital), 3 (Recusado), or 4 (Descartado)",
    },
    { code: 6001, name: "InvalidStatusTransition", msg: "Status can only progress forward." },
  ],
  types: [
    {
      name: "MedicineBatch",
      type: {
        kind: "struct",
        fields: [
          { name: "batchId", type: "u32" },
          { name: "status", type: "u8" },
          { name: "biotracer", type: "pubkey" },
        ],
      },
    },
    {
      name: "TraceEvent",
      type: {
        kind: "struct",
        fields: [
          { name: "batchId", type: "u32" },
          { name: "status", type: "u8" },
          { name: "action", type: "u8" },
          { name: "node", type: "pubkey" },
          { name: "timestamp", type: "i64" },
        ],
      },
    },
  ],
} as const;

function expandHome(p: string): string {
  return p.startsWith("~/") ? path.join(os.homedir(), p.slice(2)) : p;
}

function loadKeypair(filePath: string): Keypair {
  const raw = JSON.parse(fs.readFileSync(expandHome(filePath), "utf8")) as number[];
  return Keypair.fromSecretKey(Uint8Array.from(raw));
}

function batchIdBytes(batchId: number): Buffer {
  const buf = Buffer.alloc(4);
  buf.writeUInt32LE(batchId);
  return buf;
}

function getBatchPda(batchId: number): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from("batch"), batchIdBytes(batchId)],
    PROGRAM_ID
  );
}

function explorerTx(sig: string): string {
  return `https://explorer.solana.com/tx/${sig}?cluster=${CLUSTER}`;
}

function explorerAddr(addr: string): string {
  return `https://explorer.solana.com/address/${addr}?cluster=${CLUSTER}`;
}

function lamportsToSol(lamports: number): number {
  return lamports / LAMPORTS_PER_SOL;
}

function makeProgram(biotracer: Keypair) {
  const connection = new Connection(RPC_URL, "confirmed");
  const wallet = new anchor.Wallet(biotracer);
  const provider = new anchor.AnchorProvider(connection, wallet, {
    commitment: "confirmed",
    preflightCommitment: "confirmed",
  });
  const program = new anchor.Program(IDL as unknown as anchor.Idl, provider);
  return { connection, program };
}

function requireBatchId(raw: string | undefined): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id < 0 || id > 0xffffffff) {
    throw new Error("batch_id deve ser um u32 (ex.: 42)");
  }
  return id;
}

async function cmdPda(batchId: number) {
  const [pda, bump] = getBatchPda(batchId);
  console.log({ batchId, pda: pda.toBase58(), bump, explorer: explorerAddr(pda.toBase58()) });
}

async function cmdInit(batchId: number) {
  const biotracer = loadKeypair(process.env.BIOTRACER_KEYPAIR ?? "~/.config/solana/id.json");
  const node = loadKeypair(process.env.NODE_KEYPAIR ?? process.env.BIOTRACER_KEYPAIR ?? "~/.config/solana/id.json");
  const { program } = makeProgram(biotracer);
  const [pda] = getBatchPda(batchId);

  console.log("Enviando initialize_batch…", {
    batchId,
    pda: pda.toBase58(),
    biotracer: biotracer.publicKey.toBase58(),
    node: node.publicKey.toBase58(),
    rpc: RPC_URL,
  });

  const sig = await program.methods
    .initializeBatch(batchId)
    .accounts({
      batchAccount: pda,
      biotracer: biotracer.publicKey,
      node: node.publicKey,
      systemProgram: SystemProgram.programId,
    })
    .signers(node.publicKey.equals(biotracer.publicKey) ? [] : [node])
    .rpc();

  console.log({ signature: sig, explorer: explorerTx(sig) });
  await cmdFetch(batchId);
}

async function cmdUpdate(batchId: number, newStatus: number, action: number) {
  if (![0, 1, 2, 3, 4].includes(newStatus)) {
    throw new Error("new_status deve ser 0, 1, 2, 3 ou 4");
  }
  if (![0, 1].includes(action)) {
    throw new Error("action deve ser 0 (Aprovado) ou 1 (Reprovado)");
  }
  const biotracer = loadKeypair(process.env.BIOTRACER_KEYPAIR ?? "~/.config/solana/id.json");
  const node = loadKeypair(process.env.NODE_KEYPAIR ?? process.env.BIOTRACER_KEYPAIR ?? "~/.config/solana/id.json");
  const { program } = makeProgram(biotracer);
  const [pda] = getBatchPda(batchId);

  console.log("Enviando update_status…", {
    batchId,
    newStatus,
    statusLabel: STATUS_LABEL[newStatus],
    action,
    actionLabel: ACTION_LABEL[action],
    pda: pda.toBase58(),
    biotracer: biotracer.publicKey.toBase58(),
    node: node.publicKey.toBase58(),
  });

  const sig = await program.methods
    .updateStatus(newStatus, action)
    .accounts({
      batchAccount: pda,
      biotracer: biotracer.publicKey,
      node: node.publicKey,
    })
    .signers(node.publicKey.equals(biotracer.publicKey) ? [] : [node])
    .rpc();

  console.log({ signature: sig, explorer: explorerTx(sig) });
  await cmdFetch(batchId);
}

async function cmdFetch(batchId: number) {
  const biotracer = loadKeypair(process.env.BIOTRACER_KEYPAIR ?? "~/.config/solana/id.json");
  const { program } = makeProgram(biotracer);
  const [pda] = getBatchPda(batchId);
  const account = await (program.account as any).medicineBatch.fetch(pda);
  const status = account.status as number;
  console.log({
    pda: pda.toBase58(),
    batchId: account.batchId,
    status,
    label: STATUS_LABEL[status] ?? "desconhecido",
    biotracer: account.biotracer?.toBase58?.() ?? String(account.biotracer),
    explorer: explorerAddr(pda.toBase58()),
  });
}

async function cmdTx(signature: string) {
  const connection = new Connection(RPC_URL, "confirmed");
  const tx = await connection.getTransaction(signature, {
    maxSupportedTransactionVersion: 1,
    commitment: "confirmed",
  });
  if (!tx) {
    console.log("Transação ainda não encontrada (confirme o cluster / aguarde).");
    return;
  }
  console.log({
    slot: tx.slot,
    err: tx.meta?.err ?? null,
    feeLamports: tx.meta?.fee,
    explorer: explorerTx(signature),
  });
  console.log("\n--- logs ---");
  for (const line of tx.meta?.logMessages ?? []) {
    console.log(line);
  }
}

function computeUnitsFromTx(tx: NonNullable<Awaited<ReturnType<Connection["getTransaction"]>>>): number | null {
  const consumed = tx.meta?.computeUnitsConsumed;
  if (consumed !== undefined && consumed !== null) return consumed;

  let totalCu = 0;
  const cuRegex = /consumed (\d+) of \d+ compute units/;
  for (const line of tx.meta?.logMessages ?? []) {
    const match = line.match(cuRegex);
    if (match) totalCu += parseInt(match[1], 10);
  }
  return totalCu > 0 ? totalCu : null;
}

async function cmdCostEstimate() {
  const connection = new Connection(RPC_URL, "confirmed");
  const rentLamports = await connection.getMinimumBalanceForRentExemption(MEDICINE_BATCH_SPACE);
  const signatures = 2;
  const feeLamports = signatures * LAMPORTS_PER_SIGNATURE;
  const initTotal = rentLamports + feeLamports;
  const lifecycle = initTotal + 2 * feeLamports;

  console.log({
    rpc: RPC_URL,
    cluster: CLUSTER,
    account: {
      spaceBytes: MEDICINE_BATCH_SPACE,
      layout: "8 disc + 4 batch_id + 1 status + 32 biotracer",
      rentExemptLamports: rentLamports,
      rentExemptSol: lamportsToSol(rentLamports),
    },
    initializeBatch: {
      signatures,
      feeLamports,
      feeSol: lamportsToSol(feeLamports),
      rentLamports,
      totalLamports: initTotal,
      totalSol: lamportsToSol(initTotal),
    },
    updateStatus: {
      signatures,
      feeLamports,
      feeSol: lamportsToSol(feeLamports),
      rentLamports: 0,
      totalLamports: feeLamports,
      totalSol: lamportsToSol(feeLamports),
    },
    exampleLifecycle: {
      description: "1 initialize_batch + 2 update_status (indústria → transporte → hospital)",
      totalLamports: lifecycle,
      totalSol: lamportsToSol(lifecycle),
      note: "Rent é depósito recuperável se a conta for fechada. Taxa de assinatura é gasto permanente.",
    },
  });
}

async function cmdCostFromTx(signature: string) {
  const connection = new Connection(RPC_URL, "confirmed");
  const tx = await connection.getTransaction(signature, {
    maxSupportedTransactionVersion: 1,
    commitment: "confirmed",
  });

  if (!tx || !tx.meta) {
    console.log("Transação não encontrada ou sem metadados disponíveis.");
    return;
  }

  const feeLamports = tx.meta.fee ?? 0;
  const computeUnits = computeUnitsFromTx(tx);
  const keys = tx.transaction.message.getAccountKeys({
    accountKeysFromLookups: tx.meta.loadedAddresses,
  });

  const balances = [];
  for (let i = 0; i < keys.length; i++) {
    const pre = tx.meta.preBalances[i] ?? 0;
    const post = tx.meta.postBalances[i] ?? 0;
    balances.push({
      address: keys.get(i)?.toBase58() ?? `index:${i}`,
      preLamports: pre,
      postLamports: post,
      deltaLamports: post - pre,
    });
  }

  const rentLamports = balances
    .filter((b) => b.deltaLamports > 0)
    .reduce((sum, b) => sum + b.deltaLamports, 0);

  const payerSpend = balances
    .filter((b) => b.deltaLamports < 0)
    .reduce((sum, b) => sum + Math.abs(b.deltaLamports), 0);

  console.log({
    signature,
    computeUnits,
    feeLamports,
    feeSol: lamportsToSol(feeLamports),
    rentTransferredLamports: rentLamports,
    rentTransferredSol: lamportsToSol(rentLamports),
    payerSpendLamports: payerSpend,
    payerSpendSol: lamportsToSol(payerSpend),
    balances,
    explorer: explorerTx(signature),
  });
}

async function main() {
  const [cmd, a, b, c] = process.argv.slice(2);
  switch (cmd) {
    case "pda":
      await cmdPda(requireBatchId(a));
      break;
    case "init":
      await cmdInit(requireBatchId(a));
      break;
    case "update":
      await cmdUpdate(requireBatchId(a), Number(b), c === undefined ? 0 : Number(c));
      break;
    case "fetch":
      await cmdFetch(requireBatchId(a));
      break;
    case "tx":
      if (!a) throw new Error("passe a assinatura da transação");
      await cmdTx(a);
      break;
    case "cu":
    case "cost":
      if (a) await cmdCostFromTx(a);
      else await cmdCostEstimate();
      break;
    default:
      console.log(`Uso:
  npx tsx scripts/cli.ts pda <batch_id>
  npx tsx scripts/cli.ts init <batch_id>
  npx tsx scripts/cli.ts update <batch_id> <0|1|2|3|4> [action 0|1]
  npx tsx scripts/cli.ts fetch <batch_id>
  npx tsx scripts/cli.ts tx <assinatura>
  npx tsx scripts/cli.ts cost
  npx tsx scripts/cli.ts cost <assinatura>
`);
      process.exit(cmd ? 1 : 0);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
