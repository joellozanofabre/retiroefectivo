USE cobis
GO

/* ============================================================
   Reverso: Eliminación de registros insertados previamente
   Archivo: cobis_reverso.sql
   ============================================================ */

-- ============================================================
-- Eliminación de errores en cl_errores
-- ============================================================

-- Error 208110
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208110)
BEGIN
    DELETE FROM cl_errores WHERE numero = 208110
    PRINT '208110 eliminado correctamente'
END
GO

-- Error 208111
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208111)
BEGIN
    DELETE FROM cl_errores WHERE numero = 208111
    PRINT '208111 eliminado correctamente'
END
GO

-- Error 208112
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208112)
BEGIN
    DELETE FROM cl_errores WHERE numero = 208112
    PRINT '208112 eliminado correctamente'
END
GO

-- Error 208113
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208113)
BEGIN
    DELETE FROM cl_errores WHERE numero = 208113
    PRINT '208113 eliminado correctamente'
END
GO

-- Error 208114
IF EXISTS (SELECT 1 FROM cl_errores WHERE numero = 208114)
BEGIN
    DELETE FROM cl_errores WHERE numero = 208114
    PRINT '208114 eliminado correctamente'
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
