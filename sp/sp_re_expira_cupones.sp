USE cob_bvirtual
GO

-- ==============================================================
--  Nombre: sp_re_expira_cupones
--  Objetivo:
--      Proceso batch que expira cupones de retiro de efectivo
--      cuyo vencimiento ya se cumplió.
--      Libera fondos (despignorar), marca el cupón como expirado,
--      lo registra en histórico y lo elimina de la tabla vigente.
--  Autor:
--  Fecha:
-- ==============================================================
IF EXISTS (SELECT 1
             FROM sysobjects
            WHERE name = 'sp_re_expira_cupones'
              AND type = 'P')
    DROP PROCEDURE sp_re_expira_cupones
GO

CREATE PROCEDURE sp_re_expira_cupones
AS
BEGIN

    --------------------------------------------------------------------------
    -- Declaración de variables de contexto COBIS
    --------------------------------------------------------------------------
    DECLARE
          @i_gen_ssn    CHAR(1)
        , @w_ejec       CHAR(1)
        , @w_corr       CHAR(1)
        , @w_rty        CHAR(1)
        , @w_return     INT
        , @w_ssn        INT
        , @w_sesn       INT
        , @w_reserva    INT
        , @w_ofi        SMALLINT
        , @w_moneda     SMALLINT
        , @w_msg_error  VARCHAR(255)
        , @w_sp_name    VARCHAR(50)
        , @w_term       VARCHAR(30)
        , @w_ipaddr     VARCHAR(30)
        , @w_srv        VARCHAR(30)
        , @w_lsrv       VARCHAR(30)
        , @w_from       VARCHAR(30)
        , @w_user       VARCHAR(20)
        , @w_date       DATETIME

    --------------------------------------------------------------------------
    -- Declaración de variables de trabajo de cupones
    --------------------------------------------------------------------------
    DECLARE
          @w_id           INT
        , @w_cupon        VARCHAR(80)
        , @w_codigo_cliente INT
        , @w_tipo_cuenta  CHAR(3)
        , @w_cta_banco    VARCHAR(20)
        , @w_monto        MONEY
        , @w_monto1       MONEY
        , @w_fecha_expira DATETIME
        , @w_num_reserva  INT
        , @w_val_reservar DECIMAL(18,2)
        , @w_num_error    INT
        , @w_desc_error   VARCHAR(255)
        , @w_estado       CHAR(1)

    --------------------------------------------------------------------------
    -- Configuración inicial
    --------------------------------------------------------------------------
    SET NOCOUNT ON
    SET @w_sp_name = 'sp_re_expira_cupones'
    SET @w_return  = 0

    --------------------------------------------------------------------------
    -- Definición del cursor: cupones vencidos y aún activos
    --------------------------------------------------------------------------
    DECLARE cur_cupon CURSOR FOR
        SELECT re_id,
               re_cupon,
               re_cliente,
               re_tipo_cta,
               re_cta_banco,
               re_moneda,
               re_monto,
               re_fecha_expira,
               re_num_reserva
          FROM re_retiro_efectivo
        -- WHERE  re_estado IN ('G','V')  -- solo pendientes o validados

    OPEN cur_cupon
    FETCH NEXT FROM cur_cupon
        INTO @w_id, @w_cupon, @w_codigo_cliente, @w_tipo_cuenta,
             @w_cta_banco, @w_moneda, @w_monto, @w_fecha_expira, @w_num_reserva

    --------------------------------------------------------------------------
    -- Iterar cupones vencidos
    --------------------------------------------------------------------------
    WHILE @@FETCH_STATUS = 0
    BEGIN
print 'hay registros w_monto %1!',@w_monto
        ----------------------------------------------------------------------
        -- Iniciar transacción por cada cupón
        ----------------------------------------------------------------------
    BEGIN TRAN TRANSACCION_EXPIRA





print 'x1 @w_monto %1!',@w_monto
        ----------------------------------------------------------------------
        -- 1. Obtener datos de sesión COBIS
        ----------------------------------------------------------------------
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
        -- 2. Liberar fondos (despignorar)
        ----------------------------------------------------------------------
        EXEC @w_return = sp_re_libera_fondos
                  @s_ssn            = @w_ssn
                , @s_srv            = @w_srv
                , @s_lsrv           = @w_lsrv
                , @s_user           = @w_user
                , @s_sesn           = @w_sesn
                , @s_term           = @w_term
                , @s_date           = @w_date
                , @s_ofi            = @w_ofi
                , @s_org            = 'N'
                , @t_from           = @w_from
                , @t_ejec           = @w_ejec
                , @t_corr           = @w_corr
                , @t_rty            = @w_rty
                , @t_trn            = 318  -- Despignorar
                , @i_cuenta         = @w_cta_banco
                , @i_valor_pignorar = @w_monto
                , @i_moneda         = @w_moneda
                , @i_accion         = 'E'  -- Eliminar / liberar
                , @i_cupon          = @w_cupon
                , @i_cliente        = @w_codigo_cliente
                , @i_val_reservar   = 0
                , @i_motivo         = 2
                , @i_sec            = @w_num_reserva
                , @i_reserva        = @w_num_reserva
                , @i_tipo_cta       = @w_tipo_cuenta
                , @i_fecha_expira   = @w_fecha_expira
                , @i_tarjeta        = '000000000000000'
                , @i_descripcion    = 'CUPON EXPIRADO POR PROCESO DE LIMPIEZA'
                , @o_reserva        = @w_reserva   OUT
                , @o_num_error      = @w_return    OUTPUT
                , @o_desc_error     = @w_msg_error OUTPUT
print '2 @w_return %1!',@w_return
        ----------------------------------------------------------------------
        -- 3. Validar resultado de liberación
        ----------------------------------------------------------------------
        IF @w_return != 0
        BEGIN
            SET @w_num_error  = @w_return
            SET @w_desc_error = 'Error en sp_re_libera_fondos: ' + @w_msg_error

            PRINT 'ROLLBACK en sp_re_libera_fondos. Error: %1!' , @w_return
            IF @w_return != 160009 begin
            ROLLBACK TRAN TRANSACCION_EXPIRA
            GOTO Next_Cupon
            end
        END

        ----------------------------------------------------------------------
        -- 4. Marcar cupón como expirado
        ----------------------------------------------------------------------
        UPDATE re_retiro_efectivo
           SET re_estado  = 'X',
               re_detalle = 'CUPON EXPIRADO POR PROCESO DE LIMPIEZA'
         WHERE re_id = @w_id

        ----------------------------------------------------------------------
        -- 5. Insertar cupón en histórico
        ----------------------------------------------------------------------
        INSERT INTO cob_bvirtual_his..re_his_retiro_efectivo (
              hr_cupon,       hr_cliente,     hr_accion,        hr_tipo_cta,   hr_cta_banco,
              hr_moneda,      hr_monto,       hr_hora_ult_proc, hr_estado,     hr_fecha_expira,
              hr_fecha_proc,  hr_usuario,     hr_terminal,      hr_oficina,    hr_resultado,
              hr_num_reserva, hr_detalle
        )
        SELECT re_cupon,       re_cliente,     re_accion,        re_tipo_cta,   re_cta_banco,
               re_moneda,      re_monto,       getdate(),        'X',           re_fecha_expira,
               re_fecha_proc,  re_usuario,     re_terminal,      re_oficina,    re_resultado,
               re_num_reserva, re_detalle
          FROM re_retiro_efectivo
         WHERE re_id = @w_id

        IF @@error <> 0
        BEGIN
            SET @w_num_error  = 500
            SET @w_desc_error = 'Error al insertar cupón en histórico re_his_retiro_efectivo'
            print '@w_desc_error 1 %1!',@w_desc_error
            ROLLBACK TRAN TRANSACCION_EXPIRA
            GOTO Next_Cupon
        END
print 'delete'
        ----------------------------------------------------------------------
        -- 6. Eliminar cupón de tabla vigente
        ----------------------------------------------------------------------
        print '@w_id %1!',@w_id
        DELETE FROM re_retiro_efectivo
         WHERE re_id = @w_id

        IF @@error <> 0
        BEGIN
            SET @w_num_error  = 600
            SET @w_desc_error = 'Error al eliminar cupón en tabla re_retiro_efectivo'
            print '@w_desc_error 2 %1!',@w_desc_error
            ROLLBACK TRAN TRANSACCION_EXPIRA
            GOTO Next_Cupon
        END
print 'COMMIT'
        ----------------------------------------------------------------------
        -- Confirmar transacción por cupón
        ----------------------------------------------------------------------
        COMMIT TRAN TRANSACCION_EXPIRA

        ----------------------------------------------------------------------
        -- Siguiente cupón
        ----------------------------------------------------------------------
        Next_Cupon:
        FETCH NEXT FROM cur_cupon
            INTO @w_id, @w_cupon, @w_codigo_cliente, @w_tipo_cuenta,
                 @w_cta_banco, @w_moneda, @w_monto, @w_fecha_expira, @w_num_reserva
    END

    --------------------------------------------------------------------------
    -- Cerrar cursor
    --------------------------------------------------------------------------
    CLOSE cur_cupon
    DEALLOCATE cur_cupon

END
GO
