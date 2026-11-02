PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C6: la tablet reenvía la misma solicitud de C5 (mismo UUID), por ejemplo tras un corte.
-- Error esperado: UNIQUE/PRIMARY KEY sobre cola_sync.solicitud_uuid. No se duplica.
SELECT count(*) AS solicitudes_antes FROM cola_sync;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c5000000-0000-4000-9000-000000000001', 'c5000000-0000-4000-8000-000000000001');
SELECT count(*) AS solicitudes_despues FROM cola_sync;
SELECT solicitud_uuid, estado, evaluada_en FROM cola_sync
WHERE solicitud_uuid = 'c5000000-0000-4000-9000-000000000001';
