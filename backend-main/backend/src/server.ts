import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import batchRoutes from './routes/batchRoutes';
import { distributorKeypair, hospitalKeypair, manufacturerKeypair, wallet } from './config/solana';
import { ROLE } from './domain/transitions';
import { initDb, upsertNode } from './services/dbService';

dotenv.config();

const app = express();
const port = process.env.PORT || 3015;

// Configurar trust proxy pois estamos atrás de um Nginx (Reverse Proxy)
app.set('trust proxy', 1);

// Segurança de Headers HTTP
app.use(helmet());

// Prevenção de DDoS / Rate Limiting (Máx 100 requisições a cada 15 min por IP)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Muitas requisições deste IP, tente novamente mais tarde.' }
});
app.use(limiter);

app.use(cors());
// Limita o payload de JSON a 10kb
app.use(express.json({ limit: '10kb' }));

// API Routes
app.use('/api', batchRoutes);

initDb()
  .then(async () => {
    await upsertNode(ROLE.INDUSTRY, 'Indústria', manufacturerKeypair.publicKey.toBase58());
    await upsertNode(ROLE.TRANSPORT, 'Transporte', distributorKeypair.publicKey.toBase58());
    await upsertNode(ROLE.HOSPITAL, 'Hospital', hospitalKeypair.publicKey.toBase58());
    app.listen(port, () => {
      console.log(`BioTracer API em http://localhost:${port}`);
      console.log('biotracer', wallet.publicKey.toBase58());
      console.log('indústria', manufacturerKeypair.publicKey.toBase58());
      console.log('transporte', distributorKeypair.publicKey.toBase58());
      console.log('hospital', hospitalKeypair.publicKey.toBase58());
    });
  })
  .catch((err) => {
    console.error('Falha ao iniciar o banco:', err);
    process.exit(1);
  });
