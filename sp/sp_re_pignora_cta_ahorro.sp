use cob_ahorros
go

-- ===============================================================
-- Procedimiento: sp_re_pignora_cta_ahorro
-- Base:         cob_ahorros
-- Propósito:    Pignorar fondos de una cuenta de ahorro para retiro con cupón.
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_pignora_cta_ahorro'
              and type = 'P')
   drop procedure sp_re_pignora_cta_ahorro
go

create procedure sp_re_pignora_cta_ahorro
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

    -- Salidas
    --, @o_reserva        int          = 0 out
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
        , @w_ah_cuenta              int
        , @w_resultado          char(1)
        , @w_pro_bancario       smallint
        , @w_valor_comision     money
        , @w_detalle_resultado  varchar(100)
        , @w_ahora              datetime
        , @w_fecha_proceso      datetime
        , @w_msg_error          varchar(100)
        , @w_nombre_sp          varchar(50)
        , @w_descripcion        VARCHAR(100)
        , @w_accion_traza       char(3)
        , @w_num_reserva        int
        , @w_fecha_expira       datetime
		
        
    ----------------------------------------------------------------------
    -- Inicialización
    ----------------------------------------------------------------------
    set @w_resultado         = 'E'
    set @w_detalle_resultado = 'Generación de cupón de retiro sin tarjeta. OK'
    set @w_valor_comision    = 0
    set @w_ahora             = getdate()
    set @w_nombre_sp         = 'sp_re_pignora_cta_ahorro'
    set @w_ah_cuenta         = 0
    set @w_descripcion       = 'PIGNORACION DE CUENTA DE AHORRO DESDE ATM'
    set @w_return            = 0
    set @w_accion_traza      = ''
	  set @w_num_reserva       = 0


    ----------------------------------------------------------------------
    -- Validar producto bancario asociado a la cuenta
    ----------------------------------------------------------------------
    select @w_pro_bancario = ah_prod_banc,
           @w_ah_cuenta    = ah_cuenta
      from ah_cuenta
     where ah_cta_banco = @i_cuenta

 
    select @w_fecha_proceso = convert(varchar(10),fp_fecha,101)
      from cobis..ba_fecha_proceso
 
 
    ----------------------------------------------------------------------
    -- 1 cupon vigente a la vez
    ----------------------------------------------------------------------    
  
    set @w_accion_traza = 'PIG'   --pignorado
    set @w_estado       = 'G'     --Generado
    if exists(select 1  from cob_ahorros..ah_cuenta_reservada
              where cr_cuenta = @w_ah_cuenta      and cr_estado = 'R' and cr_tipo='P')    
    begin

        select @o_cod_error = 160004
              , @o_msg_error = 'YA TIENE UN CUPON VIGENTE. SOLO SE PERMITE UN CUPON A LA VEZ'

        return 1
    end
  

    --begin transaction
    ----------------------------------------------------------------------
    -- PIGNORACION:  Reservar fondos en la cuenta de ahorro
    ----------------------------------------------------------------------

    exec @w_return = sp_reserva_fondos_ah
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
       , @i_tipo       = 'P'  --nuevo pignoracion
       , @i_ofi_solic  = @s_ofi 
       , @i_sec        = @i_sec
       , @i_val_reservar = @i_val_reservar
       , @i_solicita   = @w_descripcion
       , @i_comision   = @w_valor_comision
       , @i_tarjeta    = @i_tarjeta
       , @i_motivo     = @i_motivo
       , @o_reserva    = @w_num_reserva out

    if @w_return <> 0
    begin
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

    set  @w_fecha_expira = dateadd(hour, 24,  @w_ahora)

    exec @w_return =  cob_bvirtual..sp_re_traza_retiroefectivo
      @i_cupon        = @i_cupon
    , @i_num_reserva  = @w_num_reserva  
    , @i_cliente      = @i_cliente
    , @i_accion       = @w_accion_traza
    , @i_tipo_cta     = 'AHO'
    , @i_cta_banco    = @i_cuenta
    , @i_moneda       = @i_moneda
    , @i_monto        = @i_valor_pignorar
    , @i_hora_ult_proc= @w_ahora
    , @i_fecha_expira = null
    , @i_estado       = @w_estado   --P=Pendiente, C=Consumido, X=Expirado
    , @i_fecha_proc   = @w_fecha_proceso
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




if object_id('dbo.sp_re_pignora_cta_ahorro') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_pignora_cta_ahorro >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_pignora_cta_ahorro >>>'
go

