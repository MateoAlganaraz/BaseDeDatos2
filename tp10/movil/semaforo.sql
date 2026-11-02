PRAGMA foreign_keys = ON;
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP N.º 8 (Unidad 8) - Consigna 2.b: el semáforo.
--
--   cd tp10/movil
--   sqlite3 foodstore_movil.db < semaforo.sql
--
-- Compara cada solicitud PENDIENTE con la última instantánea (snapshot_servidor) y guarda
-- en cola_sync el estado y el motivo:
--   Rojo     RECHAZADO          algún producto no existe, no está disponible, fue dado de baja
--                               o no alcanza el stock (o el borrador no tiene ítems).
--   Amarillo CONFLICTO          no hay rojo, pero cambió algún precio.
--   Verde    SIMULADO_APROBADO  todo coincide. Es una simulación: NO es una venta.
--
-- Solo se evalúan las solicitudes PENDIENTE: repetir la simulación no cambia nada.
-- No escribe en PostgreSQL ni modifica borradores, ítems ni el catálogo.
-- =====================================================================

BEGIN;

UPDATE cola_sync
SET estado      = r.estado,
    motivo      = r.motivo,
    evaluada_en = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
FROM (
    SELECT c.solicitud_uuid,
           CASE
               WHEN count(i.producto_id) = 0 THEN 'RECHAZADO'
               WHEN sum(s.id IS NULL OR s.disponible <> 't' OR s.eliminado <> 'f'
                        OR i.cantidad > s.stock) > 0 THEN 'RECHAZADO'
               WHEN sum(i.precio_centavos_visto <> s.precio_centavos) > 0 THEN 'CONFLICTO'
               ELSE 'SIMULADO_APROBADO'
           END AS estado,
           CASE
               WHEN count(i.producto_id) = 0 THEN 'borrador sin ítems'
               ELSE group_concat(
                   CASE
                       WHEN s.id IS NULL           THEN 'producto ' || i.producto_id || ': no existe en el servidor'
                       WHEN s.eliminado <> 'f'     THEN 'producto ' || i.producto_id || ': dado de baja'
                       WHEN s.disponible <> 't'    THEN 'producto ' || i.producto_id || ': no disponible'
                       WHEN i.cantidad > s.stock   THEN 'producto ' || i.producto_id || ': pide '
                                                        || i.cantidad || ', stock ' || s.stock
                       WHEN i.precio_centavos_visto <> s.precio_centavos
                                                   THEN 'producto ' || i.producto_id || ': precio visto '
                                                        || i.precio_centavos_visto || ', actual '
                                                        || s.precio_centavos || ' (centavos)'
                   END, '; ')
           END AS motivo
    FROM cola_sync c
    LEFT JOIN item_borrador i     ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
) AS r
WHERE cola_sync.solicitud_uuid = r.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';

SELECT 'solicitudes evaluadas en esta corrida' AS semaforo, changes() AS cantidad;

COMMIT;

.headers on
.mode column
SELECT c.solicitud_uuid, c.estado, coalesce(c.motivo, '') AS motivo, c.evaluada_en,
       (SELECT max(copiado_en) FROM snapshot_servidor) AS contra_snapshot
FROM cola_sync c
ORDER BY c.solicitud_uuid;
