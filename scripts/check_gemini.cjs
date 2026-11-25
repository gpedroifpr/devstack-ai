// Sends only a synthetic prompt; never prints the API key or provider error body.
const fs = require('node:fs');
const path = require('node:path');
async function main() {
  const entries = fs.readFileSync(path.join(__dirname, '../.env'), 'utf8')
    .split(/\r?\n/).filter(line => line.trim() && !line.trim().startsWith('#'))
    .map(line => { const index = line.indexOf('='); return index < 0 ? [] : [line.slice(0,index).trim(), line.slice(index+1).trim().replace(/^(['"])(.*)\1$/, '$2')]; });
  const config = Object.fromEntries(entries.filter(entry => entry.length === 2));
  if (!config.GEMINI_API_KEY) throw new Error('Chave ausente; nenhuma chamada realizada.');
  const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', {
    method: 'POST', signal: AbortSignal.timeout(60000),
    headers: {'Content-Type':'application/json','x-goog-api-key':config.GEMINI_API_KEY},
    body: JSON.stringify({contents: [
      {role:'user', parts:[{text:'Minha palavra de teste é AZUL.'}]},
      {role:'model', parts:[{text:'Entendido.'}]},
      {role:'user', parts:[{text:'Qual é minha palavra de teste? Responda apenas com a palavra.'}]},
    ]}),
  });
  console.log(`Gemini HTTP: ${response.status}`);
  if (!response.ok) { process.exitCode=1; return; }
  const data = await response.json();
  const text = (data.candidates?.[0]?.content?.parts || []).filter(p=>!p.thought).map(p=>p.text||'').join('');
  console.log(`Contexto reconhecido: ${text.includes('AZUL') ? 'sim' : 'nao'}`);
  if (!text.includes('AZUL')) process.exitCode=1;
}
main().catch(() => { console.error('Teste não concluído: verifique conexão, configuração e disponibilidade. Nenhuma credencial foi exibida.'); process.exitCode=1; });
