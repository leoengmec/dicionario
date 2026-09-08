#!/usr/bin/env python3
"""
Constrói o léxico offline do app a partir da extração do Wikcionário-PT
publicada por kaikki.org (formato JSONL, produzido pelo wiktextract).

Saída (dentro de ../data):
    indice.json          lista de todas as entradas (busca e sugestões)
    meta.json            versão, esquema, contagens, cobertura, fatias
    verbetes/<xx>.json   fatias com o conteúdo dos verbetes

Esquema de um verbete:
    w  palavra        c  [{g: classe, d: [acepções]}]
    f  pronúncia      e  etimologia
    s  sinônimos      a  antônimos
    x  exemplo        r  remissão (forma flexionada -> lema)

Uso:
    python3 construir_lexico.py --entrada pt-extract.jsonl.gz
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

ESQUEMA = 3

RAIZ = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.normpath(os.path.join(RAIZ, "..", "data"))

CLASSES = {
    "noun": "s.", "verb": "v.", "adj": "adj.", "adv": "adv.", "pron": "pron.",
    "prep": "prep.", "conj": "conj.", "num": "num.", "intj": "interj.",
    "article": "art.", "det": "det.", "name": "s. próprio", "phrase": "loc.",
    "prefix": "pref.", "suffix": "suf.", "contraction": "contr.",
    "abbrev": "abrev.", "character": "caráct.", "symbol": "símb.",
}

# O wiktextract não usa os mesmos nomes de campo em todos os extratores.
# Em vez de assumir um, tentamos todos e ficamos com o primeiro que existir.
CHAVES_ETIMOLOGIA = ("etymology_text", "etymology_texts", "etymology", "etym")
CHAVES_SINONIMO = ("synonyms", "synonym", "syn")
CHAVES_ANTONIMO = ("antonyms", "antonym", "ant")
CHAVES_SOM = ("ipa", "IPA", "phonetic", "other")

LIXO_INICIAL = re.compile(r"^\s*(?:\(|\[)?\s*(?:forma|flexão)\b", re.I)
TEM_LETRA = re.compile(r"[^\W\d_]", re.UNICODE)


def sem_acento(texto):
    d = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in d if unicodedata.category(c) != "Mn")


def chave_fatia(palavra):
    base = re.sub(r"[^a-z0-9]", "", sem_acento(palavra))
    if not base:
        return "_"
    return base[:2] if len(base) > 1 else base + "_"


def abrir(caminho):
    if caminho.endswith(".gz"):
        return io.TextIOWrapper(gzip.open(caminho, "rb"), encoding="utf-8")
    return open(caminho, "r", encoding="utf-8")


def limpar(texto):
    if not isinstance(texto, str):
        return ""
    return re.sub(r"\s+", " ", texto).strip().rstrip(" ;,")


def primeiro_texto(reg, chaves):
    """Aceita o campo como texto ou como lista de textos."""
    for chave in chaves:
        valor = reg.get(chave)
        if isinstance(valor, str) and valor.strip():
            return limpar(valor)
        if isinstance(valor, list):
            juntos = " ".join(limpar(v) for v in valor if isinstance(v, str))
            if juntos.strip():
                return limpar(juntos)
    return ""


def colher_palavras(reg, chaves):
    """Aceita ['x'] ou [{'word': 'x'}], no topo do registro e dentro de senses."""
    achadas = []

    def absorver(valor):
        if isinstance(valor, str):
            achadas.append(valor)
        elif isinstance(valor, list):
            for item in valor:
                if isinstance(item, str):
                    achadas.append(item)
                elif isinstance(item, dict):
                    for campo in ("word", "term", "text", "sense"):
                        if isinstance(item.get(campo), str):
                            achadas.append(item[campo])
                            break

    for chave in chaves:
        absorver(reg.get(chave))
    for sentido in reg.get("senses", []) or []:
        for chave in chaves:
            absorver(sentido.get(chave))

    limpas, vistas = [], set()
    for p in achadas:
        p = limpar(p)
        if not p or len(p) > 40 or p in vistas:
            continue
        vistas.add(p)
        limpas.append(p)
    return limpas


def colher_pronuncia(reg):
    """Prefere AFI do Brasil; ignora notação SAMPA."""
    candidatos = []
    for som in reg.get("sounds", []) or []:
        if not isinstance(som, dict):
            continue
        etiquetas = " ".join(som.get("tags", []) + som.get("raw_tags", [])).lower()
        if "sampa" in etiquetas:
            continue
        for chave in CHAVES_SOM:
            valor = som.get(chave)
            if isinstance(valor, str) and valor.strip():
                pontos = 2 if "brazil" in etiquetas or "brasil" in etiquetas else 1
                candidatos.append((pontos, limpar(valor)))
                break
    if not candidatos:
        return ""
    candidatos.sort(key=lambda c: -c[0])
    return candidatos[0][1]


def colher_remissao(sentido):
    """Alvo de uma forma flexionada, se a acepção for form_of."""
    alvos = sentido.get("form_of")
    if isinstance(alvos, list):
        for alvo in alvos:
            if isinstance(alvo, dict) and isinstance(alvo.get("word"), str):
                return limpar(alvo["word"])
            if isinstance(alvo, str):
                return limpar(alvo)
    return ""


def colher_exemplo(sentido):
    for ex in sentido.get("examples", []) or []:
        texto = ex.get("text") if isinstance(ex, dict) else ex
        texto = limpar(texto)
        if 12 <= len(texto) <= 180:
            return texto
    return ""


def main():
    ap = argparse.ArgumentParser(description="Gera o léxico offline do dicionário.")
    ap.add_argument("--entrada", required=True)
    ap.add_argument("--destino", default=DESTINO)
    ap.add_argument("--idioma", default="pt")
    ap.add_argument("--max-sentidos", type=int, default=4)
    ap.add_argument("--max-classes", type=int, default=4)
    ap.add_argument("--max-relacionadas", type=int, default=12)
    ap.add_argument("--sem-etimologia", action="store_true")
    ap.add_argument("--sem-fonetica", action="store_true")
    ap.add_argument("--sem-relacionadas", action="store_true")
    ap.add_argument("--manter-nao-palavras", action="store_true",
                    help="mantém entradas sem nenhuma letra (números, símbolos)")
    ap.add_argument("--incluir-flexoes", action="store_true")
    args = ap.parse_args()

    verbetes = {}
    lidas = sem_definicao = descartadas = remissoes = 0
    achou = {"e": 0, "f": 0, "s": 0, "a": 0, "x": 0}

    with abrir(args.entrada) as fonte:
        for linha in fonte:
            if not linha.startswith("{"):
                continue
            lidas += 1
            if lidas % 200000 == 0:
                print("  %d linhas lidas..." % lidas, file=sys.stderr)

            try:
                reg = json.loads(linha)
            except json.JSONDecodeError:
                continue
            if reg.get("lang_code") != args.idioma:
                continue

            palavra = (reg.get("word") or "").strip()
            if not palavra or len(palavra) > 60:
                continue
            if not args.manter_nao_palavras and not TEM_LETRA.search(palavra):
                descartadas += 1
                continue

            glosas = []
            remissao = ""
            exemplo = ""
            for sentido in reg.get("senses", []) or []:
                alvo = colher_remissao(sentido)
                if alvo and not args.incluir_flexoes:
                    remissao = remissao or alvo
                    continue
                for g in sentido.get("glosses") or []:
                    g = limpar(g)
                    if not g:
                        continue
                    if not args.incluir_flexoes and LIXO_INICIAL.match(g):
                        continue
                    if g not in glosas:
                        glosas.append(g)
                if not exemplo:
                    exemplo = colher_exemplo(sentido)
                if len(glosas) >= args.max_sentidos:
                    break

            if not glosas:
                if remissao and remissao != palavra:
                    registro = verbetes.setdefault(palavra, {"w": palavra, "c": []})
                    if not registro["c"] and "r" not in registro:
                        registro["r"] = remissao
                        remissoes += 1
                else:
                    sem_definicao += 1
                continue

            classe = CLASSES.get(reg.get("pos", ""), reg.get("pos") or "")
            registro = verbetes.setdefault(palavra, {"w": palavra, "c": []})
            registro.pop("r", None)

            if exemplo and "x" not in registro:
                registro["x"] = exemplo
                achou["x"] += 1

            bloco = None
            for b in registro["c"]:
                if b["g"] == classe:
                    bloco = b
                    break
            if bloco:
                for g in glosas:
                    if g not in bloco["d"] and len(bloco["d"]) < args.max_sentidos:
                        bloco["d"].append(g)
            elif len(registro["c"]) < args.max_classes:
                registro["c"].append({"g": classe, "d": glosas[: args.max_sentidos]})

            if not args.sem_fonetica and "f" not in registro:
                afi = colher_pronuncia(reg)
                if afi:
                    registro["f"] = afi
                    achou["f"] += 1

            if not args.sem_etimologia and "e" not in registro:
                etm = primeiro_texto(reg, CHAVES_ETIMOLOGIA)
                if etm and len(etm) < 500:
                    registro["e"] = etm
                    achou["e"] += 1

            if not args.sem_relacionadas:
                for campo, chaves in (("s", CHAVES_SINONIMO), ("a", CHAVES_ANTONIMO)):
                    novas = colher_palavras(reg, chaves)
                    if not novas:
                        continue
                    atual = registro.setdefault(campo, [])
                    estreou = not atual
                    for p in novas:
                        if p != palavra and p not in atual and len(atual) < args.max_relacionadas:
                            atual.append(p)
                    if estreou and atual:
                        achou[campo] += 1

    if not verbetes:
        print("Nenhum verbete encontrado. Confira --entrada e --idioma.", file=sys.stderr)
        return 1

    for registro in verbetes.values():
        for campo in ("s", "a"):
            if campo in registro and not registro[campo]:
                del registro[campo]
        if not registro["c"]:
            del registro["c"]

    fatias = defaultdict(list)
    for palavra, registro in verbetes.items():
        fatias[chave_fatia(palavra)].append(registro)

    pasta = os.path.join(args.destino, "verbetes")
    os.makedirs(pasta, exist_ok=True)
    for antigo in os.listdir(pasta):
        if antigo.endswith(".json"):
            os.remove(os.path.join(pasta, antigo))

    bytes_totais = 0
    for chave, lista in fatias.items():
        lista.sort(key=lambda r: sem_acento(r["w"]))
        caminho = os.path.join(pasta, chave + ".json")
        with open(caminho, "w", encoding="utf-8") as saida:
            json.dump(lista, saida, ensure_ascii=False, separators=(",", ":"))
        bytes_totais += os.path.getsize(caminho)

    indice = sorted(verbetes.keys(), key=lambda p: (sem_acento(p), p))
    with open(os.path.join(args.destino, "indice.json"), "w", encoding="utf-8") as saida:
        json.dump(indice, saida, ensure_ascii=False, separators=(",", ":"))

    total = len(verbetes)
    lemas = sum(1 for r in verbetes.values() if r.get("c"))
    cobertura = dict((k, round(100.0 * v / max(lemas, 1), 1)) for k, v in achou.items())
    meta = {
        "versao": date.today().isoformat(),
        "esquema": ESQUEMA,
        "fonte": "Wikcionário em português via kaikki.org (wiktextract)",
        "licenca": "CC BY-SA 4.0",
        "verbetes": total,
        "lemas": lemas,
        "remissoes": total - lemas,
        "cobertura": cobertura,
        "fatias": sorted(fatias.keys()),
        "bytes_verbetes": bytes_totais,
    }
    with open(os.path.join(args.destino, "meta.json"), "w", encoding="utf-8") as saida:
        json.dump(meta, saida, ensure_ascii=False, indent=1)

    print("\n%d verbetes em %d fatias · %.1f MB" % (total, len(fatias), bytes_totais / 1048576))
    print("  %d lemas com definição + %d remissões de formas flexionadas" % (lemas, total - lemas))
    print("  cobertura sobre os lemas:")
    print("    pronúncia  %5s%%" % cobertura["f"])
    print("    etimologia %5s%%" % cobertura["e"])
    print("    sinônimos  %5s%%" % cobertura["s"])
    print("    antônimos  %5s%%" % cobertura["a"])
    print("    exemplo    %5s%%" % cobertura["x"])
    print("%d entradas sem definição e %d não-palavras descartadas." % (sem_definicao, descartadas))
    if cobertura["e"] < 1 or cobertura["s"] < 1:
        print("\nATENÇÃO: cobertura quase nula em algum campo. Veja o censo acima\n"
              "para descobrir sob qual chave o dado está vindo.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
