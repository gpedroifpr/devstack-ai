# Revisao da IA e do historico - 17/11/2026

## Alteracoes

- Gemini recebe ate dez pares recentes de perguntas/respostas bem-sucedidas,
  com limite de tamanho. Erros nao sao tratados como respostas do modelo.
- Instrucoes separadas da pergunta; trechos `thought` nao sao exibidos.
- Respostas vazias, bloqueadas, cortadas, HTTP 400/401/403/404/413/429/5xx,
  timeout e falha de rede recebem tratamento explicito.
- Um envio por vez. Retorno apos sair da tela nao executa setState no widget destruido.
- Falha permite recuperar a pergunta e revisar antes de reenviar.
- Firestore e a fonte do historico de contas conectadas: vazio significa vazio,
  sem restaurar cache antigo do navegador e sem esconder falhas de persistencia.
- Escrita transacional com revisao evita sobrescrever silenciosamente alteracoes
  feitas em outra aba desta versao. Conflito exige confirmacao antes de recarregar.
- Limpeza confirmada, bloqueada durante resposta/salvamento e refletida na tela
  apenas apos sucesso no banco. Revisao mantida mesmo com historico vazio.
- Historico limitado a 80 mensagens e aproximadamente 600 KB de JSON em UTF-8.
- Historico abre a pergunta e a resposta; nao reenvia nem substitui o rascunho.
- Visitantes: conversa temporaria em memoria, sem compartilhar historico persistido.
- Anexos mantem nome/tipo no historico. Arquivos binarios nao sao guardados no
  documento Firestore: apos recarregar, e necessario reanexar para nova analise.

## Testes antes da banca

1. Conta A: pergunte "Minha palavra de teste e AZUL" e depois "Qual e minha palavra?".
2. Recarregue e confira pergunta/resposta no historico; repita a segunda pergunta.
3. Conta B: confira que o historico de A nao aparece.
4. Envie uma imagem, confira resposta, recarregue e confira o nome do anexo.
5. Limpe a conversa, recarregue e confirme que ela continua vazia.
6. Em duas abas da mesma conta, carregue a conversa. Altere em uma e tente
   salvar na outra: deve aparecer conflito, sem sobrescrever a primeira aba.
7. Simule falta de internet: nenhuma mensagem de sucesso de sincronizacao deve
   aparecer. Nao feche a aba antes de tentar salvar de novo; mensagens pendentes
   ficam apenas em memoria e podem ser copiadas antes de recarregar.
8. Teste historico longo e teclado aberto em um celular.

## Limites e pendencias

- Uma conversa por conta; nao sao varias sessoes nomeadas independentes.
- Nao ha garantia de disponibilidade ou de exatidao de respostas do Gemini.
- A chave Gemini ainda e usada no cliente web. Mover para backend com
  autenticacao e controle de uso permanece uma pendencia de seguranca.
- Nao foram alteradas regras de seguranca nem dados reais de conversas.
- Testes automatizados usam respostas simuladas; sincronizacao real entre
  navegadores requer o roteiro acima. A verificacao separada check_gemini.cjs
  usa uma unica pergunta sintetica e nunca imprime a chave.

## Publicar

Feche abas com versoes antigas antes de testar conflitos entre abas.
Execute na pasta do aplicativo:

```powershell
.\scripts\build_web_from_env.ps1 -Deploy
```

Nao publique o .env nem compartilhe chaves no chat ou no GitHub.
