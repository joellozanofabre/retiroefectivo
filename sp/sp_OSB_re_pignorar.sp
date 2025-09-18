USE cob_bvirtual
GO
/******************************************************************************/ 
/* Archivo:              sp_OSB_re_pingonar.sp                                */ 
/* Stored procedure:     sp_OSB_re_pingonar                                   */ 
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
/* Orquestar el proceso de  despignoración de cuentas de ahorro o corriente   */ 
/* corriente para operaciones de Retiro Efectivo mediante cupón.              */ 
/******************************************************************************/ 
/*                               MODIFICACIONES                               */ 
/* FECHA        AUTOR                     TAREA             RAZÓN             */ 
/* 2025.08.21   Joel Lozano TechnoFocus   interfaz bus      Emisión Inicial.  */ 
/******************************************************************************/ 

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
    , @i_CUPON                 varchar(80) -- Cupón generado
    , @o_num_error             int          = null out
    , @o_desc_error            varchar(132) = null out
)
AS
BEGIN
    --------------------------------------------------------------------------
    -- Declaración de variables internas
    --------------------------------------------------------------------------
DECLARE
    -- Caracteres
      @i_gen_ssn          char(1)
    , @w_ejec             char(1)
    , @w_corr             char(1)
    , @w_rty              char(1)
    , @w_tipo_cuenta      char(3)
    -- Números enteros
    , @w_error            int
    , @w_cod_error        int
    , @w_return           int
    , @w_ssn              int
    , @w_sesn             int
    , @w_reserva          int
    , @w_codigo_cliente   int
    , @w_idcuenta         int
    -- Numéricos pequeños
    , @w_ofi              smallint
    , @w_num_transaccion  smallint
    , @w_moneda           smallint
    -- Texto
    , @w_msg_error        varchar(255)
    , @w_sp_name          varchar(50)
    , @w_term             varchar(30)
    , @w_ipaddr           varchar(30)
    , @w_srv              varchar(30)
    , @w_lsrv             varchar(30)
    , @w_from             varchar(30)
    -- Otros tipos
    , @w_user             login
    , @w_date             datetime
       

    --------------------------------------------------------------------------
    -- Inicialización de variables de salida
    --------------------------------------------------------------------------
    SET @o_num_error       = 0
    SET @o_desc_error      = 'SUCCESS'
    SET @w_sp_name         = 'sp_OSB_re_pignorar'
    SET @w_tipo_cuenta     = ''

    --------------------------------------------------------------------------
    -- Paso 1: Validaciones previas de la pignoración
    --------------------------------------------------------------------------
 exec @w_return = sp_re_validacion_generales
      @i_cuenta_banco   = @i_DEBIT_ACCOUNT
    , @i_monto          = @i_AMOUNT
    , @i_moneda_iso     = @i_CURRENCY
    , @o_cliente        = @w_codigo_cliente output
    , @o_tipo_cuenta    = @w_tipo_cuenta    output
    , @o_moneda         = @w_moneda OUTPUT 
    , @o_idcuenta       = @w_idcuenta   output
    , @o_msg_error      = @w_msg_error   output
    , @o_num_error      = @w_cod_error   output 
    IF @w_return != 0
    BEGIN
        SET @o_num_error  = @w_cod_error
        SET @o_desc_error = 'Error en sp_re_validacion_generales: ' + @w_msg_error
        RETURN 1
    END


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
            , @o_num_error    = @w_return    OUTPUT
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
            , @o_num_error    = @w_return OUTPUT
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
    ----------------------------------------------------------------------
    PRINT '-- Éxito'
    ----------------------------------------------------------------------
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


