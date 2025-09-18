use cob_ahorros
go

-- ===============================================================
-- Procedimiento: sp_re_libera_fondos_aho
-- Base:         cob_ahorros
-- Propósito:    Despignorar (liberar) fondos de una cuenta de ahorro
--               previamente reservados por un cupón.
-- Nota:         No maneja transacciones internas. La atomicidad
--               será controlada desde el SP padre.
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_libera_fondos_aho'
              and type = 'P')
   drop procedure sp_re_libera_fondos_aho
go

create procedure sp_re_libera_fondos_aho
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
    , @i_cupon          varchar(80)
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

    -- Salidas
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
        , @w_valor_comision     money
        , @w_return             int
        , @w_ah_cuenta          int
        , @w_num_reserva        int
        , @w_estado             char(1)
        , @w_resultado          char(1)
        , @w_accion_traza       char(3)
        , @w_pro_bancario       smallint
        , @w_ahora              datetime
        , @w_fecha_proceso      datetime
        , @w_detalle_resultado  varchar(100)
        , @w_msg_error          varchar(100)
        , @w_nombre_sp          varchar(50)
        , @w_descripcion        varchar(100)
        , @w_val_reversar       money
    ----------------------------------------------------------------------
    -- Inicialización
    ----------------------------------------------------------------------
    set @w_resultado         = 'E'
    set @w_detalle_resultado = 'GENERACION DE CUPON DE RETIRO SIN TARJETA'
    set @w_descripcion       = 'LIBERACION DE VALOR RESERVADO DE CUENTA DE AHORRO DESDE ATM'
    set @w_nombre_sp         = 'sp_re_libera_fondos_aho'
    set @w_valor_comision    = 0
    set @w_ah_cuenta         = 0
    set @w_return            = 0
    set @w_accion_traza      = ''
    set @w_num_reserva       = 0
    set @w_ahora             = getdate()
    set @w_val_reversar      = @i_val_reservar

    ----------------------------------------------------------------------
    -- Validar producto bancario asociado a la cuenta
    ----------------------------------------------------------------------
    select @w_pro_bancario = ah_prod_banc,
           @w_ah_cuenta    = ah_cuenta
      from ah_cuenta
     where ah_cta_banco = @i_cuenta

    select @w_fecha_proceso = convert(varchar(10), fp_fecha, 101)
      from cobis..ba_fecha_proceso

    ----------------------------------------------------------------------
    -- Validaciones previas
    ----------------------------------------------------------------------
    set @w_accion_traza = 'DPG'   -- despignorado
    set @w_estado       = 'C'     -- consumido
    set @w_num_reserva  = @i_sec

    if exists (select 1
                 from cob_ahorros..ah_his_reserva
                where hr_cuenta = @w_ah_cuenta
                  and hr_num_reserva = @i_sec
                  and hr_estado = 'E'
                  and hr_tipo = 'P'
                  and hr_valor = @i_valor_pignorar)
    begin
        select @o_cod_error = 160009,
               @o_msg_error = 'CUPON YA HA SIDO LIBERADO'
        return 1
    end

    ----------------------------------------------------------------------
    -- Despignoración: libera fondos en la cuenta de ahorro
    ----------------------------------------------------------------------
    exec @w_return = sp_reserva_fondos_ah
         @s_ssn        = @s_ssn,
         @s_date       = @s_date,
         @s_sesn       = @s_sesn,
         @s_org        = @s_org,
         @s_srv        = @s_srv,
         @s_lsrv       = @s_lsrv,
         @s_user       = @s_user,
         @s_term       = @s_term,
         @s_ofi        = @s_ofi,
         @s_rol        = @s_rol,
         @t_debug      = @t_debug,
         @t_file       = @t_file,
         @t_from       = @t_from,
         @t_corr       = @t_corr,
         @t_rty        = @t_rty,
         @t_trn        = @t_trn,
         @t_ssn_corr   = @t_ssn_corr,
         @i_cta        = @i_cuenta,
         @i_valor      = @i_valor_pignorar,
         @i_mon        = @i_moneda,
         @i_accion     = @i_accion,
         @i_tipo       = 'P',
         @i_ofi_solic  = @s_ofi,
         @i_sec        = @i_sec,
         @i_val_reservar = @w_val_reversar,
         @i_solicita   = @w_descripcion,
         @i_comision   = @w_valor_comision,
         @i_tarjeta    = @i_tarjeta,
         @i_motivo     = @i_motivo,
         @o_reserva    = @w_num_reserva out

    if @w_return <> 0
    begin
        set @w_resultado = 'F'
        set @o_cod_error = @w_return
        select @o_msg_error = mensaje
          from cobis..cl_errores
         where numero = @o_cod_error
        return 1
    end

    ----------------------------------------------------------------------
    -- Registrar traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    exec @w_return = cob_bvirtual..sp_re_traza_retiroefectivo
         @i_cupon        = @i_cupon,
         @i_num_reserva  = @w_num_reserva,
         @i_cliente      = @i_cliente,
         @i_accion       = @w_accion_traza,
         @i_tipo_cta     = 'AHO',
         @i_cta_banco    = @i_cuenta,
         @i_moneda       = @i_moneda,
         @i_monto        = @i_valor_pignorar,
         @i_hora_ult_proc= @w_ahora,
         @i_estado       = @w_estado,
         @i_fecha_proc   = @w_fecha_proceso,
         @i_usuario      = @s_user,
         @i_terminal     = @s_term,
         @i_oficina      = @s_ofi,
         @i_resultado    = @w_resultado,
         @i_detalle      = @w_detalle_resultado,
         @o_msg_error    = @w_msg_error output

    if @w_return <> 0
    begin
        set @o_cod_error = @w_return
        set @o_msg_error = @w_msg_error
        return 1
    end

    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    set @o_cod_error = 0
    set @o_msg_error = 'Ejecución exitosa'
    return 0
end
go

if object_id('dbo.sp_re_libera_fondos_aho') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_libera_fondos_aho >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_libera_fondos_aho >>>'
go
