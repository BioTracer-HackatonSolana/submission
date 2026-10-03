import fs from 'fs';
import path from 'path';
import mysql, { Pool, PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { ApiError } from '../domain/errors';

export type BatchView = {
  id: number;
  code: string | null;
  productName: string;
  quantity: number;
  unit: string;
  expiresAt: string | null;
  pda: string | null;
  bump: number | null;
  chainStatus: number | null;
  createdAt: string;
  updatedAt: string;
  industryNodeId: number;
  transportNodeId: number | null;
  hospitalNodeId: number | null;
  custodyNodeId: number;
  industryPubkey: string;
  transportPubkey: string | null;
  hospitalPubkey: string | null;
  custodyPubkey: string;
  custodyRole: number;
};

export type TraceEventView = {
  id: number;
  batchId: number;
  chainStatus: number;
  action: number;
  nodePubkey: string;
  chainTimestamp: number;
  txSignature: string;
  reversed: boolean;
  createdAt: string;
};

export type NodeView = {
  id: number;
  role: number;
  name: string;
  pubkey: string;
  createdAt: string;
};

type Sql = Pool | PoolConnection;

let pool: Pool;

const BATCH_SELECT = `
  SELECT
    b.id,
    b.code,
    b.product_name AS productName,
    b.quantity,
    b.unit,
    b.expires_at AS expiresAt,
    b.pda,
    b.bump,
    b.chain_status AS chainStatus,
    b.created_at AS createdAt,
    b.updated_at AS updatedAt,
    b.industry_node_id AS industryNodeId,
    b.transport_node_id AS transportNodeId,
    b.hospital_node_id AS hospitalNodeId,
    b.custody_node_id AS custodyNodeId,
    ind.pubkey AS industryPubkey,
    tr.pubkey AS transportPubkey,
    hos.pubkey AS hospitalPubkey,
    cus.pubkey AS custodyPubkey,
    cus.role AS custodyRole
  FROM batches b
  JOIN nodes ind ON ind.id = b.industry_node_id
  LEFT JOIN nodes tr ON tr.id = b.transport_node_id
  LEFT JOIN nodes hos ON hos.id = b.hospital_node_id
  JOIN nodes cus ON cus.id = b.custody_node_id
`;

function dbConfig() {
  const database = process.env.DB_NAME || 'biotracer';
  if (!/^[A-Za-z0-9_]+$/.test(database)) {
    throw new ApiError(500, 'DB_NAME inválido.');
  }
  return {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'biotracer',
    password: process.env.DB_PASSWORD || '',
    database,
  };
}

function schemaStatements(): string[] {
  const file = path.resolve(__dirname, '../../schema.sql');
  const raw = fs.readFileSync(file, 'utf8');
  return raw
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.trim())
    .filter(Boolean);
}

async function replaceLegacySchema(): Promise<void> {
  const [cols] = await pool.query<RowDataPacket[]>(
    `SELECT COLUMN_NAME AS name
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'batches' AND COLUMN_NAME IN ('on_chain', 'chain_status')`,
  );
  const names = new Set(cols.map((col) => String(col.name)));
  if (!names.has('on_chain') || names.has('chain_status')) return;

  const [counts] = await pool.query<RowDataPacket[]>('SELECT COUNT(*) AS total FROM batches');
  if (Number(counts[0]?.total ?? 0) > 0) {
    throw new Error('Schema antigo de batches ainda tem lotes. Esvazie a tabela antes de migrar.');
  }

  await pool.query('SET FOREIGN_KEY_CHECKS = 0');
  await pool.query('DROP TABLE IF EXISTS trace_events, batches, nodes');
  await pool.query('SET FOREIGN_KEY_CHECKS = 1');
  console.log('Schema antigo removido; as tabelas novas serão criadas.');
}

export async function initDb(): Promise<void> {
  const config = dbConfig();
  const admin = await mysql.createConnection({
    host: config.host,
    port: config.port,
    user: config.user,
    password: config.password,
  });
  try {
    await admin.query(
      `CREATE DATABASE IF NOT EXISTS \`${config.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== 'ER_DBACCESS_DENIED_ERROR') throw error;
  } finally {
    await admin.end();
  }

  pool = mysql.createPool({
    ...config,
    waitForConnections: true,
    connectionLimit: 10,
    dateStrings: true,
    timezone: 'Z',
  });

  try {
    await pool.query('SELECT 1');
    await replaceLegacySchema();
    for (const statement of schemaStatements()) {
      await pool.query(statement);
    }
  } catch (error) {
    const code = (error as { code?: string }).code;
    const hint = 'Crie o banco e o usuário como root. O SQL está no topo de schema.sql.';
    if (code === 'ER_BAD_DB_ERROR' || code === 'ER_DBACCESS_DENIED_ERROR' || code === 'ER_ACCESS_DENIED_ERROR' || code === 'ECONNREFUSED') {
      throw new Error(`${hint} (${code})`);
    }
    throw error;
  }
  console.log(`MariaDB pronto (${config.database} @ ${config.host}:${config.port}).`);
}

export async function ping(): Promise<void> {
  await pool.query('SELECT 1');
}

export function connection(): Promise<PoolConnection> {
  return pool.getConnection();
}

export async function upsertNode(role: number, name: string, pubkey: string): Promise<void> {
  await pool.execute(
    `INSERT INTO nodes (role, name, pubkey) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE role = VALUES(role), name = VALUES(name)`,
    [role, name, pubkey],
  );
}

export async function listNodes(): Promise<NodeView[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT id, role, name, pubkey, created_at AS createdAt FROM nodes ORDER BY role, id',
  );
  return rows.map((row) => ({
    id: Number(row.id),
    role: Number(row.role),
    name: String(row.name),
    pubkey: String(row.pubkey),
    createdAt: String(row.createdAt),
  }));
}

export async function getNodeByPubkey(pubkey: string): Promise<NodeView | null> {
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT id, role, name, pubkey, created_at AS createdAt FROM nodes WHERE pubkey = ? LIMIT 1',
    [pubkey],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: Number(row.id),
    role: Number(row.role),
    name: String(row.name),
    pubkey: String(row.pubkey),
    createdAt: String(row.createdAt),
  };
}

function mapBatch(row: RowDataPacket): BatchView {
  return {
    id: Number(row.id),
    code: row.code == null ? null : String(row.code),
    productName: String(row.productName),
    quantity: Number(row.quantity),
    unit: String(row.unit ?? ''),
    expiresAt: row.expiresAt == null ? null : String(row.expiresAt).slice(0, 10),
    pda: row.pda == null ? null : String(row.pda),
    bump: row.bump == null ? null : Number(row.bump),
    chainStatus: row.chainStatus == null ? null : Number(row.chainStatus),
    createdAt: String(row.createdAt),
    updatedAt: String(row.updatedAt),
    industryNodeId: Number(row.industryNodeId),
    transportNodeId: row.transportNodeId == null ? null : Number(row.transportNodeId),
    hospitalNodeId: row.hospitalNodeId == null ? null : Number(row.hospitalNodeId),
    custodyNodeId: Number(row.custodyNodeId),
    industryPubkey: String(row.industryPubkey),
    transportPubkey: row.transportPubkey == null ? null : String(row.transportPubkey),
    hospitalPubkey: row.hospitalPubkey == null ? null : String(row.hospitalPubkey),
    custodyPubkey: String(row.custodyPubkey),
    custodyRole: Number(row.custodyRole),
  };
}

function batchKeyArgs(key: string): [number | null, number | null, string, number] {
  const numeric = /^\d+$/.test(key) ? Number(key) : null;
  return [numeric, numeric, key, numeric ?? 0];
}

async function selectBatch(sql: Sql, key: string, lock: boolean): Promise<BatchView | null> {
  const [rows] = await sql.query<RowDataPacket[]>(
    `${BATCH_SELECT}
     WHERE (? IS NOT NULL AND b.id = ?) OR b.code = ?
     ORDER BY CASE WHEN b.id = ? THEN 0 ELSE 1 END
     LIMIT 1
     ${lock ? 'FOR UPDATE' : ''}`,
    batchKeyArgs(key),
  );
  return rows[0] ? mapBatch(rows[0]) : null;
}

export function findBatch(key: string): Promise<BatchView | null> {
  return selectBatch(pool, key, false);
}

export function lockBatch(conn: PoolConnection, key: string): Promise<BatchView | null> {
  return selectBatch(conn, key, true);
}

export async function listBatches(): Promise<BatchView[]> {
  const [rows] = await pool.query<RowDataPacket[]>(`${BATCH_SELECT} ORDER BY b.created_at DESC, b.id DESC`);
  return rows.map(mapBatch);
}

export async function requestBatch(input: {
  code: string | null;
  productName: string;
  quantity: number;
  unit: string;
  expiresAt: string | null;
  industryPubkey: string;
}): Promise<BatchView> {
  const industry = await getNodeByPubkey(input.industryPubkey);
  if (!industry) throw new ApiError(403, 'Indústria não cadastrada.');
  if (industry.role !== 0) throw new ApiError(403, 'A pubkey informada não é um node de indústria.');

  if (input.code) {
    const existing = await findBatch(input.code);
    if (existing) {
      if (existing.chainStatus !== null) {
        throw new ApiError(409, 'Já existe um lote com esse código na blockchain.');
      }
      if (existing.industryPubkey !== industry.pubkey) {
        throw new ApiError(409, 'Esse código já foi solicitado por outra indústria.');
      }
      return existing;
    }
  }

  try {
    const [result] = await pool.execute<ResultSetHeader>(
      `INSERT INTO batches (
         code, product_name, quantity, unit, expires_at, industry_node_id, custody_node_id
       ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [input.code, input.productName, input.quantity, input.unit, input.expiresAt, industry.id, industry.id],
    );
    if (result.insertId > 0xffffffff) {
      throw new ApiError(500, 'batch_id excede o u32 do contrato.');
    }
    const created = await findBatch(String(result.insertId));
    if (!created) throw new ApiError(500, 'Lote criado não pôde ser lido.');
    return created;
  } catch (error) {
    if ((error as { code?: string }).code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'Já existe um lote com esse código.');
    }
    throw error;
  }
}

export async function saveProgress(
  sql: Sql,
  input: {
    id: number;
    pda: string;
    bump: number;
    chainStatus: number;
    custodyNodeId: number;
    transportNodeId: number | null;
    hospitalNodeId: number | null;
  },
): Promise<void> {
  await sql.execute(
    `UPDATE batches
     SET pda = ?, bump = ?, chain_status = ?, custody_node_id = ?, transport_node_id = ?, hospital_node_id = ?
     WHERE id = ?`,
    [
      input.pda,
      input.bump,
      input.chainStatus,
      input.custodyNodeId,
      input.transportNodeId,
      input.hospitalNodeId,
      input.id,
    ],
  );
}

export async function insertEvent(
  sql: Sql,
  input: {
    batchId: number;
    chainStatus: number;
    action: number;
    nodePubkey: string;
    chainTimestamp: number;
    txSignature: string;
    reversed: boolean;
  },
): Promise<void> {
  await sql.execute(
    `INSERT INTO trace_events (
       batch_id, chain_status, action, node_pubkey, chain_timestamp, tx_signature, reversed
     ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      input.batchId,
      input.chainStatus,
      input.action,
      input.nodePubkey,
      input.chainTimestamp,
      input.txSignature,
      input.reversed ? 1 : 0,
    ],
  );
}

export async function listEvents(batchId: number): Promise<TraceEventView[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT
       id,
       batch_id AS batchId,
       chain_status AS chainStatus,
       action,
       node_pubkey AS nodePubkey,
       chain_timestamp AS chainTimestamp,
       tx_signature AS txSignature,
       reversed,
       created_at AS createdAt
     FROM trace_events
     WHERE batch_id = ?
     ORDER BY id ASC`,
    [batchId],
  );
  return rows.map((row) => ({
    id: Number(row.id),
    batchId: Number(row.batchId),
    chainStatus: Number(row.chainStatus),
    action: Number(row.action),
    nodePubkey: String(row.nodePubkey),
    chainTimestamp: Number(row.chainTimestamp),
    txSignature: String(row.txSignature),
    reversed: Number(row.reversed) === 1,
    createdAt: String(row.createdAt),
  }));
}
