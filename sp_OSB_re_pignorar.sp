use cob_bvirtual
go

-- ===============================================================
-- Procedimiento: sp_OSB_re_pignorar
-- Base:         cob_ahorros
-- Propósito:    Pignorar fondos de una cuenta de ahorro para retiro con cupón.
-- ===============================================================
if exists (select 1
             from sysobjects
            where name = 'sp_OSB_re_pignorar'
              and type = 'P')
   drop procedure sp_OSB_re_pignorar
go




CREATE PROCEDURE dbo.sp_OSB_re_pignorar
(
      @i_DEBIT_ACCOUNT         varchar(35)   = null      -- Cuenta origen a pignorar
    , @i_AMOUNT                money       -- Monto a retirar
    , @i_CURRENCY              char(3)     -- Moneda
    , @i_CUPON                 varchar(40) -- Cupón generado
    , @o_num_error             int          = null out
    , @o_desc_error            varchar(132) = null out
)
AS
BEGIN
    --------------------------------------------------------------------------
    -- Declaración de variables internas
    --------------------------------------------------------------------------
    DECLARE 
          @w_error       int
        , @w_cod_error   int
        , @w_msg_error   varchar(255)
        , @w_sp_name     varchar(50)
        , @w_return      int

    DECLARE 
          @i_gen_ssn     char(1)
        , @w_ssn         int
        , @w_user        login
        , @w_sesn        int
        , @w_term        varchar(30)
        , @w_ipaddr      varchar(30)
        , @w_date        datetime
        , @w_srv         varchar(30)
        , @w_lsrv        varchar(30)
        , @w_ofi         smallint
        , @w_from        varchar(30)
        , @w_ejec        char(1)
        , @w_corr        char(1)
        , @w_rty         char(1)
        , @w_tipo_cuenta char(3)
        , @w_reserva     int
        , @w_num_transaccion  smallint
        , @w_moneda       smallint
        , @w_codigo_cliente  int
        

    --------------------------------------------------------------------------
    -- Inicialización de variables de salida
    --------------------------------------------------------------------------
    SET @o_num_error  = 0
    SET @o_desc_error = 'SUCCESS'
    SET @w_sp_name           = 'sp_OSB_re_pignorar'
    SET @w_tipo_cuenta       = ''

    print '@i_CURRENCY %1!',@i_CURRENCY
    --------------------------------------------------------------------------
    -- Paso 1: Validaciones previas de la pignoración
    --------------------------------------------------------------------------
    EXEC @w_return = sp_re_valida_pignoracion
          @i_cuenta_banco = @i_DEBIT_ACCOUNT
        , @i_monto        = @i_AMOUNT
        , @i_moneda       = @i_CURRENCY
        , @o_cliente      = @w_codigo_cliente OUTPUT
        , @o_tipo_cuenta  = @w_tipo_cuenta    OUTPUT
        , @o_moneda       = @w_moneda         OUTPUT
        , @o_msg_error    = @w_msg_error      OUTPUT

    IF @w_return != 0
    BEGIN
        SET @o_num_error  = @w_return
        SET @o_desc_error = 'Error en sp_re_valida_pignoracion: ' + @w_msg_error
        RETURN 1
    END

print '@w_moneda %1! @i_CURRENCY %2! @w_codigo_cliente %3!',@w_moneda, @i_CURRENCY ,@w_codigo_cliente
    --------------------------------------------------------------------------
    -- Paso 2: Obtener datos de sesión/seguridad COBIS
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
    -- Paso 3: Delegar según tipo de cuenta
    --------------------------------------------------------------------------
    IF @w_tipo_cuenta = 'AHO'
    BEGIN
        set @w_num_transaccion = 226
        EXEC @w_return = cob_ahorros..sp_re_pignora_cta_ahorro
              @s_ssn          = @w_ssn
            , @s_srv          = @w_srv
            , @s_lsrv         = @w_lsrv
            , @s_user         = @w_user
            , @s_sesn         = @w_sesn
            , @s_term         = @w_term
            , @s_date         = @w_date
            , @s_ofi          = @w_ofi
            , @s_org          = 'N'
            , @t_from         = @w_from
            , @t_ejec         = @w_ejec
            , @t_corr         = @w_corr
            , @t_rty          = @w_rty
            , @t_trn          = @w_num_transaccion
            , @i_cuenta       = @i_DEBIT_ACCOUNT
            , @i_valor_pignorar = @i_AMOUNT
            , @i_moneda       = @w_moneda
            , @i_accion       = 'R'  -- reservar
            , @i_cupon        = @i_CUPON
            , @i_cliente      = @w_codigo_cliente
            , @i_val_reservar = 0
            , @i_motivo       = 2
            , @i_sec          = 0
            , @i_tarjeta      = '000000000000000'
            , @o_reserva      = @w_reserva   OUT
            , @o_cod_error    = @w_return    OUTPUT
            , @o_msg_error    = @w_msg_error OUTPUT

        IF @w_return != 0
        BEGIN
            SET @o_num_error  = @w_return
            SET @o_desc_error = 'Error en sp_re_pignora_cta_ahorro: ' + @w_msg_error
            RETURN 1
        END
    END
    ELSE IF @w_tipo_cuenta = 'CTE'
    BEGIN
        set @w_num_transaccion = 2657
        EXEC @w_return = cob_cuentas..sp_re_pignora_cta_corriente
              @s_ssn          = @w_ssn
            , @s_srv          = @w_srv
            , @s_lsrv         = @w_lsrv
            , @s_user         = @w_user
            , @s_sesn         = @w_sesn
            , @s_term         = @w_term
            , @s_date         = @w_date
            , @s_ofi          = @w_ofi
            , @s_org          = 'N'
            , @t_from         = @w_from
            , @t_ejec         = @w_ejec
            , @t_corr         = @w_corr
            , @t_rty          = @w_rty
            , @t_trn          = @w_num_transaccion
            , @i_cuenta       = @i_DEBIT_ACCOUNT
            , @i_valor_pignorar = @i_AMOUNT
            , @i_moneda       = @w_moneda
            , @i_accion       = 'R'  -- reservar
            , @i_cupon        = @i_CUPON
            , @i_cliente      = @w_codigo_cliente
            , @i_val_reservar = 0
            , @i_motivo       = 2
            , @i_sec          = 0
            , @i_tarjeta      = '000000000000000'
            , @o_reserva      = @w_reserva OUT
            , @o_cod_error    = @w_return OUTPUT
            , @o_msg_error    = @w_msg_error OUTPUT

        IF @w_return != 0
        BEGIN
            SET @o_num_error  = @w_return
            SET @o_desc_error = 'Error en sp_re_pignora_cta_corriente: ' + @w_msg_error
            RETURN 1
        END
    END
    ELSE
    BEGIN
        SET @o_num_error  = 999
        SET @o_desc_error = 'Tipo de cuenta inválido'
        RETURN @o_num_error
    END

    RETURN 0
END

go

-------------------------------------------------------------------------------
-- PERMISOS DE EJECUCIÓN
-------------------------------------------------------------------------------
IF (ROLE_ID('Service_Rol_Dev') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_pignorar TO Service_Rol_Dev

IF (ROLE_ID('Service_Rol_QA') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_pignorar TO Service_Rol_QA

IF (ROLE_ID('Service_Rol') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_pignorar TO Service_Rol
GO

EXEC sp_procxmode 'dbo.sp_OSB_re_pignorar', 'anymode'
GO






IF OBJECT_ID('dbo.sp_OSB_re_pignorar') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.sp_OSB_re_pignorar >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.sp_OSB_re_pignorar >>>'
GO


