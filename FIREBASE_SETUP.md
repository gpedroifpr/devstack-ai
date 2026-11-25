# Configuração do Firebase

O app já está preparado para usar Firebase Auth e Firestore quando as credenciais estiverem no arquivo `.env`.

Enquanto essas variáveis não forem preenchidas, o app continua usando o cadastro local com `shared_preferences`.

## 1. Criar projeto

1. Acesse o Firebase Console.
2. Crie um projeto para o DevStack AI.
3. Adicione um app Web.
4. Copie os dados do SDK Web.

## 2. Ativar Authentication

1. Entre em Authentication.
2. Abra a aba Sign-in method.
3. Ative Email/Password.

## 3. Ativar Firestore

1. Entre em Firestore Database.
2. Crie o banco em modo de produção.
3. Depois publique as regras do arquivo `firestore.rules`.

## 4. Configurar `.env`

Copie o conteúdo de `.env.example` para `.env` e preencha:

```env
FIREBASE_API_KEY=sua_api_key_web
FIREBASE_APP_ID=seu_app_id_web
FIREBASE_MESSAGING_SENDER_ID=seu_messaging_sender_id
FIREBASE_PROJECT_ID=seu_project_id
FIREBASE_AUTH_DOMAIN=seu_project_id.firebaseapp.com
FIREBASE_STORAGE_BUCKET=seu_project_id.appspot.com
```

## 5. Rodar

```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat run -d chrome
```

## 6. Publicar regras do Firestore

Se tiver o Node.js instalado, instale o Firebase CLI:

```powershell
npm install -g firebase-tools
```

Depois faça login e publique:

```powershell
firebase login
firebase use devstack---ai-app
firebase deploy --only firestore:rules
```

Se não quiser usar terminal:

1. Abra o Firebase Console.
2. Entre em Firestore Database.
3. Abra a aba Regras.
4. Copie o conteúdo do arquivo `firestore.rules`.
5. Clique em Publicar.

## 7. Deploy web no Firebase Hosting

Use o script do projeto para gerar o build com as variáveis do `.env`.
Sem isso, o app publicado pode abrir sem Firebase/Gemini configurados.

1. Gere o build web:

```powershell
.\scripts\build_web_from_env.ps1
```

2. Publique no Firebase Hosting:

```powershell
firebase deploy --only hosting
```

O arquivo `firebase.json` já aponta o Hosting para `build/web`.

Também dá para fazer tudo em um comando:

```powershell
.\scripts\build_web_from_env.ps1 -Deploy
```

## 8. Deploy web no Netlify

O projeto também tem `netlify.toml`. No Netlify, use:

- Build command: o comando configurado no `netlify.toml`, com as variáveis cadastradas no painel do Netlify.
- Publish directory: `build/web`

Se o Netlify não reconhecer Flutter automaticamente, o caminho mais simples é gerar o build no computador e subir a pasta `build/web` manualmente.

## Coleções iniciais

- `users`: perfil básico criado no cadastro.
- `posts`: dúvidas criadas pelo usuário.
- `posts/{postId}/comments`: comentários de cada discussão.
- `users/{uid}/private/ai_chat_history`: histórico da IA por usuário.

Likes, salvos e histórico de busca ainda ficam locais nessa primeira integração.

## Observação importante sobre a chave da IA

No Flutter Web, qualquer variável do `.env` empacotada como asset pode ser vista no navegador. Para apresentação funciona, mas depois restrinja a chave Gemini no Google Cloud ou mova as chamadas da IA para um back-end/Cloud Function.
