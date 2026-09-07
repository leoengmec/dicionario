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

