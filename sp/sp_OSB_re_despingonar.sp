use cob_bvirtual
go
/******************************************************************************/ 
/* Archivo:              sp_OSB_re_despignorar.sp                             */ 
/* Stored procedure:     sp_OSB_re_despignorar                                */ 
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
/* Orquestar el proceso de  despignoración y aplicacion de debito a la cuenta */
/* de ahorro o corriente  mediante cupón.                                     */ 
/******************************************************************************/ 
/*                               MODIFICACIONES                               */ 
/* FECHA        AUTOR                     TAREA             RAZÓN             */ 
/* 2025.08.21   Joel Lozano TechnoFocus   interfaz bus      Emisión Inicial.  */ 
/******************************************************************************/ 

if exists (select 1
             from sysobjects
            where name = 'sp_OSB_re_despignorar'
              and type = 'P')
   drop procedure sp_OSB_re_despignorar
go

create procedure sp_OSB_re_despignorar
(
      @i_DEBIT_ACCOUNT         varchar(35) -- Cuenta origen a pignorar
    , @i_AMOUNT                money       -- Monto a retirar
    , @i_CURRENCY              char(3)     -- Moneda
    , @i_CUPON                 varchar(40) -- Cupón generado
    , @i_REVERSO               char(1)     = 'N'  -- Indica si la transacción es un reverso
    -- Parámetros de salida
   	, @o_num_error         int            out
   	, @o_desc_error        varchar(132)   out
)

as
begin
    ----------------------------------------------------------------------
    -- Variables locales
    ----------------------------------------------------------------------
    declare 
          @i_gen_ssn     char(1)
        , @w_return       int
        , @w_msg_error    varchar(255)
        , @w_secuencial   int
        , @w_rpc          varchar(64)
        , @w_tran_deb     int
        , @w_cod_error    int
        , @w_causa_deb    varchar(5)
        , @w_desc_deb     varchar(100)
        , @w_sp_name     varchar(50)
        , @w_tipo_cuenta varchar(10)
        , @w_estado      varchar(10)
        , @w_codigo_cliente varchar(20)
        , @w_ssn         int
        , @w_user        login
        , @w_sesn        int
        , @w_term        varchar(30)
        , @w_ipaddr      varchar(30)
        , @w_reserva     int
        , @w_num_transaccion  smallint
        , @w_moneda       smallint
        , @w_date        datetime
        , @w_srv         varchar(30)
        , @w_lsrv        varchar(30)
        , @w_ofi         smallint
        , @w_from        varchar(30)        
        , @w_ejec        char(1)        
        , @w_corr        char(1)
        , @w_rty         char(1)
        , @w_idcuenta         int 
    --------------------------------------------------------------------------
    -- Inicialización de variables de salida
    --------------------------------------------------------------------------
    SET @o_num_error       = 0
    SET @o_desc_error      = 'SUCCESS'
    SET @w_sp_name         = 'sp_OSB_re_despignorar'
    SET @w_tipo_cuenta     = ''

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
        , @o_num_error = @w_cod_error       OUT
        , @o_desc_error = @w_msg_error       OUT

    IF @w_return <> 0
    BEGIN
        SELECT
              @o_num_error  = @w_cod_error
            , @o_desc_error = 'Error en sp_re_valida_cupon: ' + @w_msg_error
        RETURN 1
    END

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

    ----------------------------------------------------------------------
    -- Inicia transacción
    ----------------------------------------------------------------------
    begin tran TRANSACCION_RETIRO

    ----------------------------------------------------------------------
    -- 1. Liberar fondos (despignorar)
    ----------------------------------------------------------------------
    exec @w_return = cob_cuentas..sp_re_libera_fondos
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
            , @t_trn          = 4083 
            , @i_cuenta       = @i_DEBIT_ACCOUNT
            , @i_valor_pignorar = @i_AMOUNT
            , @i_moneda       = @w_moneda
            , @i_accion       = 'L'  -- reservar
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
            rollback tran TRANSACCION_RETIRO
            RETURN 1
        END
 

    
    ----------------------------------------------------------------------
    -- 2. Aplicar Nota de Débito (debitando la cuenta origen)
    ----------------------------------------------------------------------
    exec @w_return = cob_bvirtual..sp_re_aplica_nd
         @s_srv          = @w_srv,
         @s_user         = @w_user,
         @s_sesn         = @w_sesn,
         @s_term         = @w_term,
         @s_date         = @w_date,
         @s_lsrv         = @w_lsrv,
         @s_ofi          = @w_ofi,
         @i_cupon        = @i_CUPON,
         @i_cliente      = @w_codigo_cliente,
         @i_cuenta       = @i_DEBIT_ACCOUNT,
         @i_valor_debitar= @i_AMOUNT,
         @i_moneda_iso   = @i_CURRENCY,
         @i_moneda_tran  = @w_moneda,
         @i_producto_deb = @w_tipo_cuenta,
         @i_reverso      = @i_REVERSO,
         @o_secuencial   = @w_secuencial out,
         @o_num_error    = @w_return out,
         @o_desc_error   = @w_msg_error out
        IF @w_return != 0
        BEGIN
            SET @o_num_error  = @w_return
            SET @o_desc_error = 'Error en sp_re_aplica_nd: ' + @w_msg_error
            rollback tran TRANSACCION_RETIRO
            RETURN 1
        END

    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    commit tran TRANSACCION_RETIRO
    set @o_num_error = 0
    set @o_desc_error = 'Liberación y débito exitosos'
    return 0
end
go




-------------------------------------------------------------------------------
-- PERMISOS DE EJECUCIÓN
-------------------------------------------------------------------------------
IF (ROLE_ID('Service_Rol_Dev') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol_Dev

IF (ROLE_ID('Service_Rol_QA') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol_QA

IF (ROLE_ID('Service_Rol') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol
GO

EXEC sp_procxmode 'dbo.sp_OSB_re_despignorar', 'anymode'
GO




if object_id('dbo.sp_OSB_re_despignorar') is not null
    print '<<< CREATED PROCEDURE dbo.sp_OSB_re_despignorar >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_OSB_re_despignorar >>>'
go



