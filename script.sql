use cobis
go

-- Insert idempotente de un nuevo error
if not exists (select 1 from cl_errores where numero = 208110)
begin
    insert into cl_errores (numero, severidad, mensaje)
    values (208110, 0, 'YA TIENE UN CUPON VIGENTE. SOLO SE PERMITE UN CUPON A LA VEZ')
    
    print ' 208110 insertado correctamente'
end
else
begin
    print 'Error 208110 ya existe, no se realiza ninguna acción'
end

go

-- Insert idempotente de un nuevo error
if not exists (select 1 from cl_errores where numero = 208111)
begin
    insert into cl_errores (numero, severidad, mensaje)
    values (208111, 0, 'ERROR AL INSERTAR EN TABLA RE_RETIRO_EFECTIVO.')
    
    print '208111 insertado correctamente'
end
else
begin
    print 'Error 208111 ya existe, no se realiza ninguna acción'
end
go

-- Insert idempotente de un nuevo error
if not exists (select 1 from cl_errores where numero = 208112)
begin
    insert into cl_errores (numero, severidad, mensaje)
    values (208112, 0, 'ERROR AL INSERTAR EN TABLA RE_HIS_RETIRO_EFECTIVO.')
    
    print ' 208112 insertado correctamente'
end
else
begin
    print 'Error 208112 ya existe, no se realiza ninguna acción'
end
go


-- Insert idempotente de un nuevo error
if not exists (select 1 from cl_errores where numero = 208113)
begin
    insert into cl_errores (numero, severidad, mensaje)
    values (208113, 0, 'NO SE ENCONTRO EL NUMERO DE RESERVA.')
    
    print ' 208113 insertado correctamente'
end
else
begin
    print 'Error 208113 ya existe, no se realiza ninguna acción'
end
go
-- Insert idempotente de un nuevo error
if not exists (select 1 from cl_errores where numero = 208113)
begin
    insert into cl_errores (numero, severidad, mensaje)
    values (208114, 0, 'CUPON YA HA SIDO DESPIGNORADO.')
    
    print ' 208113 insertado correctamente'
end
else
begin
    print 'Error 208113 ya existe, no se realiza ninguna acción'
end
go




DECLARE  @w_tabla SMALLINT,@siguiente SMALLINT, @w_descrip varchar(100)

set @w_descrip = '01 DIAS DE RESERVA PIGNORACION'


select @w_tabla = codigo from cobis..cl_tabla where tabla = 'ah_tipo_reserva'
  
  
delete from  cobis..cl_catalogo 
where tabla = (select codigo from cobis..cl_tabla where tabla = 'ah_tipo_reserva')
and codigo = 'P'

 insert into cobis..cl_catalogo ( tabla, codigo, valor, estado ) 
 values (@w_tabla, 'P',  @w_descrip, 'V' )
    
 select * from cobis..cl_catalogo 
where tabla = (select codigo from cobis..cl_tabla where tabla = 'ah_tipo_reserva')

 



select @w_tabla = codigo from cobis..cl_tabla where tabla = 'cc_tipo_reserva'
  
  delete from  cobis..cl_catalogo 
where tabla = (select codigo from cobis..cl_tabla where tabla = 'cc_tipo_reserva')
and codigo = 'P'

 insert into cobis..cl_catalogo ( tabla, codigo, valor, estado ) 
 values (@w_tabla, 'P',  @w_descrip, 'V' )
    
go

select * from cobis..cl_catalogo 
where tabla = (select codigo from cobis..cl_tabla where tabla = 'cc_tipo_reserva')

go



if exists(select 1 from cobis..cl_parametro where  pa_nemonico = 'MULRET')
    DELETE cobis..cl_parametro where  pa_nemonico = 'MULRET' AND pa_producto = 'CTE'

   insert into cobis..cl_parametro (pa_parametro , pa_nemonico , pa_tipo , pa_money, pa_producto )
   values ('MULTIPLO DE RETIRO EN EFECTIVO X ATM','MULRET','M',100,'CTE')
go

 select top 10 * from cobis..cl_parametro where  pa_nemonico = 'MULRET'