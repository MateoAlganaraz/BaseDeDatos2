# Tasks - Food Store en la feria

- [x] 1. Crear `movil/schema_sqlite.sql`: cuatro tablas STRICT con sus CHECK y FK, `snapshot_servidor` y `catalogo_disponible`. Comienza con `PRAGMA foreign_keys = ON;`. _(REQ-04)_
- [x] 2. Crear `servidor/01_v_snapshot_movil.sql`: la vista con lápidas y la línea base de pedidos y stock. _(REQ-02, transversal)_
- [x] 3. Crear `movil/cargar_snapshot.sql`: `.import` del CSV y UPSERT en `producto_cache`. _(REQ-02)_
- [x] 4. Crear `movil/pruebas_sqlite.sql`: `BEGIN … COMMIT`, `ROLLBACK`, C1 y C7. _(REQ-04)_
- [x] 5. Crear `movil/semaforo.sql`: rojo, amarillo y verde, solo sobre `PENDIENTE`. _(REQ-01, REQ-02, REQ-03)_
- [x] 6. Crear los scripts de `movil/casos/` y de `servidor/` para C2 a C6, y `servidor/99_control_final.sql`. _(todos)_
- [x] 7. Crear `run_tp10.sh`, ejecutarlo desde cero y guardar la evidencia en `evidencia/`. Verificar que cada caso dé el resultado esperado y que PostgreSQL no cambie. _(todos)_
