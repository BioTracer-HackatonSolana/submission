# BioTracer — plano de revisão para a apresentação do hackathon

## Objetivo

Usar o último dia para aumentar a clareza do problema, a credibilidade da proposta e a força da demonstração, sem ampliar o MVP para estoque, login, relatórios ou outros módulos.

O posicionamento será:

> O BioTracer cria uma trilha compartilhada e verificável das transferências de insumos hospitalares, começando por dispositivos médicos descartáveis.

O usuário protagonista é o profissional de recebimento hospitalar. O hospital ou a rede hospitalar é o primeiro comprador e convida distribuidores para participar. O relayer remove carteira, SOL e taxas da experiência operacional.

A promessa é provar quem declarou uma transferência e quando, apoiando conferência, investigação, disputa e recall. QR Code ou blockchain não devem ser apresentados como garantia de autenticidade física.

Os critérios publicados pela Superteam Brasil priorizam problema, solução e contexto brasileiro. Uso da Solana vale 15%; qualidade de código não é critério direto: <https://uni.superteam.com.br/>.

## Evidência para o pitch

- Usar como caso principal a suspensão e o recolhimento de um lote real de equipo de infusão pela Anvisa em 2026: <https://www.gov.br/anvisa/pt-br/assuntos/noticias-anvisa/2026/dispositivos-medicos-com-irregularidades-sao-barrados-pela-anvisa/>.
- Explicar que o BioTracer complementa, e não substitui, o UDI/SIUD brasileiro, voltado à identificação e ao monitoramento pós-mercado de dispositivos médicos: <https://www.gov.br/anvisa/pt-br/assuntos/produtosparasaude/udi>.
- Falsificação pode ser citada como risco secundário, sem prometer autenticação física: <https://www.gov.br/anvisa/pt-br/assuntos/noticias-anvisa/2026/anvisa-proibe-canula-cirurgica-e-produto-odontologico-falsificados>.

## Revisão do fluxo e das informações

Preservar o fluxo funcional atual:

`Identificar → Enviar → Conferir → Comprovante`

Mudanças prioritárias:

- Manter apenas o lote demonstrativo e a transferência entre distribuidor e hospital.
- Exibir sempre a organização e o papel atual também no mobile, tornando clara a troca de distribuidor para hospital.
- Trocar mensagens repetidas de “leitura automática em breve” por linguagem explícita de protótipo, como `Simular leitura do QR`. A câmera continua secundária; scanner real não é requisito do último dia.
- Manter o badge `Demonstração` visível em todas as larguras.
- Tratar o pedido como local enquanto aguarda aceite; somente o aceite gera a prova real na Devnet.
- Validar o motivo da recusa dentro do diálogo e impedir o fechamento com campo vazio.
- Identificar a origem de cada evento como `Cenário demonstrativo` ou `Solana · Devnet`. Apenas o último evento pode aparecer como on-chain.
- Transformar o estado final em comprovante com status, assinatura abreviada, timestamp, PDA, rede e botão para o Solana Explorer.
- Exibir a ressalva: “O registro comprova a declaração e o horário da transferência; não autentica fisicamente o produto.”
- Em falha de rede, manter a transferência pendente, mostrar `Não registrado` e oferecer retry. Nunca converter uma falha real automaticamente em sucesso simulado.

Ficam fora desta revisão: login, estoque operacional, relatórios, usuários, pagamentos, múltiplos produtos, carteira no frontend, integração real com UDI/SIUD e mudança estrutural do contrato Anchor.

## Integração mínima com o backend

O backend de referência é o repositório legado [MedTracer/backend](https://github.com/MedTracer/backend), mas o produto continua se chamando BioTracer.

Correções obrigatórias no relayer:

- Corrigir ou remover `medicine_batch_type.ts`, que importa um JSON inexistente e quebra `npm run build`.
- Usar os nomes gerados pelo Anchor: `initializeBatch`, `transferCustody` e `program.account.medicineBatch`.
- Corrigir os nomes de contas enviados aos builders Anchor.
- Fazer `/health` retornar `ready` somente com secret configurado, saldo suficiente, RPC acessível e programa executável. Carteira aleatória com saldo zero deve retornar `degraded`.
- Preparar previamente três lotes de gravação, por exemplo `BT-2048-A`, `BT-2048-B` e `BT-2048-C`, para permitir novas tomadas sem reutilizar uma custódia já transferida.
- Tratar a pubkey do relayer como custodiante do cenário demonstrativo. Não afirmar que ela prova a identidade jurídica do fabricante.

Contrato HTTP mínimo:

- `GET /api/health`: `status`, `network`, `programId`, `relayerPubkey`, `balanceSol` e checks de prontidão.
- `GET /api/batch/:batchId`: estado atual do PDA e URL do Explorer.
- `POST /api/batch/transfer`: recebe `batchId`, `newOwnerPubkey` e `status: 2`; retorna `txSignature`, `batchPda`, `network`, `confirmation`, `confirmedAt` e `explorerUrl`.

No Flutter:

- Criar `TraceRepository` com implementações `DemoTraceRepository` e `ApiTraceRepository`.
- Criar `ChainProof` com estados `notSubmitted`, `submitting`, `confirmed` e `failed`.
- Configurar `BIOTRACER_MODE=devnet|simulation`, `BIOTRACER_API_URL` e `DEMO_BATCH_ID` via `--dart-define`.
- Atualizar custódia, resultado e histórico apenas após confirmação real.
- Manter a recusa local, pois o contrato atual não representa rejeições; usar o caminho de aceite no vídeo.

## Execução em um dia, com duas pessoas

1. **0h–0h30 — alinhamento:** congelar posicionamento, cópia, lote da gravação e contrato HTTP.
2. **0h30–3h — paralelo:**
   - Pessoa A: corrigir backend, financiar relayer, preparar lotes e confirmar uma transferência Devnet.
   - Pessoa B: ajustar cópia, papéis, validação da recusa, origem dos eventos e comprovante final.
3. **Checkpoint em 3h:** se a prova Devnet não estiver estável, parar a integração e usar uma transação real previamente confirmada como evidência separada; o app continua marcado como simulado.
4. **3h–5h30:** integrar aceite, loading, sucesso, erro e retry, ou consolidar o fallback.
5. **5h30–6h30:** QA do fluxo, texto, responsividade, Explorer e nova tomada.
6. **6h30–8h:** finalizar roteiro, slides e descrição de até 300 palavras.
7. **8h–10h:** ensaio, gravação, revisão do link público, declaração de uso de IA e submissão com margem.

Roteiro do vídeo:

- 0:00–0:55: problema e caso brasileiro.
- 0:55–1:40: solução e usuário.
- 1:40–2:25: por que Solana e por que relayer.
- 2:25–3:40: demonstração ponta a ponta.
- 3:40–4:25: adoção pelo hospital, UDI/SIUD e expansão.
- 4:25–4:55: time, próximos passos e fechamento.

## Critérios de aceite

- `flutter analyze`, `flutter test` e `flutter build web --release` continuam passando.
- `npm run build` passa no backend.
- `/health` diferencia `ready` de `degraded`.
- Uma transferência Devnet retorna assinatura confirmada, altera o proprietário esperado e abre no Explorer.
- Duplo clique não duplica operação; owner já alterado é tratado como conflito ou resultado idempotente.
- Falha de RPC preserva estado pendente e permite retry.
- Fluxo revisado em 320, 375, 414, 768 e 1440 px.
- Nenhuma tela ou fala usa “MedTracer” como nome do produto.
- Nenhum texto promete autenticidade física garantida.
- A demonstração do produto cabe em até 75 segundos e o vídeo inteiro fica abaixo de cinco minutos.

## Premissas

- BioTracer é o nome oficial; MedTracer identifica apenas o endereço legado do backend.
- A visão permanece “insumos hospitalares”, com dispositivos descartáveis como primeiro caso demonstrado.
- Há duas pessoas disponíveis, acesso ao relayer e saldo Devnet.
- Não haverá mudança ou redeploy do contrato Anchor no último dia.
- O visual atual será preservado; a intervenção é de clareza, honestidade e prova verificável.
