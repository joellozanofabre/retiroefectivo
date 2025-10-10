use cob_bvirtual
go
/******************************************************************************/
/* Archivo:              sp_re_libera_fondos.sp                               */
/* Stored procedure:     sp_re_libera_fondos                                  */
/* Base de datos:        cob_bvirtual                                         */
/* Producto:             Banca Virtual                                        */
/* Diseñado por:         Joel Lozano                                          */
/* Fecha de escritura:   21/Agosto/2025                                       */
/******************************************************************************/
/*                                  IMPORTANTE                                */
/* Este programa es Propiedad de Banco Ficohsa Nicaragua, Miembro             */
/* de Grupo Financiero Ficohsa.                                               */
/* Se prohíbe su uso no autorizado, así como cualquier alteración o agregado  */
/* sin la previa autorización.                                                */
/******************************************************************************/
/*                                  PROPÓSITO                                 */
/* Orquestar el proceso de  liberacion de fondos reservados  en las cuentas   */
/* de ahorro o corriente  mediante cupón.                                     */
/******************************************************************************/
/*                               MODIFICACIONES                               */
/* FECHA        AUTOR                     TAREA             RAZÓN             */
/* 2025.08.21   Joel Lozano TechnoFocus   sp liberardor    Emisión Inicial.  */
/******************************************************************************/


if exists (select 1
             from sysobjects
            where name = 'sp_re_libera_fondos'
              and type = 'P')
   drop procedure sp_re_libera_fondos
go

create procedure sp_re_libera_fondos
(
    ----------------------------------------------------------------------
    -- Parámetros de contexto COBIS
    ----------------------------------------------------------------------
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

    ----------------------------------------------------------------------
    -- Parámetros de trazabilidad
    ----------------------------------------------------------------------
    , @t_debug          char(1)     = 'N'
    , @t_file           varchar(14) = null
    , @t_from           varchar(32) = null
    , @t_corr           char(1)     = 'N'
    , @t_rty            char(1)     = 'N'
    , @t_trn            smallint
    , @t_ejec           char(1)     = 'N'
    , @t_ssn_corr       int         = null

    ----------------------------------------------------------------------
    -- Parámetros de entrada (datos del retiro)
    ----------------------------------------------------------------------
    , @i_cupon          varchar(80)
    , @i_cliente        int
    , @i_cuenta         cuenta
    , @i_valor_pignorar money
    , @i_moneda         tinyint
    , @i_accion         char(1)
    , @i_sec            int
    , @i_reserva        int
    , @i_val_reservar   money       = 0
    , @i_solicita       descripcion = null
    , @i_motivo         tinyint     = 0
    , @i_tarjeta        cuenta      = '000000000000000'
    , @i_tipo_cta       char(3)     -- 'AHO' o 'CTE'
    , @i_fecha_expira   datetime    = null
    , @i_descripcion    varchar(80) = null

    ----------------------------------------------------------------------
    -- Parámetros de salida
    ----------------------------------------------------------------------
    , @o_num_error      int          output
    , @o_desc_error      varchar(255) output
)
as
begin
    ----------------------------------------------------------------------
    -- Declaración de variables locales
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
        , @w_fecha_proceso      datetime
        , @w_msg_error          varchar(100)
        , @w_nombre_sp          varchar(50)
        , @w_descripcion        varchar(100)
        , @w_idcta              int
        , @w_rpc                varchar(80)
        , @w_oficina            smallint
        , @w_saldoagirar_antes  money
        , @w_cod_error          int

    ----------------------------------------------------------------------
    -- Inicialización de variables
    ----------------------------------------------------------------------
    set @w_resultado         = 'E'
    set @w_nombre_sp         = 'sp_re_libera_fondos'
    set @w_descripcion       = 'LIBERACIÓN DE VALOR RESERVADO - RETIRO DE EFECTIVO SIN TD CUPÓN: /' + @i_cupon
    set @w_accion_traza      = 'DPG'   -- Despignorado
    set @w_estado            = 'L'     -- L=liberado, E=error, U=usado, etc.
    set @w_valor_comision    = 0
    set @w_ah_cuenta         = 0
    set @w_return            = 0
    set @w_num_reserva       = @i_sec

    if @i_descripcion is not null
       set @w_descripcion = @i_descripcion
    ----------------------------------------------------------------------
    -- Determinar producto bancario según tipo de cuenta
    ----------------------------------------------------------------------
    if @i_tipo_cta = 'AHO'
    begin
        set @w_rpc = 'cob_ahorros..sp_reserva_fondos_ah'
        set @t_trn =  318
        select @w_idcta = ah_cuenta
          from cob_ahorros..ah_cuenta
         where ah_cta_banco = @i_cuenta

        if exists (select 1
                     from cob_ahorros..ah_his_reserva
                    where hr_cuenta      = @w_idcta
                      and hr_num_reserva = @i_sec
                      and hr_estado      = 'E'
                      and hr_tipo        = 'P'
                      and hr_valor       = @i_valor_pignorar)
        begin
            set @o_num_error = 160009
            set @o_desc_error = 'CUPON YA HA SIDO LIBERADO'
            return @o_num_error
        end
    end
    else if @i_tipo_cta = 'CTE'
    begin
        set @w_rpc = 'cob_cuentas..sp_reserva_fondos'
        set @t_trn =  2706
        select @w_idcta = cc_ctacte
          from cob_cuentas..cc_ctacte
         where cc_cta_banco = @i_cuenta

        if exists (select 1
                     from cob_cuentas..cc_his_reserva
                    where hr_ctacte      = @w_idcta
                      and hr_num_reserva = @i_sec
                      and hr_estado      = 'E'
                      and hr_tipo        = 'P'
                      and hr_valor       = @i_valor_pignorar)
        begin
            set @o_num_error = 169264
            set @o_desc_error = 'CUPON YA HA SIDO LIBERADO'
            return @o_num_error
        end
    end
    else
    begin
        set @o_num_error = 258003
        set @o_desc_error = ' TIPO DE CUENTA NO PERMITIDO PARA LIBERACION DE FONDOS'
        return @o_num_error
    end

    ----------------------------------------------------------------------
    -- Obtener fecha de proceso
    ----------------------------------------------------------------------
    select @w_fecha_proceso = convert(varchar(10), fp_fecha, 101)
      from cobis..ba_fecha_proceso

    ----------------------------------------------------------------------
    -- Lógica de liberación de fondos
    ----------------------------------------------------------------------
    exec @w_return = @w_rpc
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
         @i_val_reservar = @i_val_reservar,
         @i_solicita   = @i_solicita,
         @i_comision   = @w_valor_comision,
         @i_tarjeta    = @i_tarjeta,
         @i_motivo     = @i_motivo,
         @i_sec        = @i_sec,
         @i_reserva    =  @i_sec,--  @i_reserva,
         @i_cheque     = 0,
         @o_oficina    = @w_oficina out,
         @o_num_error  = @w_cod_error out,
         @o_reserva    = @w_num_reserva out,
         @o_saldo_para_girar_antes = @w_saldoagirar_antes out

    if @w_return <> 0
    begin
        set @o_num_error = @w_return
        set @o_desc_error = @w_rpc + ' - ERROR AL REALIZAR EL DÉBITO EN LA CUENTA: ' + @i_cuenta
        set @w_resultado = 'F'
       -- return @o_num_error
    end


    ----------------------------------------------------------------------
    -- Registrar traza del retiro
    ----------------------------------------------------------------------
    exec @w_return = cob_bvirtual..sp_re_traza_retiroefectivo
         @i_cupon         = @i_cupon,
         @i_num_reserva   = @i_sec,
         @i_cliente       = @i_cliente,
         @i_accion        = @w_accion_traza,
         @i_tipo_cta      = @i_tipo_cta,
         @i_cta_banco     = @i_cuenta,
         @i_moneda        = @i_moneda,
         @i_monto         = @i_valor_pignorar,
         @i_fecha_expira  = @i_fecha_expira,
         @i_estado        = @w_estado,
         @i_fecha_proc    = @w_fecha_proceso,
         @i_usuario       = @s_user,
         @i_terminal      = @s_term,
         @i_oficina       = @s_ofi,
         @i_resultado     = @w_resultado,
         @i_detalle       = @w_descripcion,
         @o_num_error     = @w_cod_error output,
         @o_msg_error     = @w_msg_error output

    if @w_return <> 0
    begin
        set @o_num_error = @w_return
        set @o_desc_error = @w_msg_error
        return @w_return
    end



    return @w_return
end
go

if object_id('dbo.sp_re_libera_fondos') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_libera_fondos >>>'
else
    print '<<< FAILED TO CREATE PROCEDURE dbo.sp_re_libera_fondos >>>'
go
