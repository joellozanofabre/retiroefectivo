delete cl_catalogo_pro
  from cl_tabla
 where tabla in 	('re_estados_transicion'   )
 and codigo = cp_tabla


declare @w_codigo int
select @w_codigo = siguiente + 1
  from cl_seqnos
 where tabla = 'cl_tabla'

insert into cl_tabla values (@w_codigo, 're_estados_transicion', 'Estados de transicion para procesos Retiro Efectivo', 'V', getdate(), 'admin')
insert into cl_catalogo_pro values ('G', @w_codigo)
insert into cl_catalogo_pro values ('V', @w_codigo)
insert into cl_catalogo_pro values ('X', @w_codigo)
insert into cl_catalogo_pro values ('U', @w_codigo)
insert into cl_catalogo_pro values ('N', @w_codigo)
insert into cl_catalogo_pro values ('E', @w_codigo)

insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'GENERANDO','G','V')
insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'VALIDANDO','V','V')
insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'USADO','U','V')
insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'EXPIRADO','X','V')
insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'ANULADO','N','V')
insert into cl_catalogo (tabla,codigo,valor,estado) values (@w_codigo,'ERROR','E','V')

GO
