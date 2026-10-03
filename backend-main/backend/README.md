# BioTracer Relayer Backend

Este é o middleware Node.js/TypeScript (Relayer) para o projeto BioTracer. Ele atua como uma ponte entre o frontend (ex: aplicativo Flutter) e o Smart Contract (Anchor Program) implantado na Solana, gerenciando a comunicação, o pagamento de taxas (Relayer) e o cache em banco de dados local.

## ⚙️ Como o Backend Funciona?

Em um ambiente de supply chain na área da saúde, as entidades (hospitais, distribuidores, fabricantes) não devem se preocupar com carteiras de criptomoedas, possuir tokens SOL, ou pagar taxas de gás. O modelo adotado resolve isso utilizando o padrão **Relayer**.

1. **Recepção da Requisição:** O aplicativo envia requisições HTTP REST para o backend. As rotas sensíveis são protegidas por uma `API Key` para segurança.
2. **Construção da Transação:** O backend recebe os dados, localiza as chaves PDA (Program Derived Address) correspondentes na Solana e monta as instruções para o contrato inteligente.
3. **Assinatura e Custeio:** A carteira administrativa embutida no backend (a conta Relayer configurada no `.env`) assina a transação e paga todas as taxas da rede Solana.
4. **Índice em MariaDB:** O `id` numérico do lote é a PK do banco e o `batch_id` (u32) da conta Solana. O banco guarda o PDA, os dados do produto e uma cópia dos `TraceEvent` (status, action, node, timestamp, assinatura). A conta on-chain guarda só `batch_id`, `status` e a pubkey `biotracer`.

## 🚀 Guia de Instalação e Execução

### 1. Requisitos
- Node.js (v18+)
- NPM ou Yarn
- MariaDB 10.11+ (ou o `docker compose` desta pasta)

### 2. Configurando o Ambiente

Clone o repositório e instale as dependências:
```bash
cd backend
npm install
```

Crie o arquivo `.env` baseado no `.env.example`:
```bash
cp .env.example .env
```

Suba o MariaDB e configure o `.env` (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `API_SECRET_KEY`, `SOLANA_PAYER_SECRET_KEY`):

```bash
docker compose up -d
```

As tabelas (`nodes`, `batches`, `trace_events`) são criadas na subida da API. O `id` de `batches` é o `batch_id` on-chain.

### 3. Executando o Servidor

Inicie o servidor em modo de desenvolvimento (com hot-reload através do `ts-node-dev`):
```bash
npm run dev
```

Na primeira execução a API cria o schema em `schema.sql` e cadastra os três nodes do hackathon (indústria, transporte, hospital).

## 🔒 Segurança
- **API Key:** Rotas que gravam na blockchain exigem o header `x-api-key`.
- **Rate Limiting:** 100 requisições a cada 15 minutos por IP. A criação de lote tem um limite próprio (`BATCH_CREATE_LIMIT`, padrão 30). Se estourar, a solicitação é recusada e nenhuma conta é criada.
- **Quem assina:** a wallet `biotracer` (payer do `.env`) paga e assina toda transação. A API co-assina com a account do node (indústria na criação, transporte ou hospital na etapa seguinte). O contrato não conhece o papel do node; essa trava fica na API.
- **Payload Limiting:** Restrito a requisições JSON de até 10kb.

---

## 🌐 Endpoints da API

A URL base da API é `http://localhost:3015/api` (ou a porta definida no `.env`).

Status da conta: `0` indústria, `1` transporte, `2` hospital, `3` recusado, `4` descartado.
Action do evento: `0` aprovado, `1` reprovado.

O contrato só aceita status maior que o atual. Recusa e descarte são o caminho de retorno: o número sobe para 3 ou 4 e o fluxo para.

### 1. Criar lote
`POST /api/batches` (alias: `POST /api/batch/init`)
**[Protegida com `x-api-key` e rate limit de criação]**

A API reserva o `id`, deriva o PDA `["batch", id_u32_le]`, envia `initialize_batch` assinada pela wallet biotracer e pela account da indústria, grava o índice e devolve o PDA.

```json
{
  "code": "LOTE-1234",
  "nodePubkey": "PubKeyDaIndustria",
  "productName": "Paracetamol 500mg",
  "quantity": 1000,
  "unit": "caixas",
  "expiresAt": "2027-01-01"
}
```

`batchId` e `manufacturerPubkey` continuam aceitos no lugar de `code` e `nodePubkey`.

### 2. Assinar a etapa
`POST /api/batches/:batchId/sign` (alias: `POST /api/batch/transfer`)
**[Protegida com `x-api-key`]**

`:batchId` pode ser o id numérico ou o código do lote.

| De | Para | Quem assina | action |
| --- | --- | --- | --- |
| 0 indústria | 1 transporte | transporte | 0 |
| 0 | 3 recusado | transporte | 1 |
| 0 | 4 descartado | indústria do lote | 1 |
| 1 transporte | 2 hospital | hospital | 0 |
| 1 | 3 recusado | hospital | 1 |
| 1 | 4 descartado | transporte | 1 |
| 2 hospital | 3 ou 4 | hospital | 1 |
| 3 recusado | 4 descartado | hospital | 1 |

```json
{
  "nodePubkey": "PubKeyDoTransporte",
  "status": 1,
  "action": 0
}
```

No alias `/batch/transfer`, se `nodePubkey` não vier, a API usa `newOwnerPubkey` para avançar e `currentOwnerPubkey` para recusa ou descarte.

### 3. Consultas
- `GET /api/batches` e `GET /api/batch/list` — índice MariaDB
- `GET /api/batches/:batchId` e `GET /api/batch/:batchId` — índice mais a conta on-chain
- `GET /api/batches/:batchId/events` — eventos gravados
- `GET /api/nodes` — indústria, transporte e hospital cadastrados

### 4. Saúde
`GET /api/health`
Verifica se a API está no ar e qual é o saldo da carteira Relayer na Solana.

- **Retorno (200 OK):**
  ```json
  {
    "status": "ok",
    "relayerPubkey": "PubKeyDoRelayer...",
    "relayerBalanceSOL": 4.5,
    "network": "devnet"
  }
  ```
