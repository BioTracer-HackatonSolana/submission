import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import {
  getBatch,
  getHealth,
  initializeBatch,
  listBatches,
  listEvents,
  listNodes,
  requestBatch,
  signBatch,
  transferCustody,
} from '../controllers/batchController';
import { requireApiKey } from '../middleware/auth';

const router = Router();

const createLimit = Number(process.env.BATCH_CREATE_LIMIT || 30);
const approveBatch = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number.isFinite(createLimit) && createLimit > 0 ? createLimit : 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Solicitação de lote recusada pelo rate limiter.' },
});

router.get('/health', getHealth);
router.get('/nodes', listNodes);

router.post('/batches', approveBatch, requireApiKey, requestBatch);
router.post('/batches/:batchId/sign', requireApiKey, signBatch);
router.get('/batches', listBatches);
router.get('/batches/:batchId/events', listEvents);
router.get('/batches/:batchId', getBatch);

router.post('/batch/init', approveBatch, requireApiKey, initializeBatch);
router.post('/batch/transfer', requireApiKey, transferCustody);
router.get('/batch/list', listBatches);
router.get('/batch/:batchId', getBatch);

export default router;
