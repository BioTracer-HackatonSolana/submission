import { Keypair } from "@solana/web3.js";
const secret = new Uint8Array([205,19,94,110,156,247,108,68,145,144,54,3,231,153,37,89,229,221,209,205,218,213,225,93,167,193,220,143,173,137,29,229,135,226,218,191,6,123,181,252,242,236,251,234,154,147,46,100,58,222,105,130,87,176,243,222,180,182,72,13,35,148,60,138]);
const keypair = Keypair.fromSecretKey(secret);
console.log(keypair.publicKey.toBase58());
