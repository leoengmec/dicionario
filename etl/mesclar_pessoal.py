#!/usr/bin/env python3
"""
Mescla etl/meus-verbetes.txt no léxico em data/, sem tocar no dump.

Idempotente: a cada execução remove tudo o que foi marcado como pessoal
na rodada anterior e aplica o arquivo de novo. Apagar um bloco do .txt e
rodar de novo remove o verbete.

    python3 etl/mesclar_pessoal.py
"""

import json
import os
import re
import sys
import unicodedata

RAIZ = os.path.dirname(os.path.abspath(__file__))
ENTRADA = os.path.join(RAIZ, "meus-verbetes.txt")
DADOS = os.path.normpath(os.path.join(RAIZ, "..", "data"))
PASTA = os.path.join(DADOS, "verbetes")

CAMPOS = {"palavra", "classe", "def", "sin", "ant", "ex", "etim", "pron"}


def sem_acento(texto):
    d = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in d if unicodedata.category(c) != "Mn")


def chave_fatia(palavra):
    base = re.sub(r"[^a-z0-9]", "", sem_acento(palavra))
    if not base:
        return "_"
    return base[:2] if len(base) > 1 else base + "_"


def lista(valor):
    return [p.strip() for p in valor.split(";") if p.strip()]


def ler_blocos(caminho):
    """Devolve lista de dicionários, um por bloco, com avisos por linha."""
    blocos, atual, avisos = [], {}, []
    if not os.path.exists(caminho):
        return blocos, avisos
    with open(caminho, encoding="utf-8") as f:
        for n, linha in enumerate(f, 1):
            linha = linha.rstrip("\n")
            if linha.strip().startswith("#"):
                continue
            if not linha.strip():
                if atual:
                    blocos.append(atual)
                    atual = {}
                continue
            if ":" not in linha:
                avisos.append("linha %d: sem ':' — ignorada: %s" % (n, linha[:50]))
                continue
            chave, _, valor = linha.partition(":")
            chave, valor = chave.strip().lower(), valor.strip()
            if chave not in CAMPOS:
                avisos.append("linha %d: campo desconhecido '%s' — ignorado" % (n, chave))
                continue
            if chave == "def":
                atual.setdefault("def", []).append(valor)
            else:
                atual[chave] = valor
    if atual:
        blocos.append(atual)

    validos = []
    for b in blocos:
        if not b.get("palavra"):
            avisos.append("bloco sem 'palavra' — ignorado")
        elif not b.get("def"):
            avisos.append("'%s' sem nenhuma 'def' — ignorado" % b["palavra"])
        else:
            validos.append(b)
    return validos, avisos


def carregar_fatia(chave):
    caminho = os.path.join(PASTA, chave + ".json")
    if os.path.exists(caminho):
        with open(caminho, encoding="utf-8") as f:
            return json.load(f)
    return []


def salvar_fatia(chave, registros):
    caminho = os.path.join(PASTA, chave + ".json")
    if not registros:
        if os.path.exists(caminho):
            os.remove(caminho)
        return
    registros.sort(key=lambda r: sem_acento(r["w"]))
    with open(caminho, "w", encoding="utf-8") as f:
        json.dump(registros, f, ensure_ascii=False, separators=(",", ":"))


def limpar_pessoal(registro):
    """Remove o que a rodada anterior marcou como pessoal. True se sobrou algo."""
    if not registro.get("p"):
        return True
    registro["c"] = [b for b in registro.get("c", []) if not b.get("p")]
    for campo in ("s", "a"):
        if campo in registro:
            base = [x for x in registro[campo] if x not in registro.get("p", {}).get(campo, [])]
            if base:
                registro[campo] = base
            else:
                del registro[campo]
    for campo in ("x", "e", "f"):
        original = registro["p"].get("orig_" + campo)
        if original is not None:
            if original == "":
                registro.pop(campo, None)
            else:
                registro[campo] = original
    del registro["p"]
    return bool(registro.get("c") or registro.get("r"))


def aplicar(registro, bloco):
    marca = {}
    novo = {"g": bloco.get("classe", ""), "d": bloco["def"], "p": True}
    registro["c"] = [novo] + registro.get("c", [])
    registro.pop("r", None)

    for campo, chave in (("s", "sin"), ("a", "ant")):
        adicionais = lista(bloco.get(chave, ""))
        if adicionais:
            atuais = registro.get(campo, [])
            somados = [x for x in adicionais if x not in atuais]
            registro[campo] = somados + atuais
            marca[campo] = somados

    for campo, chave in (("x", "ex"), ("e", "etim"), ("f", "pron")):
        valor = bloco.get(chave, "").strip()
        if valor:
            marca["orig_" + campo] = registro.get(campo, "")
            registro[campo] = valor

    registro["p"] = marca


def main():
    if not os.path.isdir(PASTA):
        print("data/verbetes não existe; rode o ETL antes.", file=sys.stderr)
        return 1

    blocos, avisos = ler_blocos(ENTRADA)
    for a in avisos:
        print("aviso:", a)

    # 1. limpa a rodada anterior em todas as fatias
    removidos = 0
    for nome in os.listdir(PASTA):
        if not nome.endswith(".json"):
            continue
        chave = nome[:-5]
        regs = carregar_fatia(chave)
        if not any(r.get("p") for r in regs):
            continue
        mantidos = []
        for r in regs:
            if limpar_pessoal(r):
                mantidos.append(r)
            else:
                removidos += 1
        salvar_fatia(chave, mantidos)

    # 2. aplica os blocos atuais
    por_fatia = {}
    for b in blocos:
        por_fatia.setdefault(chave_fatia(b["palavra"]), []).append(b)

    novos = mesclados = 0
    for chave, lista_blocos in por_fatia.items():
        regs = carregar_fatia(chave)
        indice = {r["w"]: r for r in regs}
        for b in lista_blocos:
            palavra = b["palavra"]
            if palavra in indice:
                aplicar(indice[palavra], b)
                mesclados += 1
            else:
                r = {"w": palavra, "c": []}
                aplicar(r, b)
                regs.append(r)
                indice[palavra] = r
                novos += 1
        salvar_fatia(chave, regs)

    # 3. reconstrói o índice a partir das fatias
    palavras = set()
    for nome in os.listdir(PASTA):
        if nome.endswith(".json"):
            palavras.update(r["w"] for r in carregar_fatia(nome[:-5]))
    ordenado = sorted(palavras, key=lambda p: (sem_acento(p), p))
    with open(os.path.join(DADOS, "indice.json"), "w", encoding="utf-8") as f:
        json.dump(ordenado, f, ensure_ascii=False, separators=(",", ":"))

    # 4. meta
    meta_path = os.path.join(DADOS, "meta.json")
    with open(meta_path, encoding="utf-8") as f:
        meta = json.load(f)
    meta["pessoais"] = len(blocos)
    meta["verbetes"] = len(ordenado)
    meta["fatias"] = sorted(n[:-5] for n in os.listdir(PASTA) if n.endswith(".json"))
    meta["bytes_verbetes"] = sum(
        os.path.getsize(os.path.join(PASTA, n)) for n in os.listdir(PASTA) if n.endswith(".json"))
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)

    print("verbetes pessoais: %d (%d novos, %d mesclados a verbetes do Wikcionário, %d removidos)"
          % (len(blocos), novos, mesclados, removidos))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
