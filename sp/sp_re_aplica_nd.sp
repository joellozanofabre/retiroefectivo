USE cob_bvirtual
GO

-- ===============================================================
-- Procedimiento: sp_re_aplica_nd
-- Base:         cob_bvirtual
-- Propósito:    Aplicar la Nota de Débito (ND) a la cuenta que generó el cupón.
-- NOTA: El control de transacción (BEGIN/COMMIT/ROLLBACK) 
--       debe manejarse en el SP padre.
-- ===============================================================

IF EXISTS (SELECT 1
             FROM sysobjects
            WHERE name = 'sp_re_aplica_nd'
              AND type = 'P')
   DROP PROCEDURE sp_re_aplica_nd
GO

CREATE PROCEDURE sp_re_aplica_nd
(
    -- Parámetros de sesión
    @s_srv           VARCHAR(30)
  , @s_user          VARCHAR(30)
  , @s_sesn          INT
  , @s_term          VARCHAR(10)
  , @s_date          DATETIME
  , @s_lsrv          VARCHAR(30)
  , @s_ofi           SMALLINT
  , @t_ssn_corr      INT = 0

    -- Parámetros de entrada
  , @i_cupon         VARCHAR(80)
  , @i_cliente       INT
  , @i_cuenta        cuenta
  , @i_valor_debitar MONEY
  , @i_moneda_iso    CHAR(3)
  , @i_moneda_tran   SMALLINT
  , @i_producto_deb  CHAR(3)
  , @i_num_reserva   INT 
  , @i_reverso       CHAR(1) = 'N' -- S/N
  , @i_fecha_expira  DATETIME
    -- Parámetros de salida
  , @o_secuencial    INT          OUTPUT
  , @o_num_error     INT          OUTPUT
  , @o_desc_error    VARCHAR(255) OUTPUT
)
AS
BEGIN
    ----------------------------------------------------------------------
    -- Variables de trabajo
    ----------------------------------------------------------------------
    DECLARE
        @w_return           INT
      , @w_ssn              INT
      , @w_tran_deb         INT
      , @w_id_cuenta        INT
      , @w_default          INT
      , @w_num_error        INT
      , @w_idcta            INT
      , @w_cod_error        INT
      , @w_rpc              VARCHAR(64)
      , @w_causa_deb        VARCHAR(5)
      , @w_descripcion_deb  VARCHAR(100)
      , @w_nombre_sp        VARCHAR(30)
      , @w_causa_nd         VARCHAR(5)
      , @w_msg_error        VARCHAR(100)
      , @w_descripcion      VARCHAR(100)
      , @w_detalle_resultado VARCHAR(100)
      , @w_servicio         CHAR(5)
      , @w_categoria        CHAR(1)
      , @w_tipocta          CHAR(1)
      , @w_rol_ente         CHAR(1)
      , @w_tipo_def         CHAR(1)
      , @w_tipo             CHAR(1)
      , @w_tipo_promedio    CHAR(1)
      , @w_personalizada    CHAR(1)
      , @w_resultado        CHAR(1)
      , @w_accion_traza     CHAR(3)
      , @w_pro_bancario     SMALLINT
      , @w_oficina          SMALLINT
      , @w_producto         TINYINT
      , @w_filial           TINYINT
      , @w_disponible       MONEY
      , @w_promedio1        MONEY
      , @w_prom_disp        MONEY
      , @w_valor_comision   MONEY
      , @w_ahora            DATETIME
      , @w_fecha_proceso    DATETIME
      , @w_estado           CHAR(1)



    ----------------------------------------------------------------------
    -- Inicialización
    ----------------------------------------------------------------------
    SET @w_servicio          = 'RESTD'  -- Servicio de Retiro sin Tarjeta
    set @w_detalle_resultado = 'APLICACION DE ND CUPON DE LA CUENTA: ' + @i_cuenta
    set @w_descripcion       = 'LIBERACION DE VALOR RESERVADO DE CUENTA DE AHORRO DESDE ATM'
    set @w_resultado         = 'E'
    set @w_nombre_sp         = 'sp_re_libera_fondos'
    set @w_accion_traza      = 'APL'   -- nota de debito aplicada
    set @w_estado            = 'U'  --G=Pendiente, V=Validando,U=usado X=Expirado, E=Error 
    SET @o_num_error         = 0
    set @w_valor_comision    = 0
    set @w_return            = 0
    set @w_ahora             = getdate()
    SET @o_desc_error        = NULL
      ------------------------------------


    -- Normalizar número de cuenta
    SELECT @i_cuenta = LTRIM(RTRIM(@i_cuenta))
    SELECT @i_cuenta = cobis.dbo.cta_cobis_iban(@i_cuenta, '1')
    select @w_fecha_proceso = convert(varchar(10), fp_fecha, 101)
      from cobis..ba_fecha_proceso

print 'llega a sp_re_aplica_nd @i_cuenta %1! ', @i_cuenta
    ----------------------------------------------------------------------
    -- Determinación de tipo de transacción (Débito)
    ----------------------------------------------------------------------
    EXEC cob_bvirtual..sp_ESB_det_servicio
         @i_servicio    = @w_servicio,
         @i_producto    = @i_producto_deb,
         @i_operacion   = 'D',
         @i_moneda      = @i_moneda_iso,
         @i_reintegro   = @i_reverso,
         @o_transaccion = @w_tran_deb        OUT,
         @o_causa       = @w_causa_deb       OUT,
         @o_descripcion = @w_descripcion_deb OUT

    IF @w_return > 0
    BEGIN
        SET @o_num_error = @w_return
        SET @o_desc_error = 'Error en sp_ESB_det_servicio'
        RETURN @o_num_error
    END

   print 'w_tran_deb %1! - @w_causa_deb %2!  ', @w_tran_deb , @w_causa_deb
    ----------------------------------------------------------------------
    -- Obtención de secuencial
    ----------------------------------------------------------------------
    EXEC @w_ssn = ADMIN...rp_ssn
    IF @@ERROR != 0 OR @w_ssn = 0
    BEGIN
        SET @o_num_error = 1
        SET @o_desc_error = 'Error al obtener secuencial rp_ssn'
        RETURN @o_num_error
    END

    ----------------------------------------------------------------------
    -- Determinación de procedimiento RPC según producto
    ----------------------------------------------------------------------
    SELECT @w_rpc = CASE @i_producto_deb
                        WHEN 'CTE' THEN 'cob_cuentas..sp_ccndc_automatica'
                        ELSE 'cob_ahorros..sp_ahndc_automatica'
                    END

    print 'ejecuta @w_rpc %1! ', @w_rpc
    ----------------------------------------------------------------------
    -- Ejecución de la ND (Nota de Débito)
    ----------------------------------------------------------------------
    EXEC @w_return = @w_rpc
         @s_srv          = @s_lsrv,
         @s_ofi          = @s_ofi,
         @s_ssn          = @w_ssn,
         @s_ssn_branch   = @w_ssn,
         @s_date         = @s_date,
         @s_user         = @s_user,
         @s_term         = @s_term,
         @t_trn          = @w_tran_deb,
         @i_cerror       = 'N',
         @i_cta          = @i_cuenta,
         @i_concepto_ext = @w_descripcion_deb,
         @i_val          = @i_valor_debitar,
         @i_cau          = @w_causa_deb,
         @i_mon          = @i_moneda_tran,
         @i_fecha        = @s_date,
         @i_cobsus       = 'N',
         @t_corr         = @i_reverso,
         @i_reverso      = NULL,
         @t_ssn_corr     = @t_ssn_corr,
         @o_secuencial   = @o_secuencial OUT

    IF @w_return <> 0 OR @@ERROR <> 0
    BEGIN
        SET @o_num_error = @w_return
        SET @o_desc_error = @w_rpc + ' - Error al realizar el débito en la cuenta: ' + @i_cuenta
        RETURN @o_num_error
    END

    print 'inrgresa de  %1! ', @w_rpc
    ----------------------------------------------------------------------
    -- Validación de cuenta según producto (Ahorros o Corriente)
    ----------------------------------------------------------------------
    IF @i_producto_deb = 'AHO'
    BEGIN
        SELECT @w_pro_bancario     = ah_prod_banc,
               @w_tipo_def        = ah_tipo_def, 
               @w_disponible      = ah_disponible,            
               @w_rol_ente        = ah_rol_ente, 
               @w_producto        = ah_producto,
               @w_tipocta         = ah_tipocta,
               @w_categoria       = ah_categoria,
               @w_promedio1       = ah_promedio1, 
               @w_default         = ah_default,
               @w_prom_disp       = ah_prom_disponible, 
               @w_oficina         = ah_oficina,
               @w_personalizada   = ah_personalizada, 
               @w_filial          = ah_filial
          FROM cob_ahorros..ah_cuenta 
         WHERE ah_cta_banco = @i_cuenta 
           AND ah_moneda    = @i_moneda_tran

        IF @@ROWCOUNT  = 0
        BEGIN
            SET @o_num_error = 251001
            SET @o_desc_error = 'CUENTA : ' + @i_cuenta  + ' NO EXISTE'
            RETURN @o_num_error
        END
    END
    ELSE IF @i_producto_deb = 'CTE'
    BEGIN
        SELECT @w_categoria       = cc_categoria,
               @w_tipocta         = cc_tipocta,
               @w_rol_ente        = cc_rol_ente,
               @w_tipo_def        = cc_tipo_def,
               @w_pro_bancario    = cc_prod_banc,
               @w_producto        = cc_producto,
               @w_tipo            = cc_tipo,
               @w_default         = cc_default,
               @w_personalizada   = cc_personalizada,
               @w_oficina         = cc_oficina,
               @w_filial          = cc_filial,
               @w_disponible      = cc_disponible,
               @w_promedio1       = cc_promedio1,
               @w_prom_disp       = cc_prom_disponible
          FROM cob_cuentas..cc_ctacte
         WHERE cc_cta_banco = @i_cuenta
           AND cc_moneda    = @i_moneda_tran
           AND cc_estado   NOT IN ('C', 'G')

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_num_error = 201004
            SET @o_desc_error = 'CUENTA : ' + @i_cuenta  + ' NO EXISTE'
            RETURN @o_num_error
        END
    END

/*
    ----------------------------------------------------------------------
    -- Generación de costos (Comisión por retiro)
    ----------------------------------------------------------------------
    EXEC @w_return = cob_remesas..sp_genera_costos
         @t_from        = 'sp_re_aplica_nd',
         @i_categoria   = @w_categoria, 
         @i_tipo_ente   = @w_tipocta,
         @i_rol_ente    = @w_rol_ente, 
         @i_tipo_def    = @w_tipo_def, 
         @i_prod_banc   = @w_pro_bancario, 
         @i_producto    = @w_producto,
         @i_moneda      = @i_moneda_tran, 
         @i_tipo        = 'R', 
         @i_codigo      = @w_default, 
         @i_servicio    = @w_servicio,  -- Ajustar según reglas del negocio
         @i_rubro       = 'CRET',   -- Comisión (definir en catálogo)
         @i_disponible  = @w_disponible, 
         @i_prom_disp   = @w_prom_disp, 
         @i_promedio    = @w_promedio1, 
         @i_personaliza = @w_personalizada, 
         @i_fecha       = @s_date,  
         @i_filial      = @w_filial, 
         @i_oficina     = @w_oficina, 
         @o_valor_total = @w_valor_comision OUT

    IF @w_return != 0 
    BEGIN
        SET @o_num_error = @w_return
        SET @o_desc_error = 'Error en sp_genera_costos'
        RETURN @o_num_error
    END

    SET @w_valor_comision = ISNULL(@w_valor_comision, 0)
   print 'regresa de genera costos @w_valor_comision %1! ', @w_valor_comision
    ----------------------------------------------------------------------
    -- Débito de Comisión (si aplica)
    ----------------------------------------------------------------------
    IF @w_valor_comision > 0
    BEGIN
        SELECT @w_causa_nd = pa_char
          FROM cobis..cl_parametro 
         WHERE pa_nemonico =  @w_servicio 
           AND pa_producto = @i_producto_deb   

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_num_error = 101077
            SET @o_desc_error = 'No existe parámetro NDSRPR'
            RETURN @o_num_error
        END

        -- Ejecutar ND de comisión
        EXEC @w_return = @w_rpc
             @s_srv          = @s_lsrv,
             @s_ofi          = @s_ofi,
             @s_ssn          = @w_ssn,
             @s_ssn_branch   = @w_ssn,
             @s_date         = @s_date,
             @s_user         = @s_user,
             @s_term         = @s_term,
             @t_trn          = @w_tran_deb,
             @i_cerror       = 'N',
             @i_cta          = @i_cuenta,
             @i_concepto_ext = 'Comisión Retiro',
             @i_val          = @w_valor_comision,
             @i_cau          = @w_causa_nd,
             @i_mon          = @i_moneda_tran,
             @i_fecha        = @s_date,
             @i_cobsus       = 'N',
             @t_corr         = @i_reverso,
             @i_reverso      = NULL,
             @t_ssn_corr     = @t_ssn_corr,
             @o_secuencial   = @o_secuencial OUT

        IF @w_return != 0
        BEGIN
            SET @o_num_error = @w_return
            SET @o_desc_error = 'Error al aplicar comisión de retiro'
            RETURN @o_num_error
        END
    END 
*/

 
    ----------------------------------------------------------------------
    -- Registrar traza del retiro
    ----------------------------------------------------------------------
   print 'sigue nd sp_re_traza_retiroefectivo'
   exec @w_return =  cob_bvirtual..sp_re_traza_retiroefectivo
      @i_cupon        = @i_cupon
    , @i_cliente      = @i_cliente
    , @i_accion       = @w_accion_traza
    , @i_tipo_cta     = @i_producto_deb
    , @i_cta_banco    = @i_cuenta
    , @i_moneda       = @i_moneda_tran
    , @i_monto        = @i_valor_debitar
    , @i_fecha_expira = @i_fecha_expira
    , @i_hora_ult_proc= @w_ahora
    , @i_estado       = @w_estado   --P=Pendiente, C=Consumido, X=Expirado
    , @i_fecha_proc   = @w_fecha_proceso
    , @i_usuario      = @s_user
    , @i_terminal     = @s_term
    , @i_oficina      = @s_ofi
    , @i_num_reserva  = @i_num_reserva
    , @i_resultado    = @w_resultado
    , @i_detalle      = @w_detalle_resultado
    , @o_num_error    = @w_cod_error      output
    , @o_msg_error    = @w_msg_error   output
    if @w_return <> 0
    begin
        set @o_num_error = @w_return
        set @o_desc_error = @w_msg_error
        return 1
    end


    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    SET @o_num_error = 0
    SET @o_desc_error = 'SUCCESS'
    RETURN @o_num_error
END
GO

IF OBJECT_ID('dbo.sp_re_aplica_nd') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.sp_re_aplica_nd >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.sp_re_aplica_nd >>>'
GO
