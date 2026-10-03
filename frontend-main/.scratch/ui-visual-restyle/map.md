# UI visual restyle

## Destination

App tabulado (Dashboard / Ação / Histórico / Conta + papéis) no DNA visual fly.dev + pitch. API `init` / `transfer` intacta. Juiz vê lote real e prova Solana.

## Notes

- Hallmark audit já feito na sessão de plano (3 critical · 4 major · 3 minor).
- Skills: Hallmark component-scope; visual-restyle subagent; caveman off no código.
- Verificar Flutter web / analyze. `api_service.dart` freeze.
- Tracker: markdown local (este diretório).

## Decisions so far

- [Pitch brand tokens](issues/01-pitch-brand-tokens.md) — lockups 01–06; slogan e cobalt/navy iguais ao fly.dev.
- [Chrome and screens](issues/02-chrome-and-screens.md) — 4 tabs pintadas; LotFocusCard navy; prova na Ação + Histórico.
- [Verify API untouched](issues/03-verify-api-untouched.md) — `api_service.dart` sem diff; 11 testes ok.

## Not yet specified

- `design.md` portátil — só se alguém pedir `lock the system`.

## Out of scope

Auth real, iOS, novos endpoints, roteiro de 4 steps como home, métrica inventada, dark-mode completo, rewrite Riverpod.
