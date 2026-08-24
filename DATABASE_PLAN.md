# Plano de Banco de Dados - DevStack AI

## Etapa atual

O projeto comecou com uma camada de persistencia local usando `shared_preferences`.

Dados salvos localmente:

- Usuarios cadastrados para prototipo
- Sessao do usuario atual
- IDs dos posts curtidos
- IDs dos posts favoritados
- Historico de busca

Essa camada ja deixa o prototipo mais funcional, porque algumas interacoes do usuario deixam de ser apenas visuais e passam a continuar salvas apos reiniciar o app.

Observacao: o cadastro local e apenas para prototipo. Em producao, login e senha devem ser migrados para Firebase Auth ou Supabase Auth.

## Proxima etapa recomendada

Migrar a camada `LocalDatabaseService` para um banco remoto, como Firebase Firestore ou Supabase.

## Estrutura sugerida para Firebase/Supabase

### users

- id
- name
- email
- phone
- cep
- street
- neighborhood
- city
- state
- number
- complement
- createdAt

### posts

- id
- authorId
- username
- userHandle
- title
- description
- code
- tags
- likesCount
- commentsCount
- createdAt

### post_likes

- id
- postId
- userId
- createdAt

### saved_posts

- id
- postId
- userId
- createdAt

### comments

- id
- postId
- userId
- text
- createdAt

### communities

- id
- name
- description
- membersCount
- icon
- createdAt

### community_members

- id
- communityId
- userId
- createdAt

### ai_chats

- id
- userId
- title
- createdAt
- updatedAt

### ai_messages

- id
- chatId
- text
- isUser
- createdAt

## Ordem de implementacao

1. Separar modelos e telas em arquivos proprios.
2. Criar servico de banco remoto.
3. Migrar cadastro/login local para Firebase Auth ou Supabase Auth.
4. Migrar posts da Home para banco.
5. Persistir curtidas e favoritos por usuario.
6. Persistir comunidades seguidas.
7. Persistir perfil do usuario.
8. Persistir historico de conversa com IA.
