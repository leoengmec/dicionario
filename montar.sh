#!/usr/bin/env bash
# Monta o projeto do dicionario e o lexico. Roda dentro do GitHub Actions
# ou em qualquer terminal. NAO escreve nada em .github/ de proposito:
# o token do Actions nao tem permissao para criar workflows.
set -euo pipefail

echo "==> escrevendo os arquivos do projeto"
mkdir -p etl icones
touch .nojekyll

cat > index.html <<'FIMDOARQUIVO'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#E9EAE4" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#12191B" media="(prefers-color-scheme: dark)">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="Dicionário">
<meta name="description" content="Dicionário de português para consulta rápida, com funcionamento offline.">
<title>Dicionário</title>
<link rel="manifest" href="./manifest.webmanifest">
<link rel="apple-touch-icon" href="./icones/icone-180.png">
<link rel="icon" href="./icones/icone.svg" type="image/svg+xml">
<link rel="stylesheet" href="./estilo.css">
</head>
<body>

<header class="topo">
  <h1 class="marca">Dicionário</h1>
  <button class="botao-menu" id="abrirAjustes" aria-label="Ajustes e base offline">Base</button>
</header>

<main class="palco" id="palco" tabindex="-1">
  <section class="vazio" id="vazio">
    <p class="convite">Procure uma palavra.</p>
    <p class="dica" id="statusBase">Carregando o léxico…</p>
    <div class="acaso" id="acaso" hidden>
      <p class="acaso-titulo">Ao acaso</p>
      <div class="fichas" id="fichas"></div>
    </div>
  </section>

  <ol class="sugestoes" id="sugestoes" hidden></ol>

  <article class="verbete" id="verbete" hidden></article>
</main>

<form class="barra" id="barra" role="search" autocomplete="off">
  <input class="campo" id="campo" type="search" name="q" enterkeyhint="search"
         placeholder="palavra" aria-label="Palavra a procurar"
         autocapitalize="none" autocorrect="off" spellcheck="false">
  <button class="limpar" id="limpar" type="button" aria-label="Limpar" hidden>×</button>
</form>

<dialog class="painel" id="ajustes">
  <h2 class="painel-titulo">Base offline</h2>
  <dl class="dados" id="dadosBase"></dl>
  <p class="painel-texto" id="painelTexto">
    Baixe todas as fatias para consultar sem rede. O download acontece uma vez e fica guardado no aparelho.
  </p>
  <div class="progresso" id="progresso" hidden>
    <div class="progresso-trilho"><div class="progresso-barra" id="progressoBarra"></div></div>
    <p class="progresso-texto" id="progressoTexto"></p>
  </div>
  <div class="painel-acoes">
    <button class="botao" id="baixarTudo" type="button">Baixar tudo</button>
    <button class="botao botao-fraco" id="fecharAjustes" type="button">Fechar</button>
  </div>
  <p class="creditos" id="creditos"></p>
</dialog>

<script src="./app.js"></script>
</body>
</html>

FIMDOARQUIVO

cat > estilo.css <<'FIMDOARQUIVO'
:root {
  --papel: #E9EAE4;
  --papel-alto: #F3F4EF;
  --tinta: #18262A;
  --tinta-fraca: #5F6E72;
  --tinta-tenue: #8E999C;
  --realce: #2F5D50;
  --realce-fundo: #D8E3DD;
  --linha: #CDD1C9;
  --serifa: ui-serif, "New York", "Iowan Old Style", Georgia, "Times New Roman", serif;
  --sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, "Segoe UI", sans-serif;
  --barra-altura: 4.25rem;
}

@media (prefers-color-scheme: dark) {
  :root {
    --papel: #12191B;
    --papel-alto: #1B2426;
    --tinta: #E3E7E3;
    --tinta-fraca: #97A5A6;
    --tinta-tenue: #6C7A7C;
    --realce: #86BCA8;
    --realce-fundo: #23342F;
    --linha: #2A3538;
  }
}

* { box-sizing: border-box; }

html {
  -webkit-text-size-adjust: 100%;
  background: var(--papel);
}

body {
  margin: 0;
  min-height: 100svh;
  background: var(--papel);
  color: var(--tinta);
  font-family: var(--sans);
  font-size: 17px;
  line-height: 1.5;
  padding-bottom: calc(var(--barra-altura) + env(safe-area-inset-bottom));
  overscroll-behavior-y: contain;
}

/* ---- topo ---- */

.topo {
  position: sticky;
  top: 0;
  z-index: 5;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  padding: calc(env(safe-area-inset-top) + 0.9rem) 1.15rem 0.7rem;
  background: var(--papel);
  border-bottom: 1px solid var(--linha);
}

.marca {
  margin: 0;
  font-family: var(--serifa);
  font-size: 1.0625rem;
  font-weight: 500;
  letter-spacing: 0.01em;
}

.botao-menu {
  border: 1px solid var(--linha);
  border-radius: 999px;
  background: transparent;
  color: var(--tinta-fraca);
  font: inherit;
  font-size: 0.8125rem;
  padding: 0.2rem 0.75rem;
  cursor: pointer;
}

.botao-menu:hover { color: var(--tinta); }

/* ---- palco ---- */

.palco {
  padding: 0 1.15rem 2rem;
  max-width: 42rem;
  margin: 0 auto;
  outline: none;
}

/* ---- estado vazio ---- */

.vazio { padding-top: 3.5rem; }

.convite {
  font-family: var(--serifa);
  font-size: 1.5rem;
  margin: 0 0 0.35rem;
}

.dica {
  margin: 0;
  color: var(--tinta-fraca);
  font-size: 0.9375rem;
}

.acaso { margin-top: 2.75rem; }

.acaso-titulo {
  margin: 0 0 0.7rem;
  font-size: 0.8125rem;
  color: var(--tinta-tenue);
}

.fichas {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.ficha {
  font-family: var(--serifa);
  font-size: 1rem;
  border: 1px solid var(--linha);
  border-radius: 2px;
  background: var(--papel-alto);
  color: var(--tinta);
  padding: 0.3rem 0.7rem;
  cursor: pointer;
}

.ficha:hover { border-color: var(--realce); color: var(--realce); }

/* ---- sugestões ---- */

.sugestoes {
  list-style: none;
  margin: 0;
  padding: 0.4rem 0 0;
}

.sugestao {
  display: flex;
  align-items: baseline;
  gap: 0.55rem;
  padding: 0.7rem 0;
  border-bottom: 1px solid var(--linha);
  cursor: pointer;
}

.sugestao-palavra {
  font-family: var(--serifa);
  font-size: 1.1875rem;
}

.sugestao-palavra b {
  font-weight: 600;
  color: var(--realce);
  background: var(--realce-fundo);
}

.sugestao-classe {
  font-family: var(--serifa);
  font-style: italic;
  font-size: 0.875rem;
  color: var(--tinta-tenue);
}

.sugestao-aviso {
  padding: 1.5rem 0;
  color: var(--tinta-fraca);
  font-size: 0.9375rem;
}

/* ---- verbete ---- */

.verbete { padding-top: 1.4rem; }

.cabeca {
  font-family: var(--serifa);
  font-size: 2.375rem;
  line-height: 1.12;
  font-weight: 500;
  margin: 0;
  letter-spacing: -0.012em;
}

.fonetica {
  font-family: var(--serifa);
  color: var(--tinta-fraca);
  font-size: 1rem;
  margin: 0.3rem 0 0;
}

.bloco { margin-top: 1.6rem; }

.classe {
  font-family: var(--serifa);
  font-style: italic;
  font-size: 1rem;
  color: var(--realce);
  margin: 0 0 0.5rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--linha);
}

.acepcoes {
  font-family: var(--serifa);
  margin: 0;
  padding-left: 1.35rem;
  font-size: 1.0625rem;
  line-height: 1.62;
}

.acepcoes li { margin-bottom: 0.4rem; }
.acepcoes li::marker { color: var(--tinta-tenue); font-size: 0.85em; }

.etimologia {
  margin-top: 1.8rem;
  padding-top: 0.9rem;
  border-top: 1px solid var(--linha);
  font-family: var(--serifa);
  font-size: 0.9375rem;
  color: var(--tinta-fraca);
}

.rodape-verbete {
  margin-top: 2rem;
  font-size: 0.8125rem;
  color: var(--tinta-tenue);
}

.rodape-verbete a { color: inherit; }

/* ---- barra de busca fixa no alcance do polegar ---- */

.barra {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.7rem 1.15rem calc(0.7rem + env(safe-area-inset-bottom));
  background: var(--papel);
  border-top: 1px solid var(--linha);
}

.campo {
  flex: 1;
  min-width: 0;
  font-family: var(--serifa);
  font-size: 1.25rem;
  color: var(--tinta);
  background: var(--papel-alto);
  border: 1px solid var(--linha);
  border-radius: 3px;
  padding: 0.6rem 0.8rem;
  appearance: none;
  -webkit-appearance: none;
}

.campo::placeholder { color: var(--tinta-tenue); font-style: italic; }

.campo:focus {
  outline: 2px solid var(--realce);
  outline-offset: -1px;
  border-color: var(--realce);
}

.campo::-webkit-search-decoration,
.campo::-webkit-search-cancel-button { -webkit-appearance: none; }

.limpar {
  border: none;
  background: transparent;
  color: var(--tinta-fraca);
  font-size: 1.6rem;
  line-height: 1;
  padding: 0 0.35rem;
  cursor: pointer;
}

/* ---- painel ---- */

.painel {
  border: 1px solid var(--linha);
  border-radius: 4px;
  background: var(--papel-alto);
  color: var(--tinta);
  padding: 1.4rem;
  width: min(24rem, calc(100vw - 2.5rem));
  font-family: var(--sans);
}

.painel::backdrop { background: rgba(10, 20, 22, 0.45); }

.painel-titulo {
  font-family: var(--serifa);
  font-size: 1.25rem;
  font-weight: 500;
  margin: 0 0 0.9rem;
}

.dados {
  margin: 0 0 1rem;
  font-size: 0.9375rem;
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.25rem 1rem;
}

.dados dt { color: var(--tinta-fraca); }
.dados dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; }

.painel-texto {
  margin: 0 0 1.1rem;
  font-size: 0.875rem;
  color: var(--tinta-fraca);
  line-height: 1.5;
}

.progresso { margin-bottom: 1.1rem; }

.progresso-trilho {
  height: 3px;
  background: var(--linha);
  border-radius: 2px;
  overflow: hidden;
}

.progresso-barra {
  height: 100%;
  width: 0;
  background: var(--realce);
  transition: width 0.2s linear;
}

.progresso-texto {
  margin: 0.45rem 0 0;
  font-size: 0.8125rem;
  color: var(--tinta-fraca);
  font-variant-numeric: tabular-nums;
}

.painel-acoes { display: flex; gap: 0.5rem; }

.botao {
  flex: 1;
  font: inherit;
  font-size: 0.9375rem;
  padding: 0.6rem 0.9rem;
  border: 1px solid var(--realce);
  border-radius: 3px;
  background: var(--realce);
  color: var(--papel-alto);
  cursor: pointer;
}

.botao[disabled] { opacity: 0.45; cursor: default; }

.botao-fraco {
  background: transparent;
  color: var(--tinta-fraca);
  border-color: var(--linha);
}

.creditos {
  margin: 1.1rem 0 0;
  font-size: 0.75rem;
  line-height: 1.5;
  color: var(--tinta-tenue);
}

.creditos a { color: inherit; }

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}

FIMDOARQUIVO

cat > app.js <<'FIMDOARQUIVO'
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

function renderizarVerbete(registro) {
  el.verbete.replaceChildren();

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

async function abrirPalavra(palavra) {
  try {
    const registro = await obterVerbete(palavra);
    if (registro) renderizarVerbete(registro);
    else renderizarSugestoes([], palavra);
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

el.fichas.addEventListener('click', (evento) => {
  const ficha = evento.target.closest('.ficha');
  if (!ficha) return;
  el.campo.value = ficha.textContent;
  el.limpar.hidden = false;
  abrirPalavra(ficha.textContent);
});

/* --------------------------------------------------------------- ajustes */

function formatarBytes(bytes) {
  if (!bytes) return '—';
  const mb = bytes / 1048576;
  return mb >= 1 ? `${mb.toFixed(1)} MB` : `${Math.round(bytes / 1024)} kB`;
}

function preencherPainel() {
  const meta = estado.meta;
  el.dadosBase.replaceChildren();
  const linhas = [
    ['Verbetes', (meta?.verbetes || 0).toLocaleString('pt-BR')],
    ['Fatias', String(meta?.fatias?.length || 0)],
    ['Tamanho', formatarBytes(meta?.bytes_verbetes)],
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

FIMDOARQUIVO

cat > sw.js <<'FIMDOARQUIVO'
/* Dicionário — service worker
   Casca e índice ficam pré-carregados; as fatias de verbetes entram no cache
   na primeira consulta ou de uma vez pelo botão "Baixar tudo". */

const VERSAO = 'dicionario-v1';
const CASCA = [
  './',
  './index.html',
  './estilo.css',
  './app.js',
  './manifest.webmanifest',
  './icones/icone.svg',
  './icones/icone-180.png',
  './icones/icone-192.png',
  './icones/icone-512.png',
  './data/meta.json',
  './data/indice.json',
];

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    caches.open(VERSAO).then((cache) => cache.addAll(CASCA)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    caches.keys()
      .then((chaves) => Promise.all(chaves.filter((c) => c !== VERSAO).map((c) => caches.delete(c))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (evento) => {
  const requisicao = evento.request;
  if (requisicao.method !== 'GET') return;

  const url = new URL(requisicao.url);
  if (url.origin !== self.location.origin) return;

  // Navegação: casca primeiro, para abrir instantaneamente sem rede.
  if (requisicao.mode === 'navigate') {
    evento.respondWith(
      caches.match('./index.html').then((resposta) => resposta || fetch(requisicao))
    );
    return;
  }

  // Fatias de verbetes e demais estáticos: cache primeiro, rede como reserva.
  evento.respondWith(
    caches.match(requisicao).then((emCache) => {
      if (emCache && requisicao.cache !== 'reload') return emCache;
      return fetch(requisicao)
        .then((resposta) => {
          if (resposta.ok) {
            const copia = resposta.clone();
            caches.open(VERSAO).then((cache) => cache.put(requisicao, copia));
          }
          return resposta;
        })
        .catch(() => emCache || Response.error());
    })
  );
});

FIMDOARQUIVO

cat > manifest.webmanifest <<'FIMDOARQUIVO'
{
  "name": "Dicionário",
  "short_name": "Dicionário",
  "description": "Dicionário de português para consulta rápida, com funcionamento offline.",
  "lang": "pt-BR",
  "dir": "ltr",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#E9EAE4",
  "theme_color": "#E9EAE4",
  "categories": ["education", "books", "utilities"],
  "icons": [
    { "src": "./icones/icone.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any" },
    { "src": "./icones/icone-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "./icones/icone-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "./icones/icone-512-mascara.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}

FIMDOARQUIVO

cat > README.md <<'FIMDOARQUIVO'
# Dicionário

Dicionário de português para consulta rápida no iPhone. PWA instalada na tela de
início, funciona sem rede, busca por prefixo, sem acento e com correção de digitação.

Léxico: Wikcionário em português, extraído por
[kaikki.org](https://kaikki.org/ptwiktionary/) com o wiktextract (CC BY-SA).
Você não baixa nem processa nada: o GitHub Actions monta a base na nuvem.

## Como funciona

```
Actions -> "Instalar o projeto" -> bash montar.sh
      escreve os arquivos, baixa o dump, monta data/, commita e faz push
GitHub Pages (Deploy from a branch: main / root) publica o repositório
```

O léxico é reconstruído só quando `data/` está vazio ou só tem a amostra. Para
forçar uma reconstrução com extração mais nova, apague a pasta `data/` e rode o
workflow de novo.

## Instalar no iPhone

1. Abra o endereço do Pages no **Safari** (só o Safari instala PWA no iOS).
2. Compartilhar → **Adicionar à Tela de Início**.
3. Abra pelo ícone, toque em **Base** → **Baixar tudo**.
4. Teste em modo avião.

## Arquivos

```
index.html            casca
estilo.css            paleta, tipografia
app.js                busca, navegação, painel da base
sw.js                 service worker
manifest.webmanifest  ícone, nome, modo standalone
montar.sh             escreve o projeto e monta o léxico
etl/localizar_dump.py descobre a URL do dump no kaikki
etl/construir_lexico.py  dump -> data/indice.json + data/verbetes/*.json
etl/gerar_amostra.py  65 verbetes de demonstração, reserva se o dump falhar
```

## Decisões

- **Sem build.** Arquivos estáticos servidos direto. Nada de npm ou bundler.
- **Um workflow só.** O token do Actions não pode criar arquivos em
  `.github/workflows/`, então nada de segundo workflow gerado por script.
- **Pages a partir do branch.** Dispensa o pipeline de artefato e mantém o
  léxico versionado junto com o app.
- **Busca no rodapé.** Alcance do polegar; o resultado ocupa a tela toda.
- **Léxico fatiado por duas letras.** Carrega sob demanda e respeita o limite de
  100 MB por arquivo do GitHub.
- **Tipografia nativa.** Serifa do sistema (New York no iOS) para o conteúdo,
  sans para a interface. Nenhuma fonte baixada.

## Escopo da v1.0

Busca e offline. Fora desta versão: favoritos, histórico, notas, sinônimos.

FIMDOARQUIVO

cat > .gitignore <<'FIMDOARQUIVO'
node_modules/
*.jsonl
*.jsonl.gz
.DS_Store

FIMDOARQUIVO

cat > etl/localizar_dump.py <<'FIMDOARQUIVO'
#!/usr/bin/env python3
"""
Descobre a URL do dump do Wikcionário-PT em kaikki.org e a imprime.

O nome do arquivo muda a cada extração, então a página de índice é lida e os
links .jsonl são pontuados. Prefere o recorte só de português (bem menor) ao
dump bruto com todos os idiomas.

    URL=$(python3 etl/localizar_dump.py)
"""

import re
import sys
import urllib.error
import urllib.request

BASE = "https://kaikki.org/ptwiktionary/"
AGENTE = {"User-Agent": "dicionario-pwa/1.0 (construcao de lexico offline)"}

CANDIDATOS_FIXOS = [
    "https://kaikki.org/ptwiktionary/Portuguese/kaikki.org-dictionary-Portuguese.jsonl",
    "https://kaikki.org/ptwiktionary/raw-wiktextract-data.jsonl.gz",
    "https://kaikki.org/ptwiktionary/raw-wiktextract-data.json.gz",
]


def buscar(url, timeout=60):
    req = urllib.request.Request(url, headers=AGENTE)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def existe(url):
    req = urllib.request.Request(url, headers=AGENTE, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status == 200
    except (urllib.error.URLError, urllib.error.HTTPError, OSError):
        return False


def pontuar(href):
    """Maior é melhor."""
    p = 0
    baixo = href.lower()
    if "portuguese" in baixo:
        p += 100          # recorte só de português: menor e já filtrado
    if "raw-wiktextract" in baixo:
        p += 50
    if baixo.endswith(".gz"):
        p += 5            # comprimido baixa mais rápido
    if "non-disambiguated" in baixo:
        p -= 30
    return p


def main() -> int:
    achados = []
    try:
        html = buscar(BASE)
        for href in re.findall(r'href="([^"]+)"', html):
            if not re.search(r"\.jsonl?(\.gz)?$", href, re.I):
                continue
            if href.startswith("http"):
                url = href
            elif href.startswith("/"):
                url = "https://kaikki.org" + href
            else:
                url = BASE + href.lstrip("./")
            achados.append(url)
    except Exception as erro:  # noqa: BLE001
        print(f"aviso: não consegui ler {BASE} ({erro})", file=sys.stderr)

    achados = sorted(set(achados), key=pontuar, reverse=True)

    for url in achados:
        print(f"candidato: {url}", file=sys.stderr)
        if existe(url):
            print(url)
            return 0

    print("nenhum link na página; tentando nomes conhecidos", file=sys.stderr)
    for url in CANDIDATOS_FIXOS:
        if existe(url):
            print(url)
            return 0

    print(
        "Não localizei o dump. Abra https://kaikki.org/ptwiktionary/ , copie a URL\n"
        "do arquivo .jsonl e passe direto:\n"
        "  python3 etl/construir_lexico.py --entrada <arquivo baixado>",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

FIMDOARQUIVO

cat > etl/construir_lexico.py <<'FIMDOARQUIVO'
#!/usr/bin/env python3
"""
Constrói o léxico offline do app a partir da extração do Wikcionário-PT
publicada por kaikki.org (formato JSONL, produzido pelo wiktextract).

Entrada esperada:
    https://kaikki.org/ptwiktionary/  ->  arquivo .jsonl ou .jsonl.gz

Saída (dentro de ../data):
    indice.json          lista de todas as entradas (para busca e sugestões)
    meta.json            versão, contagens e lista de fatias
    verbetes/<xx>.json   fatias com o conteúdo dos verbetes

Uso:
    python3 construir_lexico.py --entrada pt-extract.jsonl.gz
    python3 construir_lexico.py --entrada pt.jsonl --max-sentidos 2 --sem-etimologia
"""

import argparse
import gzip
import io
import json
import os
import re
import sys
import unicodedata
from collections import defaultdict
from datetime import date

RAIZ = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.normpath(os.path.join(RAIZ, "..", "data"))

# classes gramaticais em abreviatura lexicográfica
CLASSES = {
    "noun": "s.",
    "verb": "v.",
    "adj": "adj.",
    "adv": "adv.",
    "pron": "pron.",
    "prep": "prep.",
    "conj": "conj.",
    "num": "num.",
    "intj": "interj.",
    "article": "art.",
    "det": "det.",
    "name": "s. próprio",
    "phrase": "loc.",
    "prefix": "pref.",
    "suffix": "suf.",
    "contraction": "contr.",
    "abbrev": "abrev.",
}

LIXO_INICIAL = re.compile(r"^\s*(?:\(|\[)?\s*(?:forma|flexão)\b", re.I)


def sem_acento(texto: str) -> str:
    decomposto = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in decomposto if unicodedata.category(c) != "Mn")


def chave_fatia(palavra: str) -> str:
    """Duas primeiras letras normalizadas; o resto vai para a fatia '_'."""
    base = re.sub(r"[^a-z0-9]", "", sem_acento(palavra))
    if not base:
        return "_"
    if len(base) == 1:
        return base + "_"
    return base[:2]


def abrir(caminho: str):
    if caminho.endswith(".gz"):
        return io.TextIOWrapper(gzip.open(caminho, "rb"), encoding="utf-8")
    return open(caminho, "r", encoding="utf-8")


def limpar_glosa(texto: str) -> str:
    texto = re.sub(r"\s+", " ", texto or "").strip()
    texto = texto.rstrip(" ;,")
    return texto


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera o léxico offline do dicionário.")
    ap.add_argument("--entrada", required=True, help="dump .jsonl ou .jsonl.gz do kaikki")
    ap.add_argument("--destino", default=DESTINO, help="pasta de saída (padrão: ../data)")
    ap.add_argument("--idioma", default="pt", help="código do idioma a manter (padrão: pt)")
    ap.add_argument("--max-sentidos", type=int, default=4, help="acepções por classe gramatical")
    ap.add_argument("--max-classes", type=int, default=4, help="classes gramaticais por palavra")
    ap.add_argument("--sem-etimologia", action="store_true", help="descarta etimologia (arquivo menor)")
    ap.add_argument("--sem-fonetica", action="store_true", help="descarta transcrição AFI")
    ap.add_argument("--incluir-flexoes", action="store_true",
                    help="mantém verbetes que são apenas formas flexionadas")
    args = ap.parse_args()

    verbetes: dict[str, dict] = {}
    lidas = descartadas = 0

    with abrir(args.entrada) as fonte:
        for linha in fonte:
            linha = linha.strip()
            if not linha or linha[0] != "{":
                continue
            lidas += 1
            if lidas % 200_000 == 0:
                print(f"  {lidas:>9,} linhas lidas...".replace(",", "."), file=sys.stderr)

            try:
                reg = json.loads(linha)
            except json.JSONDecodeError:
                continue

            if reg.get("lang_code") != args.idioma:
                continue

            palavra = (reg.get("word") or "").strip()
            if not palavra or len(palavra) > 60:
                continue

            glosas = []
            for sentido in reg.get("senses", []):
                for g in sentido.get("glosses") or []:
                    g = limpar_glosa(g)
                    if not g:
                        continue
                    if not args.incluir_flexoes and LIXO_INICIAL.match(g):
                        continue
                    if g not in glosas:
                        glosas.append(g)
                if len(glosas) >= args.max_sentidos:
                    break

            if not glosas:
                descartadas += 1
                continue

            classe = CLASSES.get(reg.get("pos", ""), reg.get("pos") or "")
            registro = verbetes.setdefault(palavra, {"w": palavra, "c": []})

            existente = next((b for b in registro["c"] if b["g"] == classe), None)
            if existente:
                for g in glosas:
                    if g not in existente["d"] and len(existente["d"]) < args.max_sentidos:
                        existente["d"].append(g)
            elif len(registro["c"]) < args.max_classes:
                registro["c"].append({"g": classe, "d": glosas[: args.max_sentidos]})

            if not args.sem_fonetica and "f" not in registro:
                for som in reg.get("sounds", []) or []:
                    if som.get("ipa"):
                        registro["f"] = som["ipa"]
                        break

            if not args.sem_etimologia and "e" not in registro:
                etm = limpar_glosa(reg.get("etymology_text") or "")
                if etm and len(etm) < 400:
                    registro["e"] = etm

    if not verbetes:
        print("Nenhum verbete encontrado. Confira --entrada e --idioma.", file=sys.stderr)
        return 1

    # fatiamento
    fatias: dict[str, list] = defaultdict(list)
    for palavra, registro in verbetes.items():
        fatias[chave_fatia(palavra)].append(registro)

    pasta_verbetes = os.path.join(args.destino, "verbetes")
    os.makedirs(pasta_verbetes, exist_ok=True)
    for antigo in os.listdir(pasta_verbetes):
        if antigo.endswith(".json"):
            os.remove(os.path.join(pasta_verbetes, antigo))

    bytes_totais = 0
    for chave, lista in fatias.items():
        lista.sort(key=lambda r: sem_acento(r["w"]))
        caminho = os.path.join(pasta_verbetes, f"{chave}.json")
        with open(caminho, "w", encoding="utf-8") as saida:
            json.dump(lista, saida, ensure_ascii=False, separators=(",", ":"))
        bytes_totais += os.path.getsize(caminho)

    indice = sorted(verbetes.keys(), key=lambda p: (sem_acento(p), p))
    with open(os.path.join(args.destino, "indice.json"), "w", encoding="utf-8") as saida:
        json.dump(indice, saida, ensure_ascii=False, separators=(",", ":"))

    meta = {
        "versao": date.today().isoformat(),
        "fonte": "Wikcionário em português via kaikki.org (wiktextract)",
        "licenca": "CC BY-SA 4.0",
        "verbetes": len(verbetes),
        "fatias": sorted(fatias.keys()),
        "bytes_verbetes": bytes_totais,
    }
    with open(os.path.join(args.destino, "meta.json"), "w", encoding="utf-8") as saida:
        json.dump(meta, saida, ensure_ascii=False, indent=1)

    mb = bytes_totais / 1_048_576
    print(f"\n{len(verbetes):,} verbetes em {len(fatias)} fatias · {mb:.1f} MB".replace(",", "."))
    print(f"{descartadas:,} entradas sem definição foram descartadas.".replace(",", "."))
    print(f"Saída em {args.destino}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

FIMDOARQUIVO

cat > etl/gerar_amostra.py <<'FIMDOARQUIVO'
#!/usr/bin/env python3
"""
Gera uma amostra de demonstração no mesmo formato do léxico final,
para o app funcionar antes de você rodar o ETL do Wikcionário.

    python3 gerar_amostra.py

Depois de rodar construir_lexico.py, esta amostra é sobrescrita.
"""

import json
import os
import re
import unicodedata
from collections import defaultdict
from datetime import date

RAIZ = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.normpath(os.path.join(RAIZ, "..", "data"))

AMOSTRA = [
    ("aferir", "v.", ["Conferir uma medida comparando-a com um padrão.", "Avaliar; apurar."], "Do latim afferre."),
    ("alvitre", "s.", ["Sugestão; parecer dado sobre uma questão."], None),
    ("âmago", "s.", ["Parte central e mais interna de algo.", "Essência."], None),
    ("anuir", "v.", ["Concordar; dar consentimento."], None),
    ("assíduo", "adj.", ["Que comparece com regularidade.", "Constante."], None),
    ("avença", "s.", ["Acordo; ajuste entre partes."], None),
    ("balizar", "v.", ["Delimitar com balizas.", "Servir de referência para uma decisão."], None),
    ("cerne", "s.", ["Parte mais dura do tronco.", "Ponto essencial de uma questão."], None),
    ("chancela", "s.", ["Selo que autentica um documento.", "Aprovação formal."], None),
    ("cogente", "adj.", ["Que obriga; de observância imperativa."], None),
    ("coadunar", "v.", ["Reunir em um todo coerente.", "Harmonizar-se."], None),
    ("conspícuo", "adj.", ["Que se destaca; notável."], None),
    ("dirimir", "v.", ["Resolver definitivamente uma dúvida ou conflito."], None),
    ("discricionário", "adj.", ["Que depende do juízo da autoridade, dentro da lei."], None),
    ("efêmero", "adj.", ["De curta duração."], "Do grego ephémeros, 'que dura um dia'."),
    ("elidir", "v.", ["Suprimir; eliminar.", "Afastar um argumento."], None),
    ("epítome", "s.", ["Resumo de uma obra extensa.", "Exemplo que sintetiza algo."], None),
    ("escopo", "s.", ["Alvo; finalidade.", "Conjunto de entregas de um projeto."], None),
    ("estanque", "adj.", ["Que não deixa passar fluido.", "Isolado, sem comunicação."], None),
    ("exarar", "v.", ["Registrar por escrito em documento oficial."], None),
    ("exíguo", "adj.", ["Muito pequeno; insuficiente."], None),
    ("fulcro", "s.", ["Ponto de apoio de uma alavanca.", "Fundamento de um argumento."], None),
    ("gizar", "v.", ["Traçar as linhas gerais de; planejar."], None),
    ["hialino", "adj.", ["Transparente como vidro."], None],
    ("hodierno", "adj.", ["Relativo aos dias de hoje."], None),
    ("idôneo", "adj.", ["Que reúne as condições exigidas; confiável."], None),
    ("ilação", "s.", ["Conclusão tirada de premissas."], None),
    ("impender", "v.", ["Ser necessário; cumprir fazer."], None),
    ("inócuo", "adj.", ["Que não causa dano.", "Sem efeito prático."], None),
    ("insumo", "s.", ["Bem ou serviço empregado na produção."], None),
    ("intempestivo", "adj.", ["Fora do prazo ou do momento adequado."], None),
    ("jaez", "s.", ["Índole; espécie.", "Arreio de cavalgadura."], None),
    ("lastro", "s.", ["Peso que dá estabilidade a uma embarcação.", "Garantia que sustenta um valor."], None),
    ("liminar", "s.", ["Decisão provisória tomada no início do processo."], None),
    ("lograr", "v.", ["Conseguir; alcançar.", "Enganar."], None),
    ("malsinar", "v.", ["Censurar; falar mal de."], None),
    ("mister", "s.", ["Ofício; ocupação.", "Aquilo que é necessário."], None),
    ("mitigar", "v.", ["Tornar menos intenso; abrandar."], None),
    ("nefasto", "adj.", ["Que traz desgraça; funesto."], None),
    ("obstar", "v.", ["Impedir; opor obstáculo a."], None),
    ("ombrear", "v.", ["Igualar-se em mérito ou valor."], None),
    ("outorgar", "v.", ["Conceder formalmente; conferir."], None),
    ("paradigma", "s.", ["Modelo; padrão de referência."], "Do grego parádeigma."),
    ("percuciente", "adj.", ["Que penetra fundo; perspicaz."], None),
    ("premente", "adj.", ["Que urge; inadiável."], None),
    ("preterir", "v.", ["Deixar de lado; passar à frente de alguém."], None),
    ("probo", "adj.", ["Íntegro; honesto."], None),
    ("prolação", "s.", ["Ato de proferir uma decisão."], None),
    ("quadra", "s.", ["Período de tempo.", "Área retangular de terreno."], None),
    ("quiçá", "adv.", ["Talvez; quem sabe."], None),
    ("recrudescer", "v.", ["Voltar a crescer em intensidade."], None),
    ("redundar", "v.", ["Resultar em; ter como consequência."], None),
    ("respaldo", "s.", ["Apoio; garantia.", "Encosto de assento."], None),
    ("salutar", "adj.", ["Que faz bem; benéfico."], None),
    ("sanar", "v.", ["Corrigir uma falha.", "Curar."], None),
    ("sobejo", "adj.", ["Que sobra; excessivo."], None),
    ("subsidiar", "v.", ["Fornecer recursos ou informações de apoio."], None),
    ("tangenciar", "v.", ["Tocar de leve.", "Abordar um assunto sem aprofundá-lo."], None),
    ("tergiversar", "v.", ["Usar rodeios para não responder."], None),
    ("truncar", "v.", ["Cortar parte de; deixar incompleto."], None),
    ("ulterior", "adj.", ["Que vem depois; posterior."], None),
    ("verossímil", "adj.", ["Que parece verdadeiro."], None),
    ("vetusto", "adj.", ["Muito antigo."], None),
    ("vicejar", "v.", ["Crescer com viço; prosperar."], None),
    ("zelar", "v.", ["Cuidar com atenção; preservar."], None),
]


def sem_acento(texto: str) -> str:
    d = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in d if unicodedata.category(c) != "Mn")


def chave_fatia(palavra: str) -> str:
    base = re.sub(r"[^a-z0-9]", "", sem_acento(palavra))
    if not base:
        return "_"
    return base[:2] if len(base) > 1 else base + "_"


def main() -> None:
    fatias = defaultdict(list)
    palavras = []
    for item in AMOSTRA:
        palavra, classe, definicoes, etimologia = item
        registro = {"w": palavra, "c": [{"g": classe, "d": definicoes}]}
        if etimologia:
            registro["e"] = etimologia
        fatias[chave_fatia(palavra)].append(registro)
        palavras.append(palavra)

    pasta = os.path.join(DESTINO, "verbetes")
    os.makedirs(pasta, exist_ok=True)
    for chave, lista in fatias.items():
        lista.sort(key=lambda r: sem_acento(r["w"]))
        with open(os.path.join(pasta, f"{chave}.json"), "w", encoding="utf-8") as f:
            json.dump(lista, f, ensure_ascii=False, separators=(",", ":"))

    palavras.sort(key=lambda p: (sem_acento(p), p))
    with open(os.path.join(DESTINO, "indice.json"), "w", encoding="utf-8") as f:
        json.dump(palavras, f, ensure_ascii=False, separators=(",", ":"))

    meta = {
        "versao": date.today().isoformat(),
        "fonte": "amostra de demonstração",
        "licenca": "—",
        "verbetes": len(palavras),
        "fatias": sorted(fatias.keys()),
        "bytes_verbetes": 0,
        "amostra": True,
    }
    with open(os.path.join(DESTINO, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)

    print(f"{len(palavras)} verbetes de amostra em {len(fatias)} fatias.")


if __name__ == "__main__":
    main()

FIMDOARQUIVO

cat > icones/icone.svg <<'FIMDOARQUIVO'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="Dicionário">
  <rect width="512" height="512" fill="#2F5D50"/>
  <text x="256" y="256" fill="#E9EAE4" font-family="ui-serif, Georgia, 'Times New Roman', serif"
        font-size="318" text-anchor="middle" dominant-baseline="central">á</text>
</svg>

FIMDOARQUIVO

base64 -d > icones/icone-180.png <<'FIMDOARQUIVO'
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
TkSuQmCC
FIMDOARQUIVO

base64 -d > icones/icone-192.png <<'FIMDOARQUIVO'
iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAIAAADdvvtQAAALdUlEQVR4nO3deXAUZRrH8Z4rxyST
C3JPbnIZIGyAgICCHMYjC6gFGKiIrourslgLKuWKWtTuahVa4o1cxnVZL0QhoCCKLEEJEoSYGMGQ
A0IynEnIMUNmJsnM/uFWZEOmp5Nnpqfn7d/nz+433U+KL8lkjm5FduFcDmColJ4eALwbAgISBAQk
CAhIEBCQICAgQUBAgoCABAEBCQICEgQEJAgISBAQkCAgIEFAQIKAgAQBAQkCAhIEBCQICEgQEJAg
ICBBQECCgIAEAQEJAgISBAQkCAhIEBCQICAgQUBAgoCABAEBCQICEgQEJAgISBAQkCAgIEFAQIKA
gAQBAQkCAhIEBCQICEgQEJAgICBRe3oAL5MRn/jqshVKpcP/eD29vc++s/5Y9Ukxp/Ig/AQaBF+N
ZmVBIU89drv95Y//LZ96OAQ0KA/eOUcfEcmzYPPnO745dlS0eaQAAQmVnZI6Z8pUngWfHdz/yYFv
RJtHIhCQIP6+fk8UFCoUCkcLDpQf27Bzu5gjSQQCEuSROfdEhoY52lteU/3ih/+y2+1ijiQRCMi5
3Mys2ybc6GhvnaFp9bubenp7xRxJOhCQEzqtdsX8hY72XmhtWbVpXZfFLOZIkoKAnHjsnnvDgoIH
3NVuNP51w5utnR0ijyQpCIjP1DE5U8fkDLjLbLU+s/ltQ/NlkUeSGgTkUJguaNndCwbc1Wuz/f29
zdWNDSKPJEEIyKHl8xcGBQQMuGvt1veP/nJC5HmkCQENLC/3xgk3jBxwV9EXO78+ekTkeSQLAQ0g
IjT0kTn3DLhrx3clH+3/SuR5pAwB9adQKJ64t1Dr53f9roMV5W/v2Cb+SFKGgPqbM2XqmBFp12+v
qKtZ88F78ny6mQcC+j/68IgH75h9/fb684bVRRu7e3rEH0niENBvlErlkwWFvj4+/bZfvNK6auM6
k7nLI1NJHAL6zfxbZmYmJPXb2GEyPb3xrZaOdo+MJH0I6H+So2Pvy7uz30aL1frsO+sbL130yEhe
AQFxHMepVaqVC+9Tq1TXbrTZbP/YUnSy4bSnpvIKCIjjOK4w747kmNh+G1/d9uGRE1UemceLKLIL
53p6BvBi+AkEJAgISBAQkCAgIEFAQIKAgAQBAQkCAhL5Xt5FoVDER0Qmx+j1ERH68Ijw4NAQnS5I
G+Cr0fhoNL02m6Xbaunu7jSZLre3tbS3nblwvtbQVGdoNHbhZfnfyCsgpVKZqo/LSc0Yk5qWEZ/g
7zvA2w5/pVap1Cr/AD//MF1QQlR033a73V7d2HD05ImDFccbLl4QZWpJk8VLGSqlMictY8roMZOy
RgcHBrrqsFX1dcWHSg5WlMv5bYqMB5QcE3vr+Ikzcsa7sJt+6gxNm78oltVFpa7FZkBqlWryqOy5
U6ZlJSWLc8Y9R0rXF3/aZbGIczrpYPMxUG5m1qrCP4h5xtsnTBqVlPL0pnUXWlvEPK/HsRmQcDab
rbK+9mTD6eqzDYbLl4xdXUZzl81mC9IGBGq1QdqAVH1cVlJKVlJymC6I/1D6iMjXHnti1aa3ag1N
4gwvBWz+Cps0cvTqBx7iX9NhMhUfKtnzfWlze5uQY/4uNX3eLTPHpWfyL2szdv7l9ZfPtTQLHNXb
yfQnUMmPx9/a/kmbsVP4l5TXVJfXVKfE6lcW3JcUHeNoWUig7oWHlj76ypqrZllcNEiOz0Rv3LX9
+S1Fg6qnT52h6bHXXtpbdphnTczw8KV3zRvqdF5GdgFt3LV9G+1aqpbu7pc/fn/L3t08a2aNmzAx
axTlLN5CXgEdOVFFrKfPlq927ztWxrNgSf5cnkuSM4P977DPVbP5tW0fufCAr2/76HLbFUd74yIi
Z43LdeHppElGAX1ZdljgH1wCma3Wot07eRbMmTLNhaeTJhkF9Pnh71x+zAPlx3h+CI2I1afHJ7j8
pJIil4BONZ5tcsMnlHtttv3Hf+BZMDV74Gt0MkMuAVWdrnPTkfk/vZqbmeWm80qEXAI6cabeTUc+
1XiW5zL18ZFRw4ND3HRqKWDzmejSqspbH/+zOOey9nRfvNIaOzzc0YK0uHjXPniXFLn8BHKrS1da
efaOiI0TbRLxISAX4H/ZKz4ySrRJxIeAXMDS3c2zl+3HQAjIJfjeEx0eEiLWGB6AgNxOpx34fgls
QEBu56vReHoEN0JAbqdQKPpdfZElbD4PJIRapUqJ1SdGRevDI2OGh4fqdCGBOp1W66NWa9Qa1/6T
q1UqVu+JKbuAEiKjJo3MHp95Q1pcvI9apF8uPLd79nZyCcjf13fG2PH5k25Kju5/NVagYD8gjVo9
e/LNBTPyHN09DigYD+iGxOQnCwp5XqgCIpYDWjgzb/Ft+Qw//pACNgNSKpWPL1g0a9wEgetbOzsq
a2tONpw+e+nipSutbcZOi7W7u7dH4GU3nlq0eHrOeMK8XozNgJbPKxBSj91uP1RVUfxtSWV9rZwv
0ULBYEALps/Ky73R6bL6c4a1W98/1XhWhJEYxlpA6XEJi2/Ld7qstKryhS3vWnv4XkUHIVh7KWPp
3fOcPol84kw96nEVpgKaPCo7Iz6Rf02HyfRc0QbU4ypMBTR78s1O13xyYF+HySTCMDLBTkDhIaED
3q77Wh0mU/F3JeLMIxPsBDQuPdPpc4Zlv/xstlrFmUcm2AlodEqq0zU/1pwSYRJZYSegBAEffvip
vlaESWSFnYBiBLxiynMhBBgaRgJSKpVaP4f3LfhVl8XC6tsCPYiRgPx8fJyu6bjqrr/e1SrWntAX
jpGAhFC67X0d/r6+bjqy9DESkJA/zt13uwy2PzrIj5GAbDZbl8XJdZl91Bohv+kGS61SRQ+T7zse
GQmI47jzAm5SkRjl8ALhQ5YSo2f7o4P82Amo8aLzK9jlpGe4/LwTs0a6/JhehJ2AfhZwDTKnd7oY
LKVSOXMs+9fy5cFOQOU11U7XjExKSY9z5WVTp43JiQwb5sIDeh12Amq4cP7MhXNOl91/u/P3Kwrk
7+v7wB2zXXU0L8VOQBzH7fm+1OmasemZ03PGueR0S++aFxka5pJDeS+mAtp9pLTdZHS6bMWCRZkJ
ScRzzb9l5q3jJxIPwgCmArJYre99+bnTZT5qzd8e/FO2gLd/OLJwZt4f8+cO+ctZwlRAHMd9cfhQ
Vb3za4oHBwSueXjZgumzBvu51ZBA3eoHHrr/9t/3bbHb7QxfxdcpBm95GRYUvG75yrCgYCGLmy5f
2vqfr/f9UOb0hfqggID8STfNmzYjwM//2u0bdn6Wqo8b8idTdx46+OZnW4f2tVLA4MvIrR3tz7yz
/sWHlwX6a50u1odHrJi/aEn+XZV1NRV1NacaG9qMxs6rJpPZrFGpdNqA6GHDU/XxOWnpOWkZ139g
6IN9ez8t2f/UosXu+Va8AIMBcRxX29S4cv0bLyx5NCRQJ2S9TqudPCp78qhs4aew2+1vF3+649sD
Q5uQGaw9BupT29T46No11Y0N7jh4u9H4XNEG1MMxHBDHcc3tbcvfWPvPPbtc+zHC0qrKJS89z3+T
Hvlg81dYn57e3g/27f36h7KCGXl5uRM1atL3+1N97bu7d7nvzlHeiMG/whzRabUzxuZOzc7JTEgc
1O1wm9vbDlYc/6rsSP15g/vG81IyCqhPoL//yOQRI2L1iVExEaGhw4KCA/z8fTQalVJptlrNVqux
6+r5luZzLc2nzxkq62oMzZc9PbJ0yTEgcCGWH0SDCBAQkCAgIEFAQIKAgAQBAQkCAhIEBCQICEgQ
EJAgICBBQECCgIAEAQEJAgISBAQkCAhIEBCQICAgQUBAgoCABAEBCQICEgQEJAgISBAQkCAgIEFA
QIKAgAQBAQkCAhIEBCQICEgQEJAgICBBQECCgIAEAQEJAgISBAQkCAhIEBCQICAgQUBAgoCABAEB
CQICkv8CxRwWmxXjzfAAAAAASUVORK5CYII=
FIMDOARQUIVO

base64 -d > icones/icone-512.png <<'FIMDOARQUIVO'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAgxUlEQVR4nO3dd3iV9d348TMzSEIm
2Yswwgh7TwcoW5AiAgpSra2/WvegVq19fu3Tp/OpWMCyXVVxgSIoIIggMmUPwyaLJGQPkpOck/P8
YR8fiwEyvvd9n3M+79flH169PJ/vh14h75yR+zb3mj3FBACQx2L0AgAAYxAAABCKAACAUAQAAIQi
AAAgFAEAAKEIAAAIRQAAQCgCAABCEQAAEIoAAIBQBAAAhCIAACAUAQAAoQgAAAhFAABAKAIAAEIR
AAAQigAAgFAEAACEIgAAIBQBAAChCAAACEUAAEAoAgAAQhEAABCKAACAUAQAAIQiAAAgFAEAAKEI
AAAIRQAAQCgCAABCEQAAEIoAAIBQBAAAhCIAACAUAQAAoQgAAAhFAABAKAIAAEIRAAAQigAAgFAE
AACEIgAAIBQBAAChCAAACEUAAEAoAgAAQhEAABCKAACAUAQAAIQiAAAgFAEAAKEIAAAIRQAAQCgC
AABCEQAAEIoAAIBQBAAAhCIAACAUAQAAoQgAAAhFAABAKAIAAEIRAAAQigAAgFAEAACEIgAAIBQB
AAChCAAACEUAAEAoAgAAQhEAABCKAACAUAQAAIQiAAAgFAEAAKEIAAAIRQAAQCgCAABCEQAAEIoA
AIBQBAAAhCIAACAUAQAAoQgAAAhFAABAKAIAAEIRAAAQigAAgFAEAACEIgAAIBQBAAChCAAACEUA
AEAoAgAAQhEAABCKAACAUAQAAIQiAAAgFAEAAKEIAAAIRQAAQCgCAABCEQAAEIoAAIBQBAAAhCIA
ACAUAQAAoQgAAAhFAABAKAIAAEIRAAAQigAAgFAEAACEIgAAIBQBAAChCAAACEUAAEAoAgAAQhEA
ABCKAACAUAQAAIQiAAAgFAEAAKFsRi8AeAez2fynBx7q1bGzFsNziy49+ve/lldVaTEcuBqeAQBN
cvuImzT67l9SUf7LxQv47g/9EQDg+pJjYu+dMEmLydW1Nb9asqigpFiL4cC1EQDgOqwWy7xZc/xs
duWT65z1L6xYcvZirvLJQFMQAOA67r51XKfEZOVjGxoa/uuNVw6fOaV8MtBEBAC4lvSklBmjxmgx
+aX3V+04ckiLyUATEQDgqvzt9nmz5lgt6v+avLZh3fpdO5SPBZqFAABXdd/EKYnRMcrHrt2x7Y2N
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
AABJRU5ErkJggg==
FIMDOARQUIVO

base64 -d > icones/icone-512-mascara.png <<'FIMDOARQUIVO'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAa40lEQVR4nO3deXTddZ3w8dxsbdqk
adM9TZfQnZYWCm2lbApF7CBQVLYKyqDCo+KC64My53GcGcdxBtBRRKBwDgoMFJSCVIEWyqLSBQpq
6cLSje60TdK0abM/fzDnmaMPlubme+/vJt/X61/u73M/PSfcd3439/5+qalXzM0DID75SS8AQDIE
ACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBI
CQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAA
kRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoA
ACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiU
AABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQ
KQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQA
IFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJ
AECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoAACIlAACR
EgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAA
IiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQA
AERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABEqjDpBSB39e9Tfsc3vl1a0qszQ1rb2r5z
1+3L164OtRWE4gwA/qavXnp5J1/98/Lybl5wn1d/cpMAwLs775TTTxo/sZND7nhs4ZMrlwXZB4IT
AHgXwwYMvPrDczs55KFnnnpw6ZIQ60BGCAD8tfz8/G/M+0SP4uLODFny0oo7HlsYaCPICAGAv3bp
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
AAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCI
lAAAREoAACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIA
ECkBAIiUAABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQE
ACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBI
CQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAA
kRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoA
ACIlAACREgCASAkAQKQEACBSAgAQKQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiU
AABESgAAIiUAAJESAIBICQBApAQAIFICABApAQCIlAAAREoAACIlAACREgCASAkAQKQEACBSAgAQ
KQEAiJQAAERKAAAiJQAAkRIAgEgJAECkBAAgUgIAECkBAIiUAABESgAAIiUAAJESAIBICQBApAQA
IFICABApAQCIlAAAREoAACIlAACR+r/GQkjg2Z0dbQAAAABJRU5ErkJggg==
FIMDOARQUIVO


# ---------------------------------------------------------------- lexico

ja_tem_lexico() {
  [ -f data/meta.json ] || return 1
  python3 -c "
import json, sys
meta = json.load(open('data/meta.json', encoding='utf-8'))
sys.exit(0 if not meta.get('amostra') and meta.get('verbetes', 0) > 5000 else 1)
" || return 1
}

SALTAR=0
if [ "${REFAZER:-0}" = "1" ]; then
  echo "==> REFAZER=1: reconstruindo o lexico do zero"
  rm -rf data
elif ja_tem_lexico; then
  echo "==> lexico ja versionado no repositorio; pulando a reconstrucao"
  echo "    (para refazer, apague a pasta data/ ou rode com REFAZER=1)"
  SALTAR=1
fi

if [ "$SALTAR" != "1" ]; then
  echo "==> localizando o dump do Wikcionario"
  if URL=$(python3 etl/localizar_dump.py); then
    echo "    $URL"
    case "$URL" in
      *.gz) ARQ=dump.jsonl.gz ;;
      *)    ARQ=dump.jsonl ;;
    esac
    if curl -fL --retry 4 --retry-delay 10 -o "$ARQ" "$URL"; then
      ls -lh "$ARQ"
      python3 etl/construir_lexico.py --entrada "$ARQ"
      rm -f "$ARQ"
    else
      echo "!! o download falhou; publicando com a amostra"
      python3 etl/gerar_amostra.py
    fi
  else
    echo "!! nao localizei o dump; publicando com a amostra"
    python3 etl/gerar_amostra.py
  fi
fi

echo "==> conferindo a base"
python3 -c "
import json
indice = json.load(open('data/indice.json', encoding='utf-8'))
meta = json.load(open('data/meta.json', encoding='utf-8'))
rotulo = 'AMOSTRA' if meta.get('amostra') else 'Wikcionario'
print(f'    {len(indice)} verbetes ({rotulo}) em {len(meta[\"fatias\"])} fatias')
"
du -sh data

echo "==> enviando para o GitHub"
git config user.name  >/dev/null 2>&1 || git config user.name  "github-actions[bot]"
git config user.email >/dev/null 2>&1 || git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -m "Dicionario: app e lexico" || echo "    (nada novo a enviar)"
git push origin HEAD

echo
echo "Pronto. Agora:"
echo "  Settings -> Pages -> Source: Deploy from a branch -> main / (root)"
echo "  Depois abra https://leoengmec.github.io/dicionario/ no Safari"
