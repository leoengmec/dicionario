#!/usr/bin/env python3
"""
Lê as primeiras N entradas em português do dump e conta sob quais chaves
aparecem etimologia, sinônimos, antônimos e pronúncia.

Existe porque o wiktextract não usa os mesmos nomes de campo em todos os
extratores: o do Wikcionário inglês emite `etymology_text`, outros emitem
`etymology_texts`. Em vez de adivinhar, medimos.

    python3 etl/inspecionar_dump.py --entrada dump.jsonl.gz
"""

import argparse
import gzip
import io
import json
import sys
from collections import Counter


def abrir(caminho):
    if caminho.endswith(".gz"):
        return io.TextIOWrapper(gzip.open(caminho, "rb"), encoding="utf-8")
    return open(caminho, "r", encoding="utf-8")


def forma(valor):
    if isinstance(valor, str):
        return "texto"
    if isinstance(valor, list):
        if not valor:
            return "lista vazia"
        primeiro = valor[0]
        if isinstance(primeiro, str):
            return "lista de textos"
        if isinstance(primeiro, dict):
            return "lista de objetos: " + ",".join(sorted(primeiro)[:5])
        return "lista"
    if isinstance(valor, dict):
        return "objeto"
    return type(valor).__name__


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--entrada", required=True)
    ap.add_argument("--idioma", default="pt")
    ap.add_argument("--amostra", type=int, default=30000)
    args = ap.parse_args()

    chaves_topo = Counter()
    chaves_sentido = Counter()
    formas = {}
    exemplos = {}
    vistos = 0

    with abrir(args.entrada) as fonte:
        for linha in fonte:
            if not linha.startswith("{"):
                continue
            try:
                reg = json.loads(linha)
            except json.JSONDecodeError:
                continue
            if reg.get("lang_code") != args.idioma:
                continue
            vistos += 1

            for chave, valor in reg.items():
                if valor in (None, "", [], {}):
                    continue
                chaves_topo[chave] += 1
                formas.setdefault(chave, forma(valor))
                if chave not in exemplos and chave not in ("senses", "forms"):
                    exemplos[chave] = json.dumps(valor, ensure_ascii=False)[:110]

            for sentido in reg.get("senses", []) or []:
                for chave, valor in sentido.items():
                    if valor in (None, "", [], {}):
                        continue
                    chaves_sentido[chave] += 1
                    formas.setdefault("senses." + chave, forma(valor))

            if vistos >= args.amostra:
                break

    if not vistos:
        print("Nenhuma entrada no idioma pedido.", file=sys.stderr)
        return 1

    print(f"\n===== censo de {vistos} entradas em '{args.idioma}' =====\n")
    print("-- chaves no topo do registro --")
    for chave, n in chaves_topo.most_common(30):
        print(f"  {chave:<24} {100*n/vistos:>5.1f}%   {formas.get(chave,'')}")

    print("\n-- chaves dentro de senses --")
    for chave, n in chaves_sentido.most_common(20):
        print(f"  {chave:<24} {n:>7}   {formas.get('senses.'+chave,'')}")

    print("\n-- primeiro valor visto, nos campos que nos interessam --")
    for chave in ("etymology_text", "etymology_texts", "etymology", "sounds",
                  "synonyms", "antonyms", "related", "hypernyms"):
        if chave in exemplos:
            print(f"  {chave}: {exemplos[chave]}")
        elif chave in chaves_topo:
            print(f"  {chave}: presente em {100*chaves_topo[chave]/vistos:.1f}%")
        else:
            print(f"  {chave}: ausente no topo")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
