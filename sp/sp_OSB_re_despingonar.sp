use cob_bvirtual
go

if exists (select 1
             from sysobjects
            where name = 'sp_OSB_re_despignorar'
              and type = 'P')
   drop procedure sp_OSB_re_despignorar
go

create procedure sp_OSB_re_despignorar
(
    -- Parámetros de sesión
      @s_srv           varchar(30),
      @s_user          varchar(30),
      @s_sesn          int,
      @s_term          varchar(10),
      @s_date          datetime,
      @s_lsrv          varchar(30),
      @s_ofi           smallint,

    -- Parámetros de entrada
      @i_cupon         varchar(30),
      @i_cliente       int,
      @i_cuenta        cuenta,
      @i_valor         money,
      @i_moneda        tinyint,
      @i_tipo_cta      char(3),   -- 'AHO' o 'CTE'
      @i_producto_deb  char(3),   -- Producto: 'CTE' / 'AHO'
      @i_moneda_iso    varchar(3),
      @i_moneda_tran   varchar(3),
      @i_reverso       char(1) = 'N',
      @i_reserva       int,

    -- Parámetros de salida
      @o_cod_error     int          output,
      @o_msg_error     varchar(255) output
)
as
begin
    ----------------------------------------------------------------------
    -- Variables locales
    ----------------------------------------------------------------------
    declare 
          @w_return       int,
          @w_msg_error    varchar(255),
          @w_secuencial   int,
          @w_rpc          varchar(64),
          @w_tran_deb     int,
          @w_causa_deb    varchar(5),
          @w_desc_deb     varchar(100)

    set @o_cod_error = 0
    set @o_msg_error = null


    --------------------------------------------------------------------------
    -- Paso 1: Obtener datos de sesión / seguridad COBIS
    --------------------------------------------------------------------------
    SET @i_gen_ssn = 'S'

    EXEC cob_bvirtual..sp_OSB_datos_conexion
          @i_gen_ssn
        , @w_ssn    OUT
        , @w_user   OUT
        , @w_sesn   OUT
        , @w_term   OUT
        , @w_ipaddr OUT
        , @w_date   OUT
        , @w_srv    OUT
        , @w_lsrv   OUT
        , @w_ofi    OUT
        , @w_from   OUT
        , @w_ejec   OUT
        , @w_corr   OUT
        , @w_rty    OUT

    --------------------------------------------------------------------------
    -- Paso 2: Validación de cupón
    --------------------------------------------------------------------------
    EXEC @w_return = sp_re_valida_cupon
          @i_cupon     = @i_CUPON
        , @o_cliente   = @w_codigo_cliente  OUT
        , @o_cta_banco = @i_DEBIT_ACCOUNT   OUT
        , @o_tipo_cta  = @w_tipo_cuenta     OUT
        , @o_moneda    = @w_moneda          OUT
        , @o_monto     = @i_AMOUNT          OUT
        , @o_estado    = @w_estado          OUT
        , @o_cod_error = @w_cod_error       OUT
        , @o_msg_error = @w_msg_error       OUT

    IF @w_return <> 0
    BEGIN
        SELECT
              @o_num_error  = @w_cod_error
            , @o_desc_error = 'Error en sp_re_valida_cupon: ' + @w_msg_error
        RETURN 1
    END

    ----------------------------------------------------------------------
    -- Inicia transacción
    ----------------------------------------------------------------------
    begin tran TRANSACCION_RETIRO

    ----------------------------------------------------------------------
    -- 1. Liberar fondos (despignorar)
    ----------------------------------------------------------------------
    exec @w_return = cob_cuentas..sp_re_libera_fondos
         @s_ssn         = @s_sesn,
         @s_srv         = @s_srv,
         @s_lsrv        = @s_lsrv,
         @s_user        = @s_user,
         @s_sesn        = @s_sesn,
         @s_term        = @s_term,
         @s_date        = @s_date,
         @s_org         = 'U',
         @s_ofi         = @s_ofi,
         @t_trn         = 4083, -- código de transacción estándar
         @i_cupon       = @i_cupon,
         @i_cliente     = @i_cliente,
         @i_cuenta      = @i_cuenta,
         @i_valor_pignorar = @i_valor,
         @i_moneda      = @i_moneda,
         @i_accion      = 'L', -- liberar
         @i_sec         = 0,
         @i_reserva     = @i_reserva,
         @i_tipo_cta    = @i_tipo_cta,
         @o_cod_error   = @o_cod_error out,
         @o_msg_error   = @o_msg_error out

    if @w_return <> 0 or @o_cod_error <> 0
    begin
        rollback tran TRANSACCION_RETIRO
        return @o_cod_error
    end

    ----------------------------------------------------------------------
    -- 2. Aplicar Nota de Débito (debitando la cuenta origen)
    ----------------------------------------------------------------------
    exec @w_return = cob_bvirtual..sp_re_aplica_nd
         @s_srv          = @s_srv,
         @s_user         = @s_user,
         @s_sesn         = @s_sesn,
         @s_term         = @s_term,
         @s_date         = @s_date,
         @s_lsrv         = @s_lsrv,
         @s_ofi          = @s_ofi,
         @i_cupon        = @i_cupon,
         @i_cliente      = @i_cliente,
         @i_cuenta       = @i_cuenta,
         @i_valor_debitar= @i_valor,
         @i_moneda_iso   = @i_moneda_iso,
         @i_moneda_tran  = @i_moneda_tran,
         @i_producto_deb = @i_producto_deb,
         @i_reverso      = @i_reverso,
         @o_secuencial   = @w_secuencial out,
         @o_cod_error    = @o_cod_error out,
         @o_msg_error    = @o_msg_error out

    if @w_return <> 0 or @o_cod_error <> 0
    begin
        rollback tran TRANSACCION_RETIRO
        return @o_cod_error
    end

    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    commit tran TRANSACCION_RETIRO
    set @o_cod_error = 0
    set @o_msg_error = 'Liberación y débito exitosos'
    return 0
end
go

if object_id('dbo.sp_OSB_re_despignorar') is not null
    print '<<< CREATED PROCEDURE dbo.sp_OSB_re_despignorar >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_OSB_re_despignorar >>>'
go
