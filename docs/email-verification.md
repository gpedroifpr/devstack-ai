# Confirmacao de e-mail

Esta etapa e opcional: nao bloqueia login, posts, comentarios ou IA.
Nao implementa login com Google. O envio e iniciado pelo usuario no Perfil,
nao automaticamente no cadastro.

## Teste no Firebase real

1. Publique usando `scripts/build_web_from_env.ps1 -Deploy`.
2. Entre com uma conta cujo e-mail voce possa acessar.
3. No Perfil, clique em Enviar confirmacao.
4. Abra o link recebido (confira tambem a pasta de spam).
5. Volte ao Perfil e clique em Ja confirmei.
6. Confira E-mail confirmado. Saia e entre novamente para conferir o estado.
7. Teste uma segunda conta: ela nao deve herdar a confirmacao da primeira.

O status vem de Firebase Auth `User.emailVerified`, depois de `reload()`.
Nao ha campo de verificacao editavel no Firestore e nenhuma regra foi alterada.
O link usa o manipulador padrao de acoes do Firebase. O template pode ser
personalizado no console em Authentication > Templates > Email address verification.

O reenvio tem intervalo de 60 segundos no cliente; limites do Firebase tambem
se aplicam. Isso nao substitui protecao de servidor contra abuso.
Os testes automatizados usam callbacks simulados e nao enviam e-mails reais.

Referencia: https://firebase.google.com/docs/auth/flutter/manage-users
