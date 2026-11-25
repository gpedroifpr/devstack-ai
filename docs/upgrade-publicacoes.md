# Upgrade: gestao de publicacoes

## O que mudou

- Menu Gerenciar publicacao, visivel apenas para o autor identificado por UID.
- Edicao de titulo, descricao e codigo, sem substituir o documento inteiro.
- Marcar duvidas como resolvidas e reabrir.
- Filtros Todas, Em aberto, Resolvidas e Minhas, combinados com as tags.
- Limpar filtros quando a lista estiver vazia.
- Formularios com validacao, bloqueio de envio duplicado e preservacao do texto em falhas.
- Acoes dos detalhes com quebra de linha e botao de salvar com area de toque maior.

## Publicar

Na raiz de flutter_application_1:

```powershell
firebase deploy --only firestore:rules
.\scripts\build_web_from_env.ps1 -Deploy
```

As regras limitam atualizacoes a titulo, descricao, codigo, status e updatedAt.
A autoria, a comunidade e a data de criacao nao sao alteradas pela edicao.
Curtidas e comentarios permanecem em suas subcolecoes.

## Conferencia em duas contas

1. Conta A: publique uma duvida de teste.
2. Conta B: curta e comente; confirme que nao ha menu de edicao para esse post.
3. Conta A: edite a duvida; confirme que curtidas e comentarios permanecem.
4. Conta A: marque como resolvida; confira no filtro Resolvidas.
5. Conta B: atualize o feed e confira o novo texto e status.
6. Conta A: reabra a duvida e confira no filtro Em aberto.
7. No editor, altere um texto e cancele; confirme que o valor salvo nao mudou.
8. Combine um filtro de status com uma tag sem resultados e use Limpar filtros.

## Limites da validacao

Os testes automatizados cobrem persistencia local, restricao de autoria local,
validacao, preservacao de metadados, falha de gravacao, envio duplicado e layout
do editor em 360 pixels. O feed tambem foi conferido no navegador em 360 e 1280 pixels.
As gravacoes em Firebase e as regras precisam ser conferidas apos o deploy;
nenhum documento de producao foi editado durante esta rodada.
O feed ainda exige atualizar para receber edicoes de outra conta.
Os posts demonstrativos nao oferecem edicao.
