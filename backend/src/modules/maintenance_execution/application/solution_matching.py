"""Deterministic documentary retrieval; scores are relevance, never diagnosis confidence."""

import re
import unicodedata
from difflib import SequenceMatcher

STOP = set("de del el la los las un una en por para con que se al y o es esta este tiene a".split())
# Initial aliases are deliberately small and inspectable; expand only after field review.
ALIASES = {
    "por ratos": "intermitencia", "a veces": "intermitencia", "intermitente": "intermitencia",
    "intermitencias": "intermitencia", "enlace": "comunicacion", "conexion": "comunicacion",
    "energia": "alimentacion", "voltaje": "tension", "reinicio": "reiniciar",
}


def normalized(value: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", value.casefold())
                   if unicodedata.category(c) != "Mn")


def canonical(value: str) -> str:
    text = normalized(value)
    for original, canonical in ALIASES.items():
        text = re.sub(r"\b" + re.escape(original) + r"\b", canonical, text)
    return text


def tokens(value: str) -> set[str]:
    text = canonical(value)
    return {word for word in re.findall(r"[a-z0-9]+(?:[-_/][a-z0-9]+)*", text) if word not in STOP}


def opposite_polarity(query: str, problem: str) -> bool:
    q, p = canonical(query), canonical(problem)
    for topic in ("alimentacion", "comunicacion", "tension", "senal"):
        negative = rf"(?:sin|no hay|ausencia de|falta de)\s+{topic}"
        positive = rf"{topic}\s+(?:correcta|correcto|normal|presente|estable)"
        if ((re.search(negative, q) and re.search(positive, p) and not re.search(negative, p))
                or (re.search(positive, q) and re.search(negative, p) and not re.search(positive, p))):
            return True
    return False


def rank_case(case: dict, query: str, context: dict | None = None) -> tuple[float, list[str]]:
    context = context or {}
    terms = tokens(query)
    problem = case["problem"]
    source = case["search_text"]
    words = tokens(source)
    reasons = []
    if terms and opposite_polarity(query, problem):
        return 0, []
    matched = terms & words
    if any(any(c.isdigit() for c in term) for term in terms - matched):
        return 0, []
    exact = normalized(query).strip() in normalized(source) if query.strip() else False
    fuzzy = sum(any(SequenceMatcher(None, term, word).ratio() >= 0.86
                    for word in words if len(word) >= 5 and abs(len(term) - len(word)) <= 2)
                for term in terms - matched if len(term) >= 5) if len(terms) <= 12 else 0
    lexical = (len(matched) + fuzzy * 0.45) / max(len(terms), 1)
    # Context may retrieve antecedents when there is no description, not override unrelated text.
    if terms and not exact and lexical < 0.28:
        return 0, []
    score = lexical * 10 + (4 if exact else 0)
    if matched:
        reasons.append("Coincidencias técnicas: " + ", ".join(sorted(matched)[:6]))
    elif fuzzy:
        reasons.append("Coincidencia aproximada de escritura")
    if set(case["asset_ids"]) & set(context.get("asset_ids", [])):
        score += 3
        reasons.append("Antecedente del mismo equipo o componente")
    elif set(case["type_keys"]) & set(context.get("type_keys", [])):
        score += 1.5
        reasons.append("Tipo de equipo o componente comparable")
    if case["subsystem"] == context.get("subsystem"):
        score += 0.5
        reasons.append("Mismo subsistema")
    if case["outcome"] == "VALIDATED":
        score += 0.6
    if not reasons:
        reasons.append("Historial documental disponible" if not terms else "Coincidencia de texto")
    return score + (0.01 if not terms else 0), reasons
