USE cobis
GO

/* ============================================================
   Reverso: Eliminación de registros insertados previamente
   Archivo: cobis_reverso.sql
   ============================================================ */

-- ============================================================
-- Eliminación de errores en cl_errores
-- ============================================================

SELECT * FROM cl_errores WHERE numero in ( 169257,169258,169259,169260,169261,169262)

SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'cc_tipo_reserva')
GO
SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'ah_tipo_reserva')
GO

SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 're_estados_transicion')
GO

-- Error 169257
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169257)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169257
    PRINT '169257 eliminado correctamente'
END
GO

-- Error 169258
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169258)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169258
    PRINT '169258 eliminado correctamente'
END
GO

-- Error 169259
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169259)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169259
    PRINT '169259 eliminado correctamente'
END
GO

-- Error 169260
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169260)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169260
    PRINT '169260 eliminado correctamente'
END
GO

-- Error 169261
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169261)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169261
    PRINT '169261 eliminado correctamente'
END
GO

-- Error 169261
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169262)
BEGIN
    DELETE FROM cl_errores WHERE numero = 169262
    PRINT '169262 eliminado correctamente'
END
GO
/* ============================================================
   Reverso: Eliminación en catálogos (ahorros y corrientes)
   ============================================================ */

DECLARE
    @w_tabla   SMALLINT,
    @w_descrip VARCHAR(100)

SET @w_descrip = '01 DIAS DE RESERVA PIGNORACION'

-- Catálogo de Ahorros
SELECT @w_tabla = codigo
FROM cobis..cl_tabla
WHERE tabla = 'ah_tipo_reserva'

IF EXISTS (SELECT 1 FROM cobis..cl_catalogo WHERE tabla = @w_tabla AND codigo = 'P')
BEGIN
    DELETE FROM cobis..cl_catalogo
    WHERE tabla  = @w_tabla
      AND codigo = 'P'

    PRINT 'Registro eliminado de ah_tipo_reserva'
END


-- Catálogo de Corrientes
SELECT @w_tabla = codigo
FROM cobis..cl_tabla
WHERE tabla = 'cc_tipo_reserva'

IF EXISTS (SELECT 1 FROM cobis..cl_catalogo WHERE tabla = @w_tabla AND codigo = 'P')
BEGIN
    DELETE FROM cobis..cl_catalogo
    WHERE tabla  = @w_tabla
      AND codigo = 'P'

    PRINT 'Registro eliminado de cc_tipo_reserva'
END
GO

/* ============================================================
   Reverso: Eliminación en parámetros
   ============================================================ */

IF EXISTS (SELECT 1 FROM cobis..cl_parametro WHERE pa_nemonico = 'MULRET' AND pa_producto = 'CTE')
BEGIN
    DELETE FROM cobis..cl_parametro
    WHERE pa_nemonico = 'MULRET'
      AND pa_producto = 'CTE'

    PRINT 'Parámetro MULRET eliminado correctamente'
END
GO


SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'cc_tipo_reserva')
GO
SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 'ah_tipo_reserva')
GO
SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 're_estados_transicion')
GO

SELECT * FROM cl_errores WHERE numero in ( 169257,169258,169259,169260,169261,169262)
go


