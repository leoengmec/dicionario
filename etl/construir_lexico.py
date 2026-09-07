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

