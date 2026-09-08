'use strict';

const MAX_SUGESTOES = 25;
const DISTANCIA_MAXIMA = 2;

const el = {
  campo: document.getElementById('campo'),
  limpar: document.getElementById('limpar'),
  barra: document.getElementById('barra'),
  palco: document.getElementById('palco'),
  vazio: document.getElementById('vazio'),
  statusBase: document.getElementById('statusBase'),
  acaso: document.getElementById('acaso'),
  fichas: document.getElementById('fichas'),
  sugestoes: document.getElementById('sugestoes'),
  verbete: document.getElementById('verbete'),
  ajustes: document.getElementById('ajustes'),
  abrirAjustes: document.getElementById('abrirAjustes'),
  fecharAjustes: document.getElementById('fecharAjustes'),
  baixarTudo: document.getElementById('baixarTudo'),
  dadosBase: document.getElementById('dadosBase'),
  painelTexto: document.getElementById('painelTexto'),
  progresso: document.getElementById('progresso'),
  progressoBarra: document.getElementById('progressoBarra'),
  progressoTexto: document.getElementById('progressoTexto'),
  creditos: document.getElementById('creditos'),
};

const estado = {
  meta: null,
  palavras: [],      // grafia original, ordenada por forma normalizada
  chaves: [],        // forma normalizada correspondente
  fatias: new Map(), // chave -> Map(palavra -> verbete)
  pronto: false,
};

/* ------------------------------------------------------------------ texto */

function normalizar(texto) {
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function chaveFatia(palavra) {
  const base = normalizar(palavra).replace(/[^a-z0-9]/g, '');
  if (!base) return '_';
  return base.length > 1 ? base.slice(0, 2) : base + '_';
}

/** Distância de edição com corte antecipado. */
function distancia(a, b, limite) {
  if (Math.abs(a.length - b.length) > limite) return limite + 1;
  let anterior = Array.from({ length: b.length + 1 }, (_, i) => i);
  let atual = new Array(b.length + 1);
  for (let i = 1; i <= a.length; i++) {
    atual[0] = i;
    let menor = i;
    for (let j = 1; j <= b.length; j++) {
      const custo = a[i - 1] === b[j - 1] ? 0 : 1;
      atual[j] = Math.min(atual[j - 1] + 1, anterior[j] + 1, anterior[j - 1] + custo);
      if (atual[j] < menor) menor = atual[j];
    }
    if (menor > limite) return limite + 1;
    [anterior, atual] = [atual, anterior];
  }
  return anterior[b.length];
}

/** Primeiro índice cuja chave é >= alvo. */
function primeiroIndice(alvo) {
  let baixo = 0;
  let alto = estado.chaves.length;
  while (baixo < alto) {
    const meio = (baixo + alto) >> 1;
    if (estado.chaves[meio] < alvo) baixo = meio + 1;
    else alto = meio;
  }
  return baixo;
}

/* ------------------------------------------------------------------ busca */

function procurar(consulta) {
  const alvo = normalizar(consulta);
  if (!alvo) return { exata: null, lista: [] };

  const vistos = new Set();
  const lista = [];
  let exata = null;

  let i = primeiroIndice(alvo);
  while (i < estado.chaves.length && estado.chaves[i].startsWith(alvo)) {
    const palavra = estado.palavras[i];
    if (estado.chaves[i] === alvo && !exata) exata = palavra;
    if (!vistos.has(palavra)) {
      vistos.add(palavra);
      lista.push(palavra);
    }
    if (lista.length >= MAX_SUGESTOES) break;
    i++;
  }

  if (lista.length < 6 && alvo.length >= 3) {
    // Varre apenas os blocos alfabéticos plausíveis: a inicial digitada e a
    // segunda letra (cobre troca e transposição no começo da palavra).
    const iniciais = new Set([alvo[0], alvo[1]]);
    const aproximadas = [];
    for (const inicial of iniciais) {
      const comeco = primeiroIndice(inicial);
      for (let j = comeco; j < estado.chaves.length; j++) {
        const chave = estado.chaves[j];
        if (chave[0] !== inicial) break;
        if (Math.abs(chave.length - alvo.length) > DISTANCIA_MAXIMA) continue;
        const d = distancia(alvo, chave, DISTANCIA_MAXIMA);
        if (d <= DISTANCIA_MAXIMA && !vistos.has(estado.palavras[j])) {
          aproximadas.push([d, estado.palavras[j]]);
        }
      }
    }
    aproximadas.sort((a, b) => a[0] - b[0] || a[1].localeCompare(b[1], 'pt'));
    for (const [, palavra] of aproximadas.slice(0, MAX_SUGESTOES - lista.length)) {
      vistos.add(palavra);
      lista.push(palavra);
    }
  }

  return { exata, lista };
}

/* ------------------------------------------------------------------ dados */

async function carregarFatia(chave) {
  if (estado.fatias.has(chave)) return estado.fatias.get(chave);
  const resposta = await fetch(`./data/verbetes/${chave}.json`);
  if (!resposta.ok) throw new Error(`fatia ${chave} indisponível`);
  const registros = await resposta.json();
  const mapa = new Map(registros.map((r) => [r.w, r]));
  estado.fatias.set(chave, mapa);
  return mapa;
}

async function obterVerbete(palavra) {
  const mapa = await carregarFatia(chaveFatia(palavra));
  return mapa.get(palavra) || null;
}

/* ------------------------------------------------------------- renderizar */

function mostrar(qual) {
  el.vazio.hidden = qual !== 'vazio';
  el.sugestoes.hidden = qual !== 'sugestoes';
  el.verbete.hidden = qual !== 'verbete';
}

function marcarPrefixo(palavra, consulta) {
  const n = normalizar(consulta).length;
  if (!n || normalizar(palavra).slice(0, n) !== normalizar(consulta)) {
    return document.createTextNode(palavra);
  }
  const fragmento = document.createDocumentFragment();
  const forte = document.createElement('b');
  forte.textContent = palavra.slice(0, n);
  fragmento.append(forte, document.createTextNode(palavra.slice(n)));
  return fragmento;
}

function renderizarSugestoes(lista, consulta) {
  el.sugestoes.replaceChildren();
  if (!lista.length) {
    const aviso = document.createElement('li');
    aviso.className = 'sugestao-aviso';
    aviso.textContent = `Nada encontrado para “${consulta}”.`;
    el.sugestoes.append(aviso);
    mostrar('sugestoes');
    return;
  }
  for (const palavra of lista) {
    const item = document.createElement('li');
    item.className = 'sugestao';
    item.tabIndex = 0;
    item.dataset.palavra = palavra;
    const grafia = document.createElement('span');
    grafia.className = 'sugestao-palavra';
    grafia.append(marcarPrefixo(palavra, consulta));
    item.append(grafia);
    el.sugestoes.append(item);
  }
  mostrar('sugestoes');
}

function renderizarVerbete(registro, origem) {
  el.verbete.replaceChildren();

  if (origem) {
    const nota = document.createElement('p');
    nota.className = 'remissao';
    nota.textContent = `${origem} é forma de`;
    el.verbete.append(nota);
  }

  const cabeca = document.createElement('h2');
  cabeca.className = 'cabeca';
  cabeca.textContent = registro.w;
  el.verbete.append(cabeca);

  if (registro.f) {
    const fonetica = document.createElement('p');
    fonetica.className = 'fonetica';
    fonetica.textContent = registro.f;
    el.verbete.append(fonetica);
  }

  for (const bloco of registro.c || []) {
    const secao = document.createElement('section');
    secao.className = 'bloco';
    if (bloco.g) {
      const classe = document.createElement('p');
      classe.className = 'classe';
      classe.textContent = bloco.g;
      secao.append(classe);
    }
    const lista = document.createElement('ol');
    lista.className = 'acepcoes';
    for (const definicao of bloco.d || []) {
      const item = document.createElement('li');
      item.textContent = definicao;
      lista.append(item);
    }
    secao.append(lista);
    el.verbete.append(secao);
  }

  if (registro.x) {
    const exemplo = document.createElement('p');
    exemplo.className = 'exemplo';
    exemplo.textContent = registro.x;
    el.verbete.append(exemplo);
  }

  for (const [campo, rotulo] of [['s', 'Sinônimos'], ['a', 'Antônimos']]) {
    const palavras = registro[campo];
    if (!palavras || !palavras.length) continue;
    const secao = document.createElement('section');
    secao.className = 'relacionadas';
    const titulo = document.createElement('p');
    titulo.className = 'relacionadas-titulo';
    titulo.textContent = rotulo;
    const fichas = document.createElement('div');
    fichas.className = 'fichas';
    for (const palavra of palavras) {
      const ficha = document.createElement('button');
      ficha.className = 'ficha';
      ficha.type = 'button';
      ficha.textContent = palavra;
      fichas.append(ficha);
    }
    secao.append(titulo, fichas);
    el.verbete.append(secao);
  }

  if (registro.e) {
    const etm = document.createElement('p');
    etm.className = 'etimologia';
    etm.textContent = registro.e;
    el.verbete.append(etm);
  }

  const rodape = document.createElement('p');
  rodape.className = 'rodape-verbete';
  rodape.textContent = estado.meta?.fonte || '';
  el.verbete.append(rodape);

  mostrar('verbete');
  window.scrollTo({ top: 0 });
}

async function abrirPalavra(palavra, origem) {
  try {
    const registro = await obterVerbete(palavra);
    if (!registro) {
      renderizarSugestoes([], palavra);
    } else if (registro.r && !origem) {
      await abrirPalavra(registro.r, palavra);
    } else {
      renderizarVerbete(registro, origem);
    }
  } catch (erro) {
    el.verbete.replaceChildren();
    const aviso = document.createElement('p');
    aviso.className = 'dica';
    aviso.textContent = 'Esta parte do léxico ainda não está no aparelho. Conecte-se à rede ou baixe a base completa em “Base”.';
    el.verbete.append(aviso);
    mostrar('verbete');
  }
}

/* ------------------------------------------------------------- interação */

let temporizador = null;

function aoDigitar() {
  const consulta = el.campo.value;
  el.limpar.hidden = consulta.length === 0;
  clearTimeout(temporizador);
  temporizador = setTimeout(() => {
    if (!consulta.trim()) {
      mostrar('vazio');
      return;
    }
    if (!estado.pronto) return;
    const { lista } = procurar(consulta);
    renderizarSugestoes(lista, consulta.trim());
  }, 60);
}

el.campo.addEventListener('input', aoDigitar);

el.barra.addEventListener('submit', async (evento) => {
  evento.preventDefault();
  const consulta = el.campo.value.trim();
  if (!consulta || !estado.pronto) return;
  const { exata, lista } = procurar(consulta);
  const escolha = exata || lista[0];
  if (escolha) {
    el.campo.blur();
    await abrirPalavra(escolha);
  } else {
    renderizarSugestoes([], consulta);
  }
});

el.limpar.addEventListener('click', () => {
  el.campo.value = '';
  el.limpar.hidden = true;
  mostrar('vazio');
  el.campo.focus();
});

el.sugestoes.addEventListener('click', (evento) => {
  const item = evento.target.closest('.sugestao');
  if (item) abrirPalavra(item.dataset.palavra);
});

el.sugestoes.addEventListener('keydown', (evento) => {
  if (evento.key !== 'Enter') return;
  const item = evento.target.closest('.sugestao');
  if (item) abrirPalavra(item.dataset.palavra);
});

function aoTocarFicha(evento) {
  const ficha = evento.target.closest('.ficha');
  if (!ficha) return;
  el.campo.value = ficha.textContent;
  el.limpar.hidden = false;
  abrirPalavra(ficha.textContent);
}

el.fichas.addEventListener('click', aoTocarFicha);
el.verbete.addEventListener('click', aoTocarFicha);

/* --------------------------------------------------------------- ajustes */

function formatarBytes(bytes) {
  if (!bytes) return '—';
  const mb = bytes / 1048576;
  return mb >= 1 ? `${mb.toFixed(1)} MB` : `${Math.round(bytes / 1024)} kB`;
}

function preencherPainel() {
  const meta = estado.meta;
  el.dadosBase.replaceChildren();
  const cob = meta?.cobertura;
  const pct = (v) => (typeof v === 'number' ? `${v}%` : '—');
  const linhas = [
    ['Lemas', (meta?.lemas || meta?.verbetes || 0).toLocaleString('pt-BR')],
    ['Formas flexionadas', (meta?.remissoes || 0).toLocaleString('pt-BR')],
    ['Tamanho', formatarBytes(meta?.bytes_verbetes)],
    ['Pronúncia', pct(cob?.f)],
    ['Etimologia', pct(cob?.e)],
    ['Sinônimos', pct(cob?.s)],
    ['Antônimos', pct(cob?.a)],
    ['Exemplos', pct(cob?.x)],
    ['Versão', meta?.versao || '—'],
  ];
  for (const [rotulo, valor] of linhas) {
    const dt = document.createElement('dt');
    dt.textContent = rotulo;
    const dd = document.createElement('dd');
    dd.textContent = valor;
    el.dadosBase.append(dt, dd);
  }
  el.creditos.textContent = `${meta?.fonte || ''}${meta?.licenca ? ' · ' + meta.licenca : ''}`;
  if (meta?.amostra) {
    el.painelTexto.textContent =
      'Você está com a amostra de demonstração. Rode etl/construir_lexico.py para gerar o léxico completo do Wikcionário.';
  }
}

el.abrirAjustes.addEventListener('click', () => {
  preencherPainel();
  el.ajustes.showModal();
});

el.fecharAjustes.addEventListener('click', () => el.ajustes.close());

el.baixarTudo.addEventListener('click', async () => {
  const fatias = estado.meta?.fatias || [];
  if (!fatias.length) return;
  el.baixarTudo.disabled = true;
  el.progresso.hidden = false;
  let feitas = 0;
  let falhas = 0;

  for (const chave of fatias) {
    try {
      await fetch(`./data/verbetes/${chave}.json`, { cache: 'reload' });
    } catch {
      falhas++;
    }
    feitas++;
    const pct = Math.round((feitas / fatias.length) * 100);
    el.progressoBarra.style.width = `${pct}%`;
    el.progressoTexto.textContent = `${feitas} de ${fatias.length} fatias · ${pct}%`;
  }

  el.progressoTexto.textContent = falhas
    ? `Concluído com ${falhas} falha(s). Repita com rede estável.`
    : 'Base completa disponível offline.';
  el.baixarTudo.disabled = false;
});

/* ----------------------------------------------------------------- início */

function sortear(quantidade) {
  const escolhidas = new Set();
  while (escolhidas.size < Math.min(quantidade, estado.palavras.length)) {
    escolhidas.add(estado.palavras[Math.floor(Math.random() * estado.palavras.length)]);
  }
  return [...escolhidas];
}

async function iniciar() {
  try {
    const [meta, indice] = await Promise.all([
      fetch('./data/meta.json').then((r) => r.json()),
      fetch('./data/indice.json').then((r) => r.json()),
    ]);
    estado.meta = meta;
    estado.palavras = indice;
    estado.chaves = indice.map(normalizar);
    estado.pronto = true;

    el.statusBase.textContent =
      `${meta.verbetes.toLocaleString('pt-BR')} verbetes no aparelho.` +
      (meta.amostra ? ' Amostra de demonstração.' : '');

    const fichas = sortear(6);
    el.fichas.replaceChildren();
    for (const palavra of fichas) {
      const ficha = document.createElement('button');
      ficha.className = 'ficha';
      ficha.type = 'button';
      ficha.textContent = palavra;
      el.fichas.append(ficha);
    }
    el.acaso.hidden = false;
  } catch (erro) {
    el.statusBase.textContent =
      'Não foi possível carregar o léxico. Conecte-se à rede uma vez para instalar a base.';
  }
}

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}

iniciar();
