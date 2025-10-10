USE cobis
GO

/* ============================================================
   Inserts idempotentes en cl_errores
   ============================================================ */

-- Error 169257
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169257)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169257 , 0        , 'YA TIENE UN CUPON VIGENTE. SOLO SE PERMITE UN CUPON A LA VEZ' )

    PRINT '169257 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 169257 ya existe, no se realiza ninguna acción'
END
GO

-- Error 169258
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169258)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169258 , 0        , 'ERROR AL INSERTAR EN TABLA RE_RETIRO_EFECTIVO.' )

    PRINT '169258 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 169258 ya existe, no se realiza ninguna acción'
END
GO

-- Error 169259
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169259)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169259 , 0        , 'ERROR AL INSERTAR EN TABLA RE_HIS_RETIRO_EFECTIVO.' )

    PRINT '169259 insertado correctamente.'
END
ELSE
BEGIN
    PRINT 'Error 169259 ya existe, no se realiza ninguna acción'
END
GO

-- Error 169260
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169260)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169260 , 0        , 'NO SE ENCONTRO EL NUMERO DE RESERVA.' )

    PRINT '169260 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 169260 ya existe, no se realiza ninguna acción'
END
GO

-- Error 169261
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169261)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169261 , 0        , 'CUPON YA HA SIDO DESPIGNORADO.' )

    PRINT '169261 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 169261 ya existe, no se realiza ninguna acción'
END
GO

-- Error 169261
IF NOT EXISTS (SELECT 1 FROM cl_errores WHERE numero = 169262)
BEGIN
    INSERT INTO cl_errores ( numero , severidad , mensaje )
    VALUES                  ( 169262 , 0        , 'NO SE HA PODIDO ACTUALIZAR TABLA re_retiro_efectivo.' )

    PRINT '169262 insertado correctamente'
END
ELSE
BEGIN
    PRINT 'Error 169262 ya existe, no se realiza ninguna acción'
END
GO



SELECT * FROM cl_errores WHERE numero in ( 169257,169258,169259,169260,169261,169262)



/* ============================================================
   Inserción en catálogos (ahorros y corrientes)
   para visualizar en frontend tadmin.
   ============================================================ */

DECLARE
    @w_tabla   SMALLINT,
    @siguiente SMALLINT,
    @w_descrip VARCHAR(100)

SET @w_descrip = '01 DIAS RESERVA PIGNORACION'

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



delete cl_catalogo_pro
    where cp_tabla  in (select codigo from cl_tabla where tabla = 're_estados_transicion')


delete cobis..cl_catalogo
where tabla in (select codigo from cl_tabla where tabla = 're_estados_transicion')

delete cobis..cl_tabla
where codigo in (select codigo from cl_tabla where tabla = 're_estados_transicion')



declare @w_codigo int
select @w_codigo = siguiente + 1
  from cl_seqnos
 where tabla = 'cl_tabla'

insert into cl_tabla values (@w_codigo, 're_estados_transicion', 'Estados de transicion para procesos Retiro Efectivo')


insert into cl_catalogo_pro values ('G', @w_codigo)
insert into cl_catalogo_pro values ('V', @w_codigo)
insert into cl_catalogo_pro values ('X', @w_codigo)
insert into cl_catalogo_pro values ('U', @w_codigo)
insert into cl_catalogo_pro values ('N', @w_codigo)
insert into cl_catalogo_pro values ('E', @w_codigo)

insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'ANULADO'  ,'N','V')
insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'EXPIRADO' ,'X','V')
insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'ERROR'    ,'E','V')
insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'GENERADO' ,'G','V')
insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'USADO'    ,'U','V')
insert into cl_catalogo (tabla,valor,codigo,estado) values (@w_codigo,'VALIDANDO','V','V')



update cobis..cl_seqnos     set siguiente = @w_codigo     where tabla = 'cl_tabla'


SELECT *
FROM cobis..cl_catalogo
WHERE tabla = (SELECT codigo FROM cobis..cl_tabla WHERE tabla = 're_estados_transicion')
GO

select * from cobis..cl_catalogo_pro
where cp_tabla = (select codigo from cobis..cl_tabla where tabla = 're_estados_transicion')
go