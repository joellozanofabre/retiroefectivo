USE cobis
GO

/* ============================================================
   Inserts idempotentes en cl_errores
   ============================================================ */

-- Error 208110
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208110)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 208110 , 0        , 'YA TIENE UN CUPON VIGENTE. SOLO SE PERMITE UN CUPON A LA VEZ' )

    PRINT '208110 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 208110 ya existe, no se realiza ninguna acción'
END
GO

-- Error 208111
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208111)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 208111 , 0        , 'ERROR AL INSERTAR EN TABLA RE_RETIRO_EFECTIVO.' )

    PRINT '208111 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 208111 ya existe, no se realiza ninguna acción'
END
GO

-- Error 208112
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208112)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 208112 , 0        , 'ERROR AL INSERTAR EN TABLA RE_HIS_RETIRO_EFECTIVO.' )

    PRINT '208112 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 208112 ya existe, no se realiza ninguna acción'
END
GO

-- Error 208113
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208113)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 208113 , 0        , 'NO SE ENCONTRO EL NUMERO DE RESERVA.' )

    PRINT '208113 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 208113 ya existe, no se realiza ninguna acción'
END
GO

-- Error 208114
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208114)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 208114 , 0        , 'CUPON YA HA SIDO DESPIGNORADO.' )

    PRINT '208114 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 208114 ya existe, no se realiza ninguna acción'
END
GO

/* ============================================================
   Inserción en catálogos (ahorros y corrientes)
   ============================================================ */

DECLARE 
    @w_tabla   SMALLINT,
    @siguiente SMALLINT,
    @w_descrip VARCHAR(100)

SET @w_descrip = '01 DIAS DE RESERVA PIGNORACION'

-- Catálogo de Ahorros
SELECT @w_tabla = codigo
FROM cobis..cl_tabla
WHERE tabla = 'ah_tipo_reserva'

DELETE FROM cobis..cl_catalogo
WHERE tabla  = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'ah_tipo_reserva')
  AND codigo = 'P'

INSERT INTO cobis..cl_catalogo ( tabla     , codigo , valor       , estado )
VALUES                         ( @w_tabla  , 'P'    , @w_descrip  , 'V'    )

SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'ah_tipo_reserva')


-- Catálogo de Corrientes
SELECT @w_tabla = codigo
FROM cobis..cl_tabla
WHERE tabla = 'cc_tipo_reserva'

DELETE FROM cobis..cl_catalogo
WHERE tabla  = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'cc_tipo_reserva')
  AND codigo = 'P'

INSERT INTO cobis..cl_catalogo ( tabla     , codigo , valor       , estado )
VALUES                         ( @w_tabla  , 'P'    , @w_descrip  , 'V'    )
GO

SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'cc_tipo_reserva')
GO


