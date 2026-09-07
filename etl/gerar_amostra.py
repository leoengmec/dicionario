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

