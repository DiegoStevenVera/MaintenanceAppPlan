from uuid import UUID, uuid5

IMPORT_NAMESPACE = UUID("6db174f8-f9ec-4dd2-bf4c-9fc93c728299")


def stable_uuid(*parts: object) -> UUID:
    key = "|".join(str(part).strip() for part in parts)
    return uuid5(IMPORT_NAMESPACE, key)


def stable_string_id(*parts: object) -> str:
    return str(stable_uuid(*parts))

