use cob_cuentas

go

-- ===============================================================
-- Procedimiento: sp_re_pignora_cta_corriente
-- Base:         cob_cuentas
-- Propósito:    Pignorar fondos de una cuenta corriente para retiro con cupón.
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_pignora_cta_corriente'
              and type = 'P')
   drop procedure sp_re_pignora_cta_corriente
go

create procedure sp_re_pignora_cta_corriente
(
    -- Parámetros de contexto COBIS
      @s_ssn            int
    , @s_srv            varchar(30)
    , @s_lsrv           varchar(30)
    , @s_user           varchar(30)
    , @s_sesn           int
    , @s_term           varchar(10)
    , @s_date           datetime
    , @s_org            char(1)
    , @s_ofi            smallint
    , @s_rol            smallint = 1

    -- Trazabilidad
    , @t_debug          char(1)      = 'N'
    , @t_file           varchar(14)  = null
    , @t_from           varchar(32)  = null
    , @t_corr           char(1)      = 'N'
    , @t_rty            char(1)      = 'N'
    , @t_trn            smallint
    , @t_ejec           char(1)      = 'N'
    , @t_ssn_corr       int          = null

    -- Datos del retiro
    , @i_cupon          varchar(30)
    , @i_cliente        int
    , @i_cuenta         cuenta
    , @i_valor_pignorar money
    , @i_moneda         tinyint
    , @i_accion         char(1)
    , @i_sec            int
    , @i_val_reservar   money        = 0
    , @i_solicita       descripcion  = null
    , @i_motivo         tinyint      = 0
    , @i_tarjeta        cuenta       = '000000000000000'
    , @i_num_reserva    int          = 0
	, @i_reserva        int          = 0
    -- Salidas
    , @o_reserva        int          = 0 out
    , @o_cod_error      int          output
    , @o_msg_error      varchar(255) output
)
as
begin
    ----------------------------------------------------------------------
    -- Variables de trabajo
    ----------------------------------------------------------------------
    declare
          @w_saldo              money
        , @w_estado             char(1)
        , @w_return             int
        , @w_idcta              int
        , @w_resultado          char(1)
        , @w_pro_bancario       smallint
        , @w_valor_comision     money
        , @w_detalle_resultado  varchar(100)
        , @w_ahora              datetime
        , @w_fecha_proceso      datetime
        , @w_msg_error          varchar(100)
        , @w_nombre_sp          varchar(50)
		, @w_saldoagirar_antes  money
		, @w_cod_error          int
		, @w_oficina            smallint
		, @w_descripcion        VARCHAR(100)
        , @w_accion_traza       char(3)
		, @w_num_reserva        int

    ----------------------------------------------------------------------
    -- Inicialización
    ----------------------------------------------------------------------
    set @w_resultado         = 'E'
    set @w_detalle_resultado = 'Generación de cupón de retiro sin tarjeta. OK'
    set @w_valor_comision    = 0
    set @w_ahora             = getdate()
    set @w_nombre_sp         = 'sp_re_pignora_cta_corriente'
    set @w_idcta             = 0
	set @w_saldoagirar_antes = 0
	set @w_cod_error         = 0
	set @w_oficina           = 0
	set @w_return            = 0
	set @w_accion_traza      = ''
    set @w_num_reserva       = 0
 

    ----------------------------------------------------------------------
    -- Validar producto bancario asociado a la cuenta
    ----------------------------------------------------------------------
    select @w_pro_bancario = cc_prod_banc,
           @w_idcta        = cc_ctacte
      from cc_ctacte
     where cc_cta_banco = @i_cuenta

 
    select @w_fecha_proceso = convert(varchar(10),fp_fecha,101)
      from cobis..ba_fecha_proceso
   
 
	  
     ----------------------------------------------------------------------
    -- 1 cupon vigente a la vez
    ----------------------------------------------------------------------    
    if @i_accion = 'R'-- Reservar
    begin
	   set @w_accion_traza = 'PIG'   --pignorado
       set @w_estado       = 'P'     --pendiente
	   if exists(select 1  from cob_cuentas..cc_cuenta_reservada
				  where cr_ctacte = @w_idcta      and cr_estado = 'R'
				  and cr_tipo='P')  
		begin
            select @o_cod_error = 160004
                 , @o_msg_error = 'YA TIENE UN CUPON VIGENTE. SOLO SE PERMITE UN CUPON A LA VEZ'
	 
			return 1
		end	
    end

	if @i_accion = 'E'-- Eliminar 
	begin
	    set @w_accion_traza = 'DPG'   --despignorado
        set @w_estado       = 'C'     --consumido
	    set @w_num_reserva  = @i_reserva
        if exists(select 1  from cob_cuentas..cc_his_reserva
                  where hr_ctacte = @w_idcta     and hr_num_reserva = @i_reserva   --@i_sec   
				  and hr_estado = 'E' and hr_tipo='P' and hr_valor = @i_valor_pignorar) 
        begin

            select @o_cod_error = 160009
                 , @o_msg_error = 'CUPON YA HA SIDO LIBERADO'
            return 1
        end	
	end

 /*
    ----------------------------------------------------------------------
    -- Generación de costos (cob_remesas)
    ----------------------------------------------------------------------
   exec @w_return = cob_remesas..sp_genera_costos
         @t_from        = 'sp_re_pignora_cta_ahorro'
       , @i_fecha       = @s_date
       , @i_valor       = 1
       , @i_categoria   = 'N'
       , @i_rol_ente    = 'P'
       , @i_tipo_def    = 'D'
       , @i_codigo      = 0
       , @i_tipo_ente   = 'P'
       , @i_prod_banc   = @w_pro_bancario
       , @i_producto    = 16
       , @i_moneda      = @i_moneda
       , @i_tipo        = 'R'
       , @i_servicio    = 'CING'
       , @i_rubro       = 3  --comision
       , @i_personaliza = 'N'
       , @i_filial      = 1
       , @i_oficina     = @s_ofi
       , @o_valor_total = @w_valor_comision out

print '@w_valor_comision  %1!',@w_valor_comision 

*/
 

    ----------------------------------------------------------------------
    -- PIGNORACION:  Reservar fondos en la cuenta corriente
    ----------------------------------------------------------------------

    exec @w_return = sp_reserva_fondos
         @s_ssn        = @s_ssn
       , @s_date       = @s_date
       , @s_sesn       = @s_sesn
       , @s_org        = @s_org
       , @s_srv        = @s_srv
       , @s_lsrv       = @s_lsrv
       , @s_user       = @s_user
       , @s_term       = @s_term
       , @s_ofi        = @s_ofi
       , @s_rol        = @s_rol
       , @t_debug      = @t_debug
       , @t_file       = @t_file
       , @t_from       = @t_from
       , @t_corr       = @t_corr
       , @t_rty        = @t_rty
       , @t_trn        = @t_trn
       , @t_ssn_corr   = @t_ssn_corr
       , @i_cta        = @i_cuenta

       , @i_valor      = @i_valor_pignorar
       , @i_mon        = @i_moneda
       , @i_accion     = @i_accion
       , @i_tipo       = 'P'  --dias de reserva pignoracion
       , @i_ofi_solic  = @s_ofi
       , @i_val_reservar = @i_val_reservar
       , @i_solicita    = @i_solicita
       , @i_comision    = @w_valor_comision
       , @i_tarjeta     = @i_tarjeta
       , @i_motivo      = @i_motivo
       , @i_causa	    = null
       , @i_aut		    = null
       , @i_plazo	    = null
       , @i_cheque      = 0
       , @i_chq_certi   = 'N' 
       , @i_reserva     = @i_reserva    --numero de reserva 
       , @i_num_reserva = @i_num_reserva
     
       , @o_oficina     = @w_oficina out
       , @o_cod_error	= @w_cod_error out
       , @o_reserva     = @w_num_reserva out
       , @o_saldo_para_girar_antes  = @w_saldoagirar_antes out 
	   
   
    if @w_return <> 0
    begin
        if @w_num_reserva is null
		   set @w_num_reserva = 0
		   
        set @w_resultado = 'F'
        set @o_cod_error = @w_return
    end

    ----------------------------------------------------------------------
    -- Registrar la traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    if @o_cod_error != 0
    begin
        select @o_msg_error = mensaje
          from cobis..cl_errores
         where numero = @o_cod_error
         
        set @w_detalle_resultado = @o_msg_error
		
    end
	
     exec @w_return =  cob_bvirtual..sp_re_traza_retiroefectivo
      @i_cupon        = @i_cupon
    , @i_num_reserva  = @w_num_reserva	  
    , @i_cliente      = @i_cliente
    , @i_accion       = @w_accion_traza
    , @i_tipo_cta     = 'CTE'
    , @i_cta_banco    = @i_cuenta
    , @i_moneda       = @i_moneda
    , @i_monto        = @i_valor_pignorar
    , @i_fecha_gen    = @w_ahora
    , @i_estado       = @w_estado   --P=Pendiente, C=Consumido, X=Expirado
    , @i_cliente_dest = null
    , @i_fecha        = @w_fecha_proceso
    , @i_usuario      = @s_user
    , @i_terminal     = @s_term
    , @i_oficina      = @s_ofi
    , @i_resultado    = @w_resultado
    , @i_detalle      = @w_detalle_resultado
    , @o_msg_error    = @w_msg_error output
    if @w_return != 0
    begin
        set @o_cod_error = @w_return
        set @o_msg_error = @w_msg_error

        return 1
    end



    return @w_return
end
go




if object_id('dbo.sp_re_pignora_cta_corriente') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_pignora_cta_corriente >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_pignora_cta_corriente >>>'
go

