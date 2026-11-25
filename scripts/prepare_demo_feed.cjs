const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const ids = ['user-1786911032019','user-1787508048555','user-1787580762338','user-1787948747225','user-1788182780681','user-1792500812530','user-1792860078057','user-1793710297760'];
const base = 'https://firestore.googleapis.com/v1/projects/devstack---ai-app/databases/(default)/documents';

async function main() {
  const {configstore} = require(path.join(cli, 'configstore.js'));
  const {getAccessToken} = require(path.join(cli, 'auth.js'));
  const refresh = configstore.get('tokens')?.refresh_token;
  if (!refresh) throw new Error('Execute firebase login antes de continuar.');
  const token = await getAccessToken(refresh, ['https://www.googleapis.com/auth/cloud-platform']);
  async function request(url, body) {
    const response = await fetch(url, {
      method: body ? 'POST' : 'GET',
      headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type':'application/json'},
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) throw new Error(`Firestore HTTP ${response.status}; nenhuma credencial foi registrada.`);
    return response.json();
  }
  const originals = [];
  const children = [];
  for (const id of ids) {
    const doc = await request(`${base}/posts/${id}`);
    originals.push(doc);
    const collectionIds = [];
    let pageToken;
    do {
      const page = await request(`${base}/posts/${id}:listCollectionIds`, {pageSize:100, ...(pageToken ? {pageToken} : {})});
      collectionIds.push(...(page.collectionIds || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    if (collectionIds.some(name => !['likes','comments'].includes(name))) {
      throw new Error('Subcoleção inesperada: revisar antes de excluir.');
    }
    for (const collection of collectionIds) {
      let next;
      do {
        const page = await request(`${base}/posts/${id}/${collection}?pageSize=100${next ? `&pageToken=${encodeURIComponent(next)}` : ''}`);
        children.push(...(page.documents || []));
        next = page.nextPageToken;
      } while (next);
    }
  }
  const backupDir = path.join(root, '.private-backups');
  fs.mkdirSync(backupDir, {recursive:true});
  const backup = path.join(backupDir, `feed-${Date.now()}.json`);
  fs.writeFileSync(backup, JSON.stringify({originals, children}, null, 2), {flag:'wx'});
  console.log(`Backup local: ${backup}. Posts: ${originals.length}; interações: ${children.length}.`);
  if (!process.argv.includes('--apply')) return;
  const owner = originals.find(d => d.name.endsWith('user-1792860078057')).fields.authorId;
  if (!owner?.stringValue) throw new Error('Autor responsável não encontrado.');
  const examples = [
    {id:'demo-banca-flutter', title:'Como adaptar uma tela Flutter para celular e computador?', tags:['Flutter'],
      description:'Conteúdo demonstrativo preparado pela equipe para a banca. Quero exibir os painéis lado a lado em telas largas e empilhados no celular. Estou usando a largura disponível no LayoutBuilder. Como escolher o ponto de mudança e evitar que textos ultrapassem a tela?',
      code:'LayoutBuilder(\n  builder: (context, constraints) {\n    final panels = [resumo(), detalhes()];\n    if (constraints.maxWidth >= 720) {\n      return Row(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: panels.map((p) => Expanded(child: p)).toList(),\n      );\n    }\n    return Column(children: panels);\n  },\n)'},
    {id:'demo-banca-python', title:'Como remover valores duplicados sem perder a ordem em Python?', tags:['Python'],
      description:'Conteúdo demonstrativo preparado pela equipe para a banca. Recebo uma lista de tecnologias e preciso mostrar cada nome apenas uma vez, mantendo a ordem da primeira ocorrência. O exemplo abaixo funciona com strings. Por que dict.fromkeys preserva essa ordem e quais cuidados devo ter com outros tipos de dados?',
      code:'tecnologias = ["Python", "Flutter", "Python", "JavaScript"]\nunicas = list(dict.fromkeys(tecnologias))\nprint(unicas)\n# ["Python", "Flutter", "JavaScript"]'},
    {id:'demo-banca-javascript', title:'Como tratar falhas ao carregar dados com fetch?', tags:['JavaScript'],
      description:'Conteúdo demonstrativo preparado pela equipe para a banca. Quero mostrar uma mensagem útil quando uma API falhar, sem deixar a tela carregando para sempre. Sei que fetch não lança uma exceção automaticamente para todo erro HTTP. Este tratamento cobre erros do servidor e de conexão? Como acrescentar um limite de espera?',
      code:'async function carregarPosts() {\n  try {\n    const resposta = await fetch("/api/posts");\n    if (!resposta.ok) {\n      throw new Error(`Falha HTTP: ${resposta.status}`);\n    }\n    return await resposta.json();\n  } catch (erro) {\n    console.error("Não foi possível carregar os posts", erro);\n    throw erro;\n  }\n}'},
    {id:'demo-banca-ia', title:'Como dar contexto à IA para receber ajuda com um erro?', tags:['AI'],
      description:'Conteúdo demonstrativo preparado pela equipe para a banca. Em vez de perguntar apenas “meu código não funciona”, organizei objetivo, comportamento observado e exemplo mínimo. Como melhorar essa pergunta sem enviar senhas, chaves de API ou dados pessoais?',
      code:'Objetivo: calcular a média de três notas.\nEsperado: resultado 8.\nObservado: resultado 18.\nCódigo Python:\nnotas = [7, 8, 9]\nmedia = notas[0] + notas[1] + notas[2] / 3\nprint(media)\n\nPergunta: como a precedência dos operadores afeta o cálculo?'},
  ];
  const str = value => ({stringValue:value});
  const writes = [...children, ...originals].map(d => ({delete:d.name, currentDocument:{updateTime:d.updateTime}}));
  for (const example of examples) {
    writes.push({update:{name:`projects/devstack---ai-app/databases/(default)/documents/posts/${example.id}`, fields:{
      id:str(example.id), authorId:owner, username:str('Equipe DevStack · Demonstração'), userHandle:str('@devstack'),
      title:str(example.title), description:str(example.description), code:str(example.code),
      tags:{arrayValue:{values:example.tags.map(str)}}, likes:{integerValue:'0'}, comments:{integerValue:'0'},
      isQuestion:{booleanValue:true}, isResolved:{booleanValue:false}, isDemo:{booleanValue:true},
      timeAgo:str('Demonstração'), createdAt:{timestampValue:new Date().toISOString()},
    }}, currentDocument:{exists:false}});
  }
  if (writes.length > 450) throw new Error('Volume inesperado; backup salvo, nenhuma exclusão feita.');
  await request(`${base}:commit`, {writes});
  for (const example of examples) await request(`${base}/posts/${example.id}`);
  console.log('Confirmado: 8 posts de teste removidos, interações associadas removidas e 4 exemplos criados.');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
