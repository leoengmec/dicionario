#!/usr/bin/env bash
# Constroi o lexico do Wikcionario e commita o resultado.
# Roda pelo workflow "Instalar o projeto" ou em qualquer terminal.
# As fontes do app ficam versionadas no repositorio; este script nao as toca.
set -euo pipefail

ESQUEMA=3

lexico_atual() {
  [ -f data/meta.json ] || return 1
  ESQUEMA="$ESQUEMA" python3 -c "
import json, os, sys
meta = json.load(open('data/meta.json', encoding='utf-8'))
ok = (not meta.get('amostra')
      and meta.get('verbetes', 0) > 5000
      and meta.get('esquema', 0) >= int(os.environ['ESQUEMA']))
sys.exit(0 if ok else 1)
" || return 1
}

SALTAR=0
if [ "${REFAZER:-0}" = "1" ]; then
  echo "==> REFAZER=1: reconstruindo o lexico do zero"
  rm -rf data
elif lexico_atual; then
  echo "==> lexico ja esta no esquema $ESQUEMA; pulando a reconstrucao"
  SALTAR=1
else
  echo "==> lexico ausente ou em esquema antigo; sera reconstruido"
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
      echo "==> censo dos campos do dump (tambem salvo em etl/censo.txt)"
      python3 etl/inspecionar_dump.py --entrada "$ARQ" 2>&1 | tee etl/censo.txt || true
      python3 etl/construir_lexico.py --entrada "$ARQ" 2>&1 | tee -a etl/censo.txt
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

echo "==> mesclando os verbetes pessoais (etl/meus-verbetes.txt)"
python3 etl/mesclar_pessoal.py

echo "==> conferindo a base"
python3 -c "
import json
indice = json.load(open('data/indice.json', encoding='utf-8'))
meta = json.load(open('data/meta.json', encoding='utf-8'))
rotulo = 'AMOSTRA' if meta.get('amostra') else 'Wikcionario'
print(f'    {len(indice)} verbetes ({rotulo}), esquema {meta.get(\"esquema\", 1)}')
for campo, nome in (('f','pronuncia'), ('e','etimologia'), ('s','sinonimos'), ('a','antonimos')):
    print(f'    {nome:<11} {meta.get(\"cobertura\", {}).get(campo, 0)}%')
"
du -sh data

echo "==> enviando para o GitHub"
git config user.name  >/dev/null 2>&1 || git config user.name  "github-actions[bot]"
git config user.email >/dev/null 2>&1 || git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -m "Lexico: esquema $ESQUEMA" || echo "    (nada novo a enviar)"
git push origin HEAD
echo "Pronto."
