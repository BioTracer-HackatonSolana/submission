# BioTracer — MVP implementado

## Decisão de escopo

O frontend foi reduzido ao único problema demonstrado no pitch: **transferir a custódia de um lote entre organizações e manter um histórico verificável**.

O roteiro é intencionalmente ponta a ponta:

`Identificar lote → Transferência → Histórico`

A etapa de seleção já abre o preview da câmera do dispositivo. A leitura do QR está deliberadamente desativada: o botão `Usar lote demo` carrega o lote fixo do cenário. No mobile, o fluxo usa cards compactos para seleção, envio, recebimento e histórico.

O cenário usa o lote `BT-2048`, de 120 equipos de infusão, com fabricante, distribuidor e hospital simulados. O hospital aceita ou recusa o recebimento; a recusa exige motivo. Depois da decisão, a custódia e o histórico mudam de forma determinística.

## O que foi removido

Login, dashboard de indicadores, estoque operacional, consumo, transferência interna, alertas, relatórios, configurações, perfis, CSV, scanner e persistência local foram removidos por não serem necessários para validar a proposta principal. A blockchain é apenas uma prova de integridade explicitamente marcada como `Registrado · simulado`.

## Arquitetura atual

- `DemoTraceRepository`: estado mockado em memória, seed fixo, latência/falha injetáveis para testes.
- `TraceFlowController`: orquestra o roteiro, impede duplo envio e expõe feedback de sucesso/erro.
- `TraceFlowScreen`: workbench responsivo sem shell global; rail de quatro etapas em desktop e coluna única em telas menores.
- `_CameraSheet`: preview real de câmera com tratamento de permissão/indisponibilidade; sem captura ou decodificação nesta versão.
- Tokens de UI em `lib/core/theme.dart`, com cores BioTracer, Inter para corpo e Space Grotesk para títulos.

## Critérios de aceite

- Sem login ou navegação para módulos fora do roteiro.
- A câmera pode ser aberta no início do roteiro; se a permissão/ambiente falhar, a simulação continua disponível.
- A leitura automática permanece fora do escopo desta versão.
- Aceite só habilita após conferência de identidade e quantidade.
- Recusa sem motivo não é registrada.
- Aceite atualiza a custódia para o hospital; recusa mantém o distribuidor.
- Histórico sempre mostra os eventos anteriores e a prova simulada final.
- Layout validado em 320, 375, 414, 768 e desktop web, sem overflow horizontal.
