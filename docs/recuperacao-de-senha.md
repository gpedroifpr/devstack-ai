# Recuperacao de senha

Na tela de login, use **Esqueci minha senha**. O e-mail digitado no login
ja aparece na janela. O envio usa Firebase Authentication, em portugues,
sem consultar ou alterar documentos de usuarios no Firestore.

A confirmacao nao revela se o endereco possui conta. Se o Firebase nao
estiver configurado, o app mostra indisponibilidade, nunca sucesso falso.

## Teste antes da banca

1. Entre com uma conta de teste que tenha um e-mail acessivel ao grupo.
2. Saia e abra Entrar > Esqueci minha senha.
3. Confira o endereco e envie uma unica vez.
4. Abra o e-mail (confira o spam), siga o link e escolha uma nova senha.
5. Confirme que a nova senha permite entrar e a antiga nao.
6. Teste um e-mail malformado e uma falha de conexao: o campo deve continuar editavel.

O envio real nao foi executado pelos testes automatizados. Eles verificam
validacao, bloqueio durante envio, confirmacao neutra, falha e nova tentativa
em largura de 360 pixels.

## Publicar

Na pasta flutter_application_1, use o script existente com o .env local:

```powershell
.\scripts\build_web_from_env.ps1 -Deploy
```

Esta melhoria nao exige mudancas nas regras do Firestore. O provedor
E-mail/senha do Firebase Authentication precisa continuar habilitado.
