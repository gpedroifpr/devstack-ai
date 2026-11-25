# Login Google na web

## Ativar antes de publicar

1. No Firebase, abra o projeto devstack---ai-app.
2. Authentication > Sign-in method (Metodo de login) > Adicionar provedor > Google.
3. Habilite o provedor, selecione o e-mail de suporte do projeto e salve.
4. Em Authentication > Settings > Authorized domains, confira:
   devstack---ai-app.web.app e devstack---ai-app.firebaseapp.com.
5. Para testes locais, adicione localhost e/ou 127.0.0.1 conforme o endereco usado.
6. Publique com `.\scripts\build_web_from_env.ps1 -Deploy`.

Nao e necessario alterar as regras do Firestore nem enviar uma senha Google
ao aplicativo. A autenticacao acontece na janela oficial do Google.

## Validacao manual obrigatoria

- Abra Entrar ou Criar conta, clique Continuar com Google e escolha uma conta.
- Confira o novo usuario no Firebase Authentication e seu documento users/UID.
- Recarregue e confirme que o login e os dados continuam disponiveis.
- Edite o nome/foto no perfil, saia e entre com Google: os dados devem permanecer.
- Feche a janela Google sem entrar e confira se pode tentar novamente.
- Teste no celular pelo navegador e no computador.
- Se houver conflito com outro metodo de login, use o metodo original. Nao
  criamos uma segunda conta nem vinculamos contas por conta propria.

Esta implementacao usa signInWithPopup para a web. APK Android requer
configuracao e implementacao nativas separadas. A foto Google nao e importada
automaticamente; a troca de foto do DevStack continua disponivel.

Referencia: https://firebase.google.com/docs/auth/flutter/federated-auth
