# BioTracer MVP

Frontend Flutter demonstrativo do problema central do pitch: registrar a transferência de custódia de um lote entre organizações, com confirmação do destinatário e histórico verificável.

O site oficial (PT/EN) está em [BioTracer-HackatonSolana/site](https://github.com/BioTracer-HackatonSolana/site). Este repositório é só o app; no Fly ele responde em `https://biotracer-hackathon.fly.dev/`.

## Rodar

```bash
flutter pub get
flutter run -d chrome
```

Também é possível executar em um dispositivo Android conectado. O app abre diretamente no roteiro de demonstração; não há login.

## Roteiro mockado

1. O usuário abre a câmera do dispositivo para identificar um lote.
2. Como a leitura de QR ainda não está ativa, “Usar lote demo” carrega o lote `BT-2048` (Equipo de infusão, 120 unidades). A tela deixa essa simulação explícita.
3. O Distribuidor Piloto envia o lote ao Hospital Piloto.
4. O hospital confere identidade e quantidade, e aceita ou recusa a transferência.
5. O histórico do lote registra a decisão e exibe a origem da prova: `Registrado · simulado` no modo local, `Registrado localmente` para uma recusa ou `Registrado na Solana · Devnet` quando o relayer confirma a transação.

O preview da câmera é real quando o ambiente concede permissão, mas não captura, decodifica ou interpreta imagens. O modo padrão é determinístico e mantido apenas em memória. O botão de reinício restaura o cenário inicial.

### Prova Devnet opcional

Para a apresentação, o roteiro pode usar o relayer Node do repositório de backend sem alterar o fluxo de UX. O app só aplica o aceite depois de receber uma resposta 2xx com assinatura confirmada:

```bash
flutter run -d chrome \
  --dart-define=BIOTRACER_MODE=devnet \
  --dart-define=BIOTRACER_API_URL=http://localhost:3000 \
  --dart-define=DEMO_BATCH_ID=BT-2048 \
  --dart-define=BIOTRACER_HOSPITAL_PUBKEY=<carteira-do-hospital>
```

Se a API estiver indisponível, a custódia não muda e o usuário recebe uma mensagem de falha acionável. Sem `BIOTRACER_MODE=devnet`, a demo permanece local e não tenta esconder a simulação.

## Estrutura

- `lib/core/models.dart`: organizações, lote, transferência, eventos e estados de prova.
- `lib/core/app_state.dart`: repositório mock e controlador do roteiro.
- `lib/screens/trace_flow_screen.dart`: workbench responsivo do fluxo ponta a ponta.
- `lib/widgets/shared.dart`: marca, badges e componentes de informação.
- `lib/core/theme.dart`: tokens de cor, tipografia e estados de interação.
- `assets/branding`: logotipo BioTracer fornecido.
- `assets/fonts`: Inter para corpo e Space Grotesk para títulos, carregadas localmente.

## Verificação

```bash
flutter analyze
flutter test
flutter build web --release
```

Os testes cobrem envio, aceite, recusa com motivo, reinício, fluxo ponta a ponta e renderização nas larguras 320, 375, 414 e 768 px.
