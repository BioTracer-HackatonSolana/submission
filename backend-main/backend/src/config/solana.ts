import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import * as anchor from '@coral-xyz/anchor';
import dotenv from 'dotenv';
import { IDL, MedicineBatch } from '../idl/medicine_batch';

dotenv.config();

const RPC_URL = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';
const SECRET_KEY_STRING = process.env.SOLANA_PAYER_SECRET_KEY || '[]';
const PROGRAM_ID = process.env.PROGRAM_ID || IDL.address;

// Keypairs Fixos para o Hackathon (Simulando as 3 organizações)
export const manufacturerKeypair = Keypair.fromSecretKey(new Uint8Array([154,16,196,140,243,22,145,158,210,142,176,122,128,91,171,163,161,71,174,135,82,65,44,197,161,100,252,152,212,188,167,8,50,117,100,204,197,156,208,138,161,171,206,216,165,9,235,71,148,154,40,133,212,90,220,108,236,122,49,115,53,217,208,78]));
export const distributorKeypair = Keypair.fromSecretKey(new Uint8Array([136,30,233,237,250,107,20,181,50,255,33,97,215,55,184,113,7,141,254,207,78,0,157,227,214,22,77,100,102,35,132,79,53,105,127,181,155,185,6,182,59,108,75,234,242,153,59,56,25,201,230,15,66,211,139,128,130,180,110,25,36,43,118,212]));
export const hospitalKeypair = Keypair.fromSecretKey(new Uint8Array([201,86,73,92,197,37,86,69,159,102,192,117,253,128,173,142,147,47,168,126,139,87,196,126,74,162,13,184,215,254,6,198,172,75,8,160,183,235,69,8,172,201,252,38,114,226,91,118,189,33,163,184,48,166,223,193,158,66,118,193,178,37,92,226]));

// Para pagar a taxa da Solana, podemos usar o relayer (carteira principal) ou a própria organização.
// Aqui vamos usar o Manufacturer como "payer" global para simplificar o hackathon, 
// ou gerar um caso não exista um SOLANA_PAYER_SECRET_KEY
let payerKeypair: Keypair;
try {
  const secretKeyArray = JSON.parse(SECRET_KEY_STRING);
  if (secretKeyArray.length > 0) {
    payerKeypair = Keypair.fromSecretKey(new Uint8Array(secretKeyArray));
  } else {
    payerKeypair = manufacturerKeypair; // Fallback: Manufacturer paga tudo
  }
} catch (error) {
  payerKeypair = manufacturerKeypair;
}

export const connection = new Connection(RPC_URL, 'confirmed');

// Simple Wallet implementation for Anchor
class RelayerWallet implements anchor.Wallet {
  constructor(readonly payer: Keypair) {}
  async signTransaction<T extends anchor.web3.Transaction | anchor.web3.VersionedTransaction>(tx: T): Promise<T> {
    if (tx instanceof anchor.web3.Transaction) {
      tx.partialSign(this.payer);
    } else if (tx instanceof anchor.web3.VersionedTransaction) {
      tx.sign([this.payer]);
    }
    return tx;
  }
  async signAllTransactions<T extends anchor.web3.Transaction | anchor.web3.VersionedTransaction>(txs: T[]): Promise<T[]> {
    return txs.map((t) => {
      if (t instanceof anchor.web3.Transaction) {
        t.partialSign(this.payer);
      } else if (t instanceof anchor.web3.VersionedTransaction) {
        t.sign([this.payer]);
      }
      return t;
    });
  }
  get publicKey(): PublicKey {
    return this.payer.publicKey;
  }
}

export const wallet = new RelayerWallet(payerKeypair);

export const provider = new anchor.AnchorProvider(connection, wallet, {
  preflightCommitment: 'confirmed',
  commitment: 'confirmed',
});

// Set Anchor provider globally
anchor.setProvider(provider);

export const programId = new PublicKey(PROGRAM_ID);
export const program = new anchor.Program(IDL as unknown as anchor.Idl, provider);

export const cluster =
  process.env.SOLANA_NETWORK ||
  (RPC_URL.includes('devnet')
    ? 'devnet'
    : RPC_URL.includes('localhost') || RPC_URL.includes('127.0.0.1')
      ? 'localnet'
      : 'mainnet-beta');

const nodeSigners = [manufacturerKeypair, distributorKeypair, hospitalKeypair];

/** Chave que este relayer pode usar para co-assinar como node. A pubkey em si fica no MariaDB. */
export function signerForNode(pubkey: string): Keypair | undefined {
  return nodeSigners.find((keypair) => keypair.publicKey.toBase58() === pubkey);
}
