-- Catalogo minimo de laboratorio para una copia creada solo con schema.sql.
-- No modifica practica_bd2: ejecutar unicamente en la copia TP3 vacia.
-- Si ya existe al menos una categoria, no inserta nada.
BEGIN;

INSERT INTO categoria (nombre, descripcion, activo)
SELECT semilla.nombre, semilla.descripcion, TRUE
FROM (
    VALUES
        ('Almacen', 'Catalogo inicial de laboratorio para TP3'),
        ('Bebidas', 'Catalogo inicial de laboratorio para TP3'),
        ('Limpieza', 'Catalogo inicial de laboratorio para TP3'),
        ('Perfumeria', 'Catalogo inicial de laboratorio para TP3'),
        ('Congelados', 'Catalogo inicial de laboratorio para TP3')
) AS semilla(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM categoria);

COMMIT;

SELECT id_categoria, nombre, activo
FROM categoria
ORDER BY id_categoria;
