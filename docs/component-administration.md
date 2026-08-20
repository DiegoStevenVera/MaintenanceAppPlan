# Administración Manual De Componentes

La aplicación ofrece administración transaccional de componentes para usuarios
Administradores. Estas consultas son una alternativa controlada para corregir
datos durante desarrollo o una carga inicial. Realiza primero una copia de la
base de datos y ejecuta cada cambio dentro de una transacción.

## Consultas De Lectura

### Encontrar un equipo grande

```sql
SELECT id, name, subsystem, category, asset_type, physical_location
FROM assets
WHERE is_business_anchor = true
  AND name ILIKE '%ZC4%'
ORDER BY name;
```

### Ver toda la jerarquía de un equipo

```sql
WITH root AS (
    SELECT id, name FROM assets
    WHERE id = 'REEMPLAZAR_CON_ID_DEL_EQUIPO'
)
SELECT
    closure.depth AS nivel,
    child.id,
    child.name,
    child.category,
    child.asset_type,
    child.serial_number,
    parent.name AS padre_directo,
    child.current_position
FROM root
JOIN asset_closure closure
  ON closure.ancestor_asset_id = root.id
 AND closure.depth > 0
JOIN assets child ON child.id = closure.descendant_asset_id
LEFT JOIN assets parent ON parent.id = child.parent_id
ORDER BY closure.depth, parent.name NULLS FIRST, child.name;
```

### Ver solo los componentes directos

```sql
SELECT id, name, asset_type, serial_number, part_number, model, status
FROM assets
WHERE parent_id = 'REEMPLAZAR_CON_ID_DEL_PADRE'
ORDER BY name;
```

## Crear Un Componente Directo

Reemplaza el ID del padre y los valores del bloque `VALUES`. La consulta crea
el activo, sus rutas de cierre y actualiza `children` del padre.

```sql
BEGIN;

WITH parent AS (
    SELECT * FROM assets WHERE id = 'REEMPLAZAR_CON_ID_DEL_PADRE'
), inserted AS (
    INSERT INTO assets (
        id, name, category, asset_type, subsystem, serial_or_code,
        part_number, status, physical_location, is_business_anchor,
        parent_id, children, equipment_category_id, equipment_kind_id,
        subsystem_id, current_geographic_location_id, internal_code,
        serial_number, serial_number_status, model, business_label,
        registration_method, is_mobile
    )
    SELECT
        gen_random_uuid()::text,
        'NOMBRE DEL COMPONENTE',
        'Componente',
        'TIPO DEL COMPONENTE',
        parent.subsystem,
        COALESCE(NULLIF('NUMERO_DE_SERIE', ''), 'ADM-MANUAL'),
        NULLIF('PART NUMBER', ''),
        'OPERATIVO',
        parent.physical_location,
        false,
        parent.id,
        '[]'::jsonb,
        parent.equipment_category_id,
        parent.equipment_kind_id,
        parent.subsystem_id,
        parent.current_geographic_location_id,
        'ADM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
        NULLIF('NUMERO_DE_SERIE', ''),
        CASE WHEN NULLIF('NUMERO_DE_SERIE', '') IS NULL THEN 'NOT_CAPTURED' ELSE 'KNOWN' END,
        NULLIF('MODELO', ''),
        'Componente',
        'MANUAL',
        false
    FROM parent
    RETURNING id, parent_id
), closure_rows AS (
    INSERT INTO asset_closure (ancestor_asset_id, descendant_asset_id, depth)
    SELECT ancestor_asset_id, inserted.id, depth + 1
    FROM asset_closure
    JOIN inserted ON asset_closure.descendant_asset_id = inserted.parent_id
    UNION ALL
    SELECT id, id, 0 FROM inserted
    ON CONFLICT (ancestor_asset_id, descendant_asset_id)
    DO UPDATE SET depth = EXCLUDED.depth
)
UPDATE assets parent
SET children = COALESCE(
    (SELECT jsonb_agg(child.name ORDER BY child.name)
     FROM assets child WHERE child.parent_id = parent.id),
    '[]'::jsonb
)
WHERE parent.id = (SELECT parent_id FROM inserted);

COMMIT;
```

## Mover Un Componente

Para preservar coherencia, mueve solo el componente y luego reconstruye la
tabla de cierre. Si tiene hijos, estos permanecen bajo él.

```sql
BEGIN;

WITH destination AS (
    SELECT * FROM assets WHERE id = 'ID_EQUIPO_DESTINO'
), moved_tree AS (
    SELECT descendant_asset_id
    FROM asset_closure
    WHERE ancestor_asset_id = 'ID_COMPONENTE'
)
UPDATE assets component
SET subsystem = destination.subsystem,
    subsystem_id = destination.subsystem_id,
    physical_location = destination.physical_location,
    current_geographic_location_id = destination.current_geographic_location_id,
    parent_id = CASE WHEN component.id = 'ID_COMPONENTE' THEN destination.id ELSE component.parent_id END,
    updated_at = now()
FROM destination, moved_tree
WHERE component.id = moved_tree.descendant_asset_id;

DELETE FROM asset_closure;
WITH RECURSIVE hierarchy AS (
    SELECT id AS ancestor_asset_id, id AS descendant_asset_id, 0 AS depth FROM assets
    UNION ALL
    SELECT hierarchy.ancestor_asset_id, child.id, hierarchy.depth + 1
    FROM hierarchy JOIN assets child ON child.parent_id = hierarchy.descendant_asset_id
)
INSERT INTO asset_closure (ancestor_asset_id, descendant_asset_id, depth)
SELECT ancestor_asset_id, descendant_asset_id, MIN(depth)
FROM hierarchy
GROUP BY ancestor_asset_id, descendant_asset_id;

UPDATE assets parent
SET children = COALESCE(
    (SELECT jsonb_agg(child.name ORDER BY child.name)
     FROM assets child WHERE child.parent_id = parent.id),
    '[]'::jsonb
);

COMMIT;
```

No elimines por SQL un componente con reportes, movimientos o reemplazos
históricos: PostgreSQL debe rechazarlo para conservar trazabilidad.
