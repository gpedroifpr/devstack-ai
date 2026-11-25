# Aparencia e temas

Atualizacao local de 18/11/2026. Nao publicada automaticamente.

## Alteracoes

- Menu de sol/lua no acesso inicial e no cabecalho do aplicativo.
- Temas claro e escuro com preferencia salva neste navegador (nao por conta).
- Configuracoes da IA preservadas no menu de aparencia e opcoes.
- Paleta adaptada para textos, formularios, perfil, comunidades e publicacoes.
- Conteudo centralizado com largura maxima de 1100 px em computadores.
- Publicacoes com mais espaco e titulos mais legiveis.
- Chat inicial simplificado, atalhos responsivos e respostas sem moldura extra.
- Fundos sobre fotografias preservam contraste em ambos os temas.

## Verificacao

- 61 testes selecionados passaram, incluindo cinco testes novos de tema.
- A suite inclui historico, servico Gemini, navegacao, Google login (erros),
  recuperacao de senha, fotos, curtidas, edicao, favoritos, comunidades e e-mail.
- O teste padrao de contador em widget_test.dart nao faz parte desta suite.
- Build web de verificacao em build/theme-review, separado de build/web.
- Testes visuais locais em Chrome, como visitante, sem alteracao de dados.
- Respostas simuladas no navegador servem apenas para conferir a apresentacao;
  nao comprovam disponibilidade da API Gemini.

## Publicacao

Na pasta flutter_application_1, com o arquivo .env correto:

```powershell
.\scripts\build_web_from_env.ps1 -Deploy
```

Esse fluxo gera a versao de publicacao com as configuracoes do projeto.
Nao publicar build/theme-review como substituto desse fluxo.
