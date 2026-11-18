from modules.maintenance_execution.application.solution_matching import opposite_polarity, rank_case, tokens
from modules.maintenance_execution.infrastructure.postgres.solution_cases import documentary_outcome


def case(problem, **updates):
    return {"problem": problem, "search_text": problem, "asset_ids": [], "type_keys": [],
            "subsystem": "ATS", "outcome": "UNVALIDATED", **updates}


def test_aliases_accents_and_typos():
    assert tokens("Intermiténcia de enlace") == {"intermitencia", "comunicacion"}
    assert rank_case(case("Intermitencia de comunicación"), "pierde enlace por ratos")[0] > 0
    assert rank_case(case("Intermitencia de comunicación"), "intermitensia")[0] > 0
    assert rank_case(case("Batería descargada"), "intermitencia de comunicación")[0] == 0


def test_negation_and_context_do_not_override_unrelated_problem():
    assert opposite_polarity("sin alimentación", "alimentación correcta")
    assert rank_case(case("alimentación correcta"), "sin alimentación")[0] == 0
    assert rank_case(case("alimentación correcta"), "sin energía")[0] == 0
    assert rank_case(case("Alarma ALM-1235"), "ALM-1234")[0] == 0
    context = {"asset_ids": ["a"], "subsystem": "ATS"}
    assert rank_case(case("Batería descargada", asset_ids=["a"]), "pérdida comunicación", context)[0] == 0
    assert rank_case(case("Batería descargada", asset_ids=["a"]), "", context)[0] > 0


def test_closed_is_not_validated_and_inoperative_is_not_resolved():
    source = {"finalized": True, "principal": True, "searchable": True, "validation": "Conforme",
              "technical_status": "Inoperativo", "service_released": True, "tests": "Prueba realizada"}
    assert documentary_outcome("COMPLETED", [source]) == "UNVALIDATED"
    source["technical_status"] = "Operativo"
    assert documentary_outcome("COMPLETED", [source]) == "VALIDATED"
    assert documentary_outcome("IN_PROGRESS", [source]) == "PENDING"
    source["tests"] = ""
    assert documentary_outcome("CLOSED", [source]) == "UNVALIDATED"
    source["tests"] = "No se pudo validar el enlace"
    assert documentary_outcome("CLOSED", [source]) == "UNVALIDATED"
    assert documentary_outcome("CLOSED", []) == "UNDOCUMENTED"
