use cob_cuentas

go

-- ===============================================================
-- Procedimiento: sp_re_despignora_cta_corriente
-- Base:         cob_cuentas
-- Propósito:    Pignorar fondos de una cuenta corriente para retiro con cupón.
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_despignora_cta_corriente'
              and type = 'P')
   drop procedure sp_re_despignora_cta_corriente
go

create procedure sp_re_despignora_cta_corriente
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

    ----------------------------------------------------------------------
    -- Inicialización
    ----------------------------------------------------------------------
    set @w_resultado         = 'E'
    set @w_detalle_resultado = 'Generación de cupón de retiro sin tarjeta. OK'
    set @w_valor_comision    = 0
    set @w_ahora             = getdate()
    set @w_nombre_sp         = 'sp_re_despignora_cta_corriente'
    set @w_idcta             = 0
	set @w_saldoagirar_antes = 0
	set @w_cod_error         = 0
	set @w_oficina           = 0

    ----------------------------------------------------------------------
    -- Validar producto bancario asociado a la cuenta
    ----------------------------------------------------------------------
    select @w_pro_bancario = cc_prod_banc,
           @w_idcta        = cc_ctacte
      from cc_ctacte
     where cc_cta_banco = @i_cuenta

 
    select @w_fecha_proceso = convert(varchar(10),fp_fecha,101)
      from cobis..ba_fecha_proceso
 
 /*
    ----------------------------------------------------------------------
    -- Generación de costos (cob_remesas)
    ----------------------------------------------------------------------
    exec cob_remesas..sp_genera_costos
         @t_debug       = 'N'
       , @t_file        = 'NOERROR'
       , @t_from        = 'sp_re_despignora_cta_corriente'
       , @i_fecha       = @s_date
       , @i_valor       = 1
       , @i_categoria   = 'N'
       , @i_rol_ente    = null
       , @i_tipo_def    = null
       , @i_codigo      = null
       , @i_tipo_ente   = 'P'
       , @i_prod_banc   = @w_pro_bancario
       , @i_producto    = 16
       , @i_moneda      = 0
       , @i_tipo        = 'R'
       , @i_servicio    = 'MAN'
       , @i_rubro       = 4
       , @i_personaliza = 'N'
       , @i_filial      = 1
       , @i_oficina     = @s_ofi
       , @o_valor_total = @w_valor_comision out

print '@w_valor_comision  %1!',@w_valor_comision 

*/
    begin transaction
    ----------------------------------------------------------------------
    -- PIGNORACION:  Reservar fondos en la cuenta de ahorro
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
       , @i_tipo       = 'E'  --?
       , @i_ofi_solic  = 76 --?
       , @i_sec        = 0 --?
       , @i_val_reservar = @i_val_reservar
       , @i_solicita    = @i_solicita
       , @i_comision    = @w_valor_comision
       , @i_tarjeta     = @i_tarjeta
       , @i_motivo      = @i_motivo
       , @i_causa	    = null
       , @i_aut		    = null
       , @i_plazo	    = null
       , @i_cheque      = null
       , @i_chq_certi   = 'N' 
       , @i_reserva     = @i_reserva
       , @i_num_reserva = @i_num_reserva
     
       , @o_oficina     = @w_oficina out
       , @o_cod_error	= @w_cod_error out
       , @o_reserva     = @o_reserva out
       , @o_saldo_para_girar_antes  = @w_saldoagirar_antes out 
	   
	   print '@w_saldoagirar_antes %1!'  ,@w_saldoagirar_antes
	   
    if @w_return <> 0
    begin
    print 'rollback tran sp_reserva_fondos'
        rollback tran
        set @w_resultado = 'F'
        select @o_cod_error = @w_cod_error
             , @o_msg_error = mensaje
          from cobis..cl_errores
         where numero = @w_return

        if @@rowcount = 0
            set @o_msg_error =  'Error en procesar sp_reserva_fondos'
        
        set @w_detalle_resultado = @o_msg_error
    end

    ----------------------------------------------------------------------
    -- Registrar la traza en re_retiro_efectivo
    ----------------------------------------------------------------------
     exec @w_return =  cob_bvirtual..sp_re_traza_retiroefectivo
      @i_cupon        = @i_cupon
    , @i_cliente      = @i_cliente
    , @i_accion       = 'PIG'
    , @i_tipo_cta     = 'CTE'
    , @i_cta_banco    = @w_idcta
    , @i_moneda       = @i_moneda
    , @i_monto        = @i_valor_pignorar
    , @i_fecha_gen    = @w_ahora
    , @i_estado       = 'P'   --Pignorado
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
        rollback tran
        return 1
    end

    commit transaction
    return 0
end
go




if object_id('dbo.sp_re_despignora_cta_corriente') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_despignora_cta_corriente >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_despignora_cta_corriente >>>'
go

