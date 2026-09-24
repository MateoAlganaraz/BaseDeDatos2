# Checklist verificable del TPI

| Punto solicitado | Evidencia en el repositorio |
|---|---|
| 1. Modelo ER | `tpi/docs/01_modelo_er.md`: diagrama, atributos, claves, cardinalidad y participación. |
| 2. Paso ER-relacional | `tpi/docs/02_modelo_relacional.md`: FKs 1:N y tabla intermedia N:M. |
| 3. 3FN/BCNF | `tpi/docs/03_normalizacion.md`: dependencias funcionales y justificación. |
| 4. DDL | `schema.sql` y `tpi/01_migracion_modelo_final.sql`. |
| 5. DML y consultas | `tp3/04_parte4_consultas.sql`, `tp4/01_consultas_analiticas.sql`, `tp4/03_specs_equivalencia.sql`. |
| 6. Vistas, funciones y procedimientos | `tp5/views.sql`, `tp5/materializadas.sql`, `tpi/02_objetos_programables.sql`. |
| 7. Reglas de negocio | CHECK/UNIQUE en `schema.sql`; trigger de vigencia y auditoría en `tpi/02_objetos_programables.sql`. |
| 8. Transacciones y concurrencia | `sql/03_laboratorio_concurrencia.sql`, `informe_concurrencia.md` y evidencia TPI. |
| 9. Borrado lógico | `deleted_at`, índices parciales y vistas en los scripts TPI; explicación en `docs/01_modelo_er.md`. |

El informe técnico solicitado por la cátedra se encuentra en `tpi/informe_tecnico_tpi.md`. Cada resultado declarado enlaza una salida de motor en `tpi/evidencia/`; no se sustituyen mediciones por estimaciones.
