# BioTracer — briefing original (escopo superseded pelo MVP)

> Este arquivo registra o briefing amplo usado antes da redução de escopo. A implementação atual segue `README.md` e `docs/plano-frontend-biotracer.md`, que limitam o produto ao roteiro de transferência de custódia.

Quero que você planeje o frontend do BioTracer em Flutter e Dart, com dados mockados funcionais e uma arquitetura preparada para integração futura com backend.

**Nesta etapa, produza o plano; não implemente o aplicativo ainda.** Primeiro inspecione o projeto, as instruções do repositório, o Flutter disponível e os arquivos anexados. Se já houver código, preserve o que for útil e proponha a evolução. Se não houver projeto Flutter, inclua sua criação no plano. Faça apenas perguntas que realmente mudem o escopo ou a arquitetura; para decisões rotineiras, recomende uma opção e explique brevemente.

## 1. Produto e escopo

BioTracer é uma plataforma B2B de gestão de insumos hospitalares, com possibilidade futura de atuação B2G. **Gestão de insumos é o núcleo; rastreabilidade onchain é um módulo complementar.**

Cada hospital deve operar independentemente. A gestão não pode depender de todos os hospitais e fornecedores aderirem a um sistema único.

O frontend precisa cobrir:
- estoque por produto, lote e local/setor;
- entradas, saídas por consumo, transferências internas e ajustes de inventário;
- recebimento de fornecedores e conferência;
- validade, estoque mínimo e apoio à reposição;
- histórico auditável das movimentações;
- consulta por QR Code;
- painel e relatórios operacionais;
- configuração de organização, setores e usuários;
- apresentação simulada da rastreabilidade onchain.

Não desenvolver neste escopo backend, contratos inteligentes, transações reais, pagamentos, emissão fiscal, prontuário, prescrição, gestão de leitos ou aplicação de insumos em pacientes. ESPtech e Unimed pertencem ao contexto do pitch; não devem aparecer como clientes ou integrações já disponíveis no app.

A ideia deve virar um frontend navegável com comportamento de produto, e não apenas uma coleção de telas bonitas.

## 2. Plataformas e referências

Planeje uma única base Flutter responsiva:
- **Flutter Web em desktop:** painel principal de gestão.
- **Android/mobile:** consulta e operação no estoque.
- **Tablet:** adaptação intermediária.
- Preserve a portabilidade para iOS, sem exigir build iOS em ambiente que não o suporte.

Anexos:
1. `01-referencia-desktop.png`: painel, estoque e detalhes de lote.
2. `02-referencia-mobile.png`: login, início, estoque, lote, saída e recebimento.
3. `03-branding-biotracer.png`: identidade visual e símbolo.

As imagens orientam composição, cores, hierarquia e densidade. **Este texto e as regras de domínio têm prioridade sobre textos, datas, contadores e exemplos das imagens.** Corrija inconsistências dos mockups: não copie contadores estáticos, datas incompatíveis ou produtos diferentes associados ao mesmo lote.

Implemente a interface com widgets Flutter reais. Não use as pranchas como imagem de fundo de uma tela, nem substitua a interface por WebView. Mantenha o logo como um asset independente e reutilizável; não redesenhe o símbolo como um “B” genérico.

## 3. Identidade e sistema visual

- Azul principal: `#3159ED`
- Marinho: `#102D3A`
- Verde-lima de destaque: `#DAF975`
- Fundo claro: `#F5F7F4`
- Superfícies: branco; bordas discretas.
- Texto marinho; texto escuro sobre verde-lima.
- Âmbar para atenção e vermelho para erro/perda/bloqueio, com ícone e rótulo além da cor.
- Tipografia sem serifa, contemporânea e legível, próxima das referências. Escolha uma família com licença adequada e carregamento local previsível.
- Espaçamento consistente em múltiplos de 8, cantos moderadamente arredondados e sombras sutis.
- Aparência limpa e profissional, adequada a um produto hospitalar. Evite estética de landing page, excesso de gradientes e decoração de criptomoedas.

Crie tokens, tema centralizado e componentes reutilizáveis: botões, campos, busca, filtros, tabelas/listas, badges, diálogos, notificações, timeline, estados vazios e indicadores de carregamento.

No desktop, use sidebar e barra superior; no mobile, navegação inferior e páginas de detalhe com retorno. Adapte tabelas para listas/cartões compactos, formulários e filtros ao espaço disponível. Não apenas reduza uma tela desktop.

A interface deve ser em português do Brasil, com datas, números e moeda formatados corretamente. Considere foco visível, teclado, leitores de tela, tamanho de texto ampliado e áreas de toque confortáveis.

## 4. Mapa de telas e fluxos

Planeje cada fluxo de ponta a ponta, incluindo revisão, confirmação e resultado.

**Acesso e organização**
- Login, recuperação de senha simulada e acesso à demonstração.
- Seleção/troca de hospital fictício e perfil de demonstração.
- Perfil, sessão expirada e acesso negado.
- Badge discreto e persistente “Demonstração”.

**Visão geral**
- Indicadores calculados a partir dos mesmos dados do estoque.
- Alertas acionáveis de validade e estoque mínimo.
- Consumo por setor, com unidade e período claros.
- Movimentações recentes e atalhos funcionais.

**Produtos e lotes**
- Lista com busca, filtros, ordenação e paginação.
- Cadastro/edição de produto: identificação, unidade e estoque mínimo.
- Cadastro de lote vinculado a produto: código, origem, fabricação e validade.
- Detalhes de produto e lote, saldo por setor, histórico e identificação.
- Arquivamento quando permitido, preservando referências históricas.

**Movimentações**
- Entrada vinculada a produto e lote.
- Saída por consumo, com quantidade, setor e motivo.
- Transferência entre setores do mesmo hospital.
- Ajuste de inventário com contagem física, diferença e justificativa.
- Revisão antes de confirmar, resultado e atualização das telas relacionadas.
- Listagem e detalhe de cada evento, com filtros por período, tipo, produto, lote e setor.

**Recebimentos**
- Lista de pendentes, aceitos e recusados.
- Detalhe da remessa, origem, produtos, lotes e quantidades.
- Conferência, aceite ou recusa com motivo.
- No MVP, recebimento integral por remessa; deixe recebimento parcial como evolução explícita.
- Entrada manual controlada para fornecedor que não utiliza BioTracer.

**Escanear e localizar**
- Leitura de QR quando suportada, fluxo simulado e digitação manual.
- Código encontrado, inválido, inexistente e permissão de câmera negada.
- Nunca abrir automaticamente URLs arbitrárias presentes em QR; interprete o formato esperado de identificação.

**Alertas e relatórios**
- Vencidos, próximos do vencimento e abaixo do mínimo.
- Ação do alerta levando ao produto/lote correspondente.
- Posição de estoque, consumo, movimentações e perdas por período.
- Exportação CSV funcional para dados filtrados, com tratamento de conteúdo que possa ser interpretado como fórmula.
- Diferencie saldo atual, consumo no período e perdas registradas; não crie métricas financeiras sem custos de origem.

**Configurações**
- Organização, setores/locais, usuários e perfis.
- Preferências de alertas.
- Controle de cenários mock, restauração dos dados e modo de falha/latência.
- Módulo de integrações com estados honestos, sem indicar conectores reais.

**Rastreabilidade**
- Seção secundária no lote e na movimentação.
- Histórico dos eventos, origem e referências.
- Estado do registro onchain separado do estado do estoque.
- Comprovante simulado claramente identificado, com estados “Não enviado”, “Pendente”, “Registrado — simulado” e “Falhou”.
- A gestão continua funcionando mesmo quando o módulo onchain está indisponível.

## 5. Regras de domínio que o plano deve preservar

- Separe organização, usuário, setor, fornecedor, produto, lote, posição de estoque, remessa e movimentação.
- Produto e lote têm identificadores distintos. Um lote pertence a um produto.
- Estoque é discriminado por organização + produto/lote + local.
- Quantidade de movimentação deve ser positiva; consumo e transferência não podem ultrapassar o saldo disponível.
- Uma transferência interna reduz a origem e aumenta o destino atomicamente, preservando o total do hospital. Não confunda transferência com consumo.
- Recebimento pendente não aumenta o saldo; aceite aumenta uma única vez; recusa não aumenta.
- Cadastro de lote não cria saldo automaticamente. Saldo inicial exige evento explícito de entrada.
- Bloqueie saída para uso de lotes vencidos ou bloqueados; preserve caminhos de ajuste/baixa com justificativa.
- Estoque baixo e validade são dimensões diferentes e podem ocorrer simultaneamente.
- Onchain, recebimento e situação do estoque também são estados independentes.
- Impedir duplo envio de formulários e duplo aceite na simulação.
- Movimentação confirmada não é apagada nem reescrita; correções geram evento de ajuste/estorno autorizado.
- Perfis propostos: administrador, operador de estoque e gestor/auditor de consulta. Descreva a matriz de ações permitidas.
- A simulação de permissões no frontend não substitui autorização no backend futuro.
- Trocar de hospital não pode misturar saldos, caches ou históricos.
- Não afirmar autenticidade física de insumos a partir de QR, hashes ou blockchain.

## 6. Mocks que realmente simulam o produto

Use dados fictícios relacionais e determinísticos, cobrindo uso normal, vazio, erro, atraso, vencimento e estoque insuficiente.

Inclua pelo menos dois hospitais para validar isolamento e vários produtos, lotes e setores. Use como exemplo principal:
- Hospital Central, setor Almoxarifado.
- Equipo de infusão, lote BT-2048, 120 unidades.
- Luva nitrílica M, lote BT-2049, 800 unidades.
- Seringa 10 mL, lote BT-2050, 40 unidades.
- Uma remessa pendente separada, sem incluir sua quantidade no saldo.

Use um relógio injetável para calcular alertas e datas. Seed, “hoje” simulado, gráficos e histórico precisam ser coerentes; não fixe contagens da referência visual.

As alterações devem persistir localmente para uma demonstração útil e ser restauráveis por “Restaurar dados de demonstração”. Não persistir senhas nem tratar sessão simulada como autenticação segura.

Preveja latência e falhas controláveis. Indicadores, listas e relatórios devem refletir os mesmos dados após cada operação. Câmera indisponível não pode impedir testar o fluxo de consulta.

## 7. Arquitetura preparada para backend

Proponha estrutura por funcionalidades com separação clara entre apresentação, estado/controladores, domínio e acesso a dados, sem camadas artificiais.

- Views não acessam dados mockados diretamente.
- Defina interfaces de repositórios/serviços e injeção de dependências.
- Implementações mock devem poder ser substituídas por adapters HTTP sem reescrever telas.
- Separe DTOs de modelos de domínio quando houver transformação real.
- Defina contratos para autenticação, organizações, catálogo, estoque, movimentações, recebimentos, alertas, relatórios e rastreabilidade.
- Documente contratos propostos, não uma API supostamente já existente.
- Preveja busca, paginação, filtros, ordenação, erros tipados, cancelamento/descartes de respostas antigas e estados de sessão.
- Planeje IDs, timestamps, unidade, dinheiro em representação decimal segura, versionamento de registros e chaves de idempotência para operações de escrita.
- Centralize configuração de ambiente mock/API. Um modo de API ainda não conectado deve falhar de forma clara, sem inventar sucesso.
- Tokens e endpoints futuros não ficam espalhados nas telas; não colocar segredos no frontend.
- No futuro, blockchain é acessada por um serviço/backend. O frontend não deve custodiar chave privada nem assinar transações reais neste escopo.
- IDs estáveis de produto/lote não devem ser substituídos por hashes de campos mutáveis. Hashes de versão/evento pertencem ao contrato de rastreabilidade.

Recomende roteamento, gestão de estado, persistência local e bibliotecas com base no repositório e em documentação oficial atual. Explique decisões relevantes sem listar alternativas em excesso. Evite dependências experimentais desnecessárias.

## 8. Qualidade e critérios de aceite

Planeje verificações proporcionais ao escopo:
- análise estática e formatação;
- testes de regras de saldo, recebimento idempotente, transferência interna, ajuste, validade e isolamento entre hospitais;
- testes de widgets para formulários e estados críticos;
- fluxo integrado de cadastrar produto/lote, registrar entrada, consumir parte, transferir entre setores e consultar histórico;
- teste de receber, recusar e impedir recebimento duplicado;
- conferência visual desktop, tablet e mobile, incluindo texto ampliado e teclado;
- build Web e Android quando o ambiente permitir, com limitações registradas claramente.

A futura entrega deve conter código organizado, instruções para executar, seeds/mocks, configuração de ambiente, documentação dos contratos e pontos exatos onde conectar o backend.

Nenhum botão relevante deve ser apenas decorativo. Estados carregando, vazio, erro, sem permissão, salvando e sucesso precisam ser planejados. Recursos fora do MVP devem estar explicitamente fora do escopo, sem botões que aparentem funcionar.

## 9. O que entregar agora: o plano

Entregue:
1. Entendimento do produto e premissas.
2. Diagnóstico do repositório/ambiente.
3. Mapa de páginas, navegação e perfis.
4. Sistema visual e comportamento responsivo.
5. Modelo de dados, estados e regras.
6. Arquitetura, estrutura de pastas e contratos propostos.
7. Estratégia de mocks e transição ao backend.
8. Etapas de implementação em ordem de dependência, com entregáveis verificáveis e critérios de conclusão.
9. Estratégia de validação e principais riscos.
10. Perguntas pendentes realmente impeditivas, se houver.

Priorize primeiro uma fatia funcional completa: acesso demonstrativo → estoque → detalhe de lote → entrada/saída → histórico. Depois amplie para recebimentos, transferências, alertas, relatórios, configurações e módulo onchain.

Salve o plano em `docs/plano-frontend-biotracer.md` se o modo e o ambiente permitirem escrita; caso contrário, apresente o plano completo na resposta. Aguarde minha instrução para começar a codar.
