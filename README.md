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

## O que cada verbete traz

Palavra, classe gramatical e acepções numeradas; e, quando o Wikcionário
registra, pronúncia em AFI, etimologia, sinônimos e antônimos. Sinônimos e
antônimos são tocáveis: levam direto ao verbete correspondente.

A cobertura real de cada campo fica em `data/meta.json` e aparece no painel
**Base** dentro do app. O `etl/inspecionar_dump.py` roda antes do ETL e imprime
no log sob quais chaves cada dado está vindo — o wiktextract muda esses nomes
entre extratores, então medimos em vez de supor.

## Seus próprios verbetes

Edite `etl/meus-verbetes.txt` — pelo app do GitHub mesmo — e rode o workflow.
O formato está documentado no cabeçalho do arquivo: texto puro, um bloco por
palavra, campos `palavra`, `classe`, `def`, `sin`, `ant`, `ex`, `etim`, `pron`.
Palavras que já existem no Wikcionário ganham o seu bloco na frente; as que não
existem viram verbetes novos. Apagar o bloco e rodar de novo remove.

## Escopo

v1.0: busca e offline. v1.1: pronúncia, etimologia, sinônimos, antônimos.
Fora por enquanto: favoritos, histórico, notas.
