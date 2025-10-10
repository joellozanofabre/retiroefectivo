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
    , @i_CUPON                 varchar(80) -- Cupón generado
    , @i_ONLYRELEASE           char(1)     = 'N'  -- Indica si la transacción es para liberar unicamente
   	, @o_num_error             int            out
   	, @o_desc_error            varchar(132)   out
)
as
begin
    ----------------------------------------------------------------------
    -- Variables locales
    ----------------------------------------------------------------------
declare
    -- Caracteres
      @i_gen_ssn             char(1)
    , @w_ejec                char(1)
    , @w_corr                char(1)
    , @w_rty                 char(1)
    , @w_estado              char(1)
    , @w_tipo_cuenta         char(3)
    , @w_aplicanotadedebito  char(1)
    -- Números enteros
    , @w_return              int
    , @w_secuencial          int
    , @w_tran_deb            int
    , @w_cod_error           int
    , @w_codigo_cliente      int
    , @w_ssn                 int
    , @w_sesn                int
    , @w_reserva             int
    , @w_num_reserva         int
    , @w_idcuenta            int
    -- Numéricos pequeños
    , @w_num_transaccion     smallint
    , @w_moneda              smallint
    , @w_ofi                 smallint
    -- Texto
    , @w_causa_deb           varchar(5)
    , @w_msg_error           varchar(255)
    , @w_desc_deb            varchar(100)
    , @w_rpc                 varchar(64)
    , @w_sp_name             varchar(50)
    , @w_term                varchar(30)
    , @w_ipaddr              varchar(30)
    , @w_srv                 varchar(30)
    , @w_lsrv                varchar(30)
    , @w_from                varchar(30)
    , @w_cta_banco           varchar(30)
    -- Otros tipos
    , @w_user                login
    , @w_date                datetime
    , @w_fecha_expira        datetime
    , @w_val_reservar        money


    --------------------------------------------------------------------------
    -- Inicialización de variables de salida
    --------------------------------------------------------------------------
    SET @o_num_error       = 0
    SET @o_desc_error      = 'SUCCESS'
    SET @w_sp_name         = 'sp_OSB_re_despignorar'
    SET @w_tipo_cuenta     = ''
    set @w_val_reservar    = 0
    set @w_num_reserva     = 0
    set @w_aplicanotadedebito = 'S'  -- por defecto aplica nota de debito


    --------------------------------------------------------------------------
    -- Paso 2: Validación de cupón
    --------------------------------------------------------------------------
    EXEC @w_return = sp_re_valida_cupon
          @i_cupon        = @i_CUPON
        , @i_valor        = @i_AMOUNT
        , @o_cliente      = @w_codigo_cliente  OUT
        , @o_cta_banco    = @w_cta_banco       OUT
        , @o_tipo_cta     = @w_tipo_cuenta     OUT
        , @o_moneda       = @w_moneda          OUT
        , @o_monto        = @i_AMOUNT          OUT
        , @o_estado       = @w_estado          OUT
        , @o_num_error    = @w_cod_error       OUT
        , @o_desc_error   = @w_msg_error       OUT
        , @o_fecha_expira = @w_fecha_expira    OUT
        , @o_num_reserva  = @w_num_reserva     OUT
    IF @w_return <> 0
    BEGIN
        SELECT
              @o_num_error  = @w_cod_error
            , @o_desc_error = 'Error en sp_re_valida_cupon: ' + @w_msg_error
        RETURN @w_cod_error
    END
    --------------------------------------------------------------------------
    -- Paso 2.1: Si el cupón está expirado, eliminar de tabla vigente
    --------------------------------------------------------------------------
    IF @w_estado = 'X'
    BEGIN

        DELETE FROM re_retiro_efectivo
        WHERE re_cupon = @i_CUPON

        IF @@error <> 0
        BEGIN
            SET @o_num_error  = 169265
            SET @o_desc_error = 'ERROR AL ELIMINAR CUPÓN EXPIRADO EN TABLA RE_RETIRO_EFECTIVO'
            RETURN  @o_num_error
        END

        -- Devolver mensaje de expiración
        SET @o_num_error  = 169266
        SET @o_desc_error = 'CUPÓN EXPIRADO Y ELIMINADO DE TABLA RE_RETIRO_EFECTIVO'

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
        -- 1. Obligatorio Liberar fondos (despignorar) a la reserva en la base de datos respectiva
        ----------------------------------------------------------------------
        exec @w_return = sp_re_libera_fondos
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
                , @t_trn          = 318  --Despignorar
                , @i_cuenta       = @i_DEBIT_ACCOUNT
                , @i_valor_pignorar = @i_AMOUNT
                , @i_moneda       = @w_moneda
                , @i_accion       = 'E'  -- reservar
                , @i_cupon        = @i_CUPON
                , @i_cliente      = @w_codigo_cliente
                , @i_val_reservar = @w_val_reservar
                , @i_motivo       = 2
                , @i_sec          = @w_num_reserva
                , @i_reserva      = @w_num_reserva
                , @i_tipo_cta     = @w_tipo_cuenta
                , @i_fecha_expira = @w_fecha_expira
                , @i_tarjeta      = '000000000000000'
                , @o_reserva      = @w_reserva   OUT
                , @o_num_error    = @w_return    OUTPUT
                , @o_desc_error    = @w_msg_error OUTPUT
            IF @w_return != 0
            BEGIN
                SET @o_num_error  = @w_return
                SET @o_desc_error = 'ERROR EN SP_RE_LIBERA_FONDOS: ' + @w_msg_error
                rollback tran TRANSACCION_RETIRO
                RETURN @w_return
            END
        ----------------------------------------------------------------------
        -- si no esta expirado y no es solo liberacion
        ----------------------------------------------------------------------
        IF @w_estado = 'X'  or @i_ONLYRELEASE = 'S'
          set @w_aplicanotadedebito = 'N'  -- no aplica nota de debito


        ----------------------------------------------------------------------
        -- 2. Aplicar Nota de Débito (debitando la cuenta origen)'
        ----------------------------------------------------------------------

        IF @w_aplicanotadedebito = 'S'
        begin
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
                @i_num_reserva  = @w_num_reserva,
                @i_producto_deb = @w_tipo_cuenta,
                @i_reverso      = 'N',
                @i_fecha_expira = @w_fecha_expira,
                @o_secuencial   = @w_secuencial out,
                @o_num_error    = @w_return out,
                @o_desc_error   = @w_msg_error out
                IF @w_return != 0
                BEGIN
                    SET @o_num_error  = @w_return
                    SET @o_desc_error = 'Error en sp_re_aplica_nd: ' + @w_msg_error
                    rollback tran TRANSACCION_RETIRO
                    RETURN @w_return
                END
        end

   -- print 'El cupón está Liberado, se procede a eliminar de tabla vigente re_retiro_efectivo.'
    DELETE FROM re_retiro_efectivo
    WHERE re_cupon = @i_CUPON

    IF @@error <> 0
    BEGIN
        SET @o_num_error  = 169263
        SET @o_desc_error = 'ERROR AL ELIMINAR CUPÓN LIBERADO EN TABLA RE_RETIRO_EFECTIVO'
        RETURN @o_num_error
    END

    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    commit tran TRANSACCION_RETIRO
    set @o_num_error = 0
    if @i_ONLYRELEASE = 'S'
        set @o_desc_error = 'LIBERACIÓN DE CUPÓN' + @i_CUPON + ' EXITOSA'
    else
        set @o_desc_error = 'LIBERACIÓN y DEBITO DE CUPÓN' + @i_CUPON + ' EXITOSA'
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



