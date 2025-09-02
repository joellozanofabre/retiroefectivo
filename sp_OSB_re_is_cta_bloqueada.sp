use cob_bvirtual
go

-- ===============================================================
-- Procedimiento: sp_OSB_re_is_cta_bloqueada
-- Base:         cob_ahorros
-- Propósito:    Pignorar fondos de una cuenta de ahorro para retiro con cupón.
-- ===============================================================
if exists (select 1
             from sysobjects
            where name = 'sp_OSB_re_is_cta_bloqueada'
              and type = 'P')
   drop procedure sp_OSB_re_is_cta_bloqueada
go


CREATE PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada
(
      @i_DEBIT_ACCOUNT                cuenta      -- Cuenta origen a pignorar
    , @o_codigo_respuesta      int output  -- Código de salida
    , @o_detalle_respuesta     varchar(255) output -- Mensaje detalle
)
AS
 

declare
    @w_sp_name      varchar(30),
    @w_tipo_bloqueo varchar(2),
    @w_mensaje      varchar(255),
	@w_tipo_cuenta  char(3),
	@w_id_cuenta    int,
	@w_return       int


    set  @w_sp_name = 'sp_OSB_re_is_cta_bloqueada'

	SET @o_codigo_respuesta  = 0
	SET @o_detalle_respuesta = 'SIN BLOQUEO'
		

-- Llamada al procedimiento
   exec @w_return    = sp_re_get_tipodecuenta 
     @i_cuenta_banco = @i_DEBIT_ACCOUNT
   , @o_tipo_cuenta  = @w_tipo_cuenta output
   , @o_id_cuenta    = @w_id_cuenta output
   , @o_cod_error    = @o_codigo_respuesta output
   , @o_msg_error    = @o_detalle_respuesta output

    if @w_return <> 0
    begin
        select @o_codigo_respuesta ,         @o_detalle_respuesta 
        return 1
    end

 

if @w_tipo_cuenta = 'CTE'
begin
    -- ===== CUENTA CORRIENTE ===== 
    select @w_tipo_bloqueo = cb_tipo_bloqueo
      from cob_cuentas..cc_ctabloqueada
     where cb_cuenta = @w_id_cuenta
       and cb_estado = 'V'
       and cb_tipo_bloqueo in ('2', '3')

    if @@rowcount != 0
    begin
        select @w_mensaje = rtrim(valor)
          from cobis..cl_catalogo
         where tabla = (select codigo from cobis..cl_tabla
                         where tabla = 'cc_tbloqueo')
           and codigo = @w_tipo_bloqueo

        select @w_mensaje = 'Cuenta bloqueada: ' + @w_mensaje

        SET @o_codigo_respuesta  = 201008
        SET @o_detalle_respuesta =  @w_mensaje
        RETURN 1
    end
end
else if @w_tipo_cuenta = 'AHO'
begin
    /* ===== CUENTA DE AHORROS ===== */
    select @w_tipo_bloqueo = cb_tipo_bloqueo
      from cob_ahorros..ah_ctabloqueada
     where cb_cuenta = @w_id_cuenta
       and cb_estado = 'V'
       and cb_tipo_bloqueo in ('2', '3')

    if @@rowcount != 0
    begin
        select @w_mensaje = rtrim(valor)
          from cobis..cl_catalogo
         where tabla = (select codigo from cobis..cl_tabla
                         where tabla = 'ah_tbloqueo')
           and codigo = @w_tipo_bloqueo

        select @w_mensaje = 'Cuenta bloqueada: ' + @w_mensaje

        SET @o_codigo_respuesta  = 201009
        SET @o_detalle_respuesta = @w_mensaje
        RETURN 1
		
    end
end

return 0
go

if object_id('dbo.sp_OSB_re_is_cta_bloqueada') is not null
    print '<<< CREATED PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada >>>'
go
