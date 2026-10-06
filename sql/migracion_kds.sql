-- =====================================================================
--  SazónTrack / KDS - Migración necesaria para conectar la app a la BD
--  Es IDEMPOTENTE: se puede ejecutar varias veces sin romper nada.
--  Además api/config.php la ejecuta sola la primera vez (ver README_API.md).
--  Base de datos: PostgreSQL (probada contra el esquema de sazontrack_db2)
-- =====================================================================

-- 1) Sesiones de la API (token que se entrega al iniciar sesión con PIN)
CREATE TABLE IF NOT EXISTS public.api_tokens (
    token_hash  character varying(64) PRIMARY KEY,
    id_usuario  integer NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    creado_en   timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en   timestamp without time zone NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_api_tokens_expira ON public.api_tokens (expira_en);

-- 2) Detalle de las órdenes (platillos de cada comanda). No existía en el esquema.
CREATE TABLE IF NOT EXISTS public.orden_detalle (
    id_detalle       serial PRIMARY KEY,
    id_orden         integer NOT NULL REFERENCES public.ordenes(id_orden) ON DELETE CASCADE,
    id_producto      integer REFERENCES public.productos(id_producto) ON DELETE SET NULL,
    nombre_producto  character varying(100) NOT NULL,
    cantidad         integer NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    precio_unitario  numeric(10,2) NOT NULL DEFAULT 0.00,
    notas            text,
    estacion         character varying(20) NOT NULL DEFAULT 'cocina',
    -- PENDIENTE -> EN_PREPARACION -> LISTO -> ENTREGADO  (o CANCELADO)
    estado           character varying(20) NOT NULL DEFAULT 'PENDIENTE',
    enviado_en       timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    iniciado_en      timestamp without time zone,
    listo_en         timestamp without time zone,
    entregado_en     timestamp without time zone
);
CREATE INDEX IF NOT EXISTS idx_orden_detalle_orden  ON public.orden_detalle (id_orden);
CREATE INDEX IF NOT EXISTS idx_orden_detalle_estado ON public.orden_detalle (estado);

-- 3) Columnas nuevas en tablas existentes
ALTER TABLE public.ordenes ADD COLUMN IF NOT EXISTS comensales   integer DEFAULT 1;
ALTER TABLE public.mesas   ADD COLUMN IF NOT EXISTS grupo_union  integer;   -- mesas unidas comparten valor

-- 4) Normalización de datos de mesas (había 'LIBRE' y 'disponible', y mesas sin área)
UPDATE public.mesas SET estado = 'disponible' WHERE lower(estado) = 'libre';
UPDATE public.mesas
   SET id_area = COALESCE(area_id, (SELECT MIN(id_area) FROM public.areas))
 WHERE id_area IS NULL;
UPDATE public.mesas SET numero = numero_mesa WHERE numero IS NULL;

-- 5) Re-sincronizar secuencias con los datos reales.
--    (En el dump, areas_id_area_seq quedó en 1 con 3 filas existentes: al crear
--     un área nueva fallaba por clave duplicada.)
DO $$
DECLARE
    r   record;
    seq text;
    mx  bigint;
    lv  bigint;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            ('areas','id_area'), ('categorias','id_categoria'), ('mesas','id_mesa'),
            ('productos','id_producto'), ('ordenes','id_orden'), ('pagos','id_pago'),
            ('reservas','id_reserva'), ('turnos_caja','id_turno')
        ) AS t(tbl, col)
    LOOP
        seq := pg_get_serial_sequence('public.' || r.tbl, r.col);
        IF seq IS NOT NULL THEN
            EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM public.%I', r.col, r.tbl) INTO mx;
            EXECUTE format('SELECT last_value FROM %s', seq) INTO lv;
            IF mx >= lv AND mx > 0 THEN
                PERFORM setval(seq, mx, true);
            END IF;
        END IF;
    END LOOP;
END
$$;
