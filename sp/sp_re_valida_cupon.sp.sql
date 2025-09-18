USE cob_bvirtual
GO
/******************************************************************************/ 
/* Archivo:              sp_re_valida_cupon.sp                                */ 
/* Stored procedure:     sp_re_valida_cupon                                   */ 
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
/* Validar la vigencia de un cupón de retiro efectivo y actualizar su estado  */ 
/* (Consumido, Expirado, En Validación) moviéndolo al histórico cuando aplique*/ 
/******************************************************************************/ 
/*                               MODIFICACIONES                               */ 
/* FECHA        AUTOR                     TAREA             RAZÓN             */ 
/* 2025.08.21   Joel Lozano TechnoFocus   interfaz bus      Emisión Inicial.  */ 
/******************************************************************************/ 

IF EXISTS (SELECT 1
             FROM sysobjects
            WHERE name = 'sp_re_valida_cupon'
              AND type = 'P')
   DROP PROCEDURE sp_re_valida_cupon
GO

CREATE PROCEDURE sp_re_valida_cupon
    @i_cupon        VARCHAR(30),         -- Código del cupón
    @i_valor        MONEY,               -- Monto esperado
    @o_cliente      INT          OUTPUT, -- Cliente asociado
    @o_cta_banco    VARCHAR(20)  OUTPUT, -- Cuenta bancaria
    @o_tipo_cta     CHAR(3)      OUTPUT, -- Tipo de cuenta
    @o_moneda       SMALLINT     OUTPUT, -- Moneda
    @o_monto        MONEY        OUTPUT, -- Monto
    @o_estado       CHAR(1)      OUTPUT, -- Estado del cupón
    @o_num_error    INT          OUTPUT, -- Código de error
    @o_desc_error   VARCHAR(132) OUTPUT, -- Descripción del error
    @o_fecha_expira DATETIME     OUTPUT, -- Fecha de expiración
    @o_num_reserva  INT          OUTPUT  -- Número de reserva
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @w_estado    CHAR(1),
            @w_hora_proc smallint,
            @w_id        INT
            
    set @o_num_error    = 0

    -------------------------------------------------------------------------
    -- 1. Validar existencia del cupón
    -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 
                     FROM re_retiro_efectivo 
                    WHERE re_cupon = @i_cupon)
    BEGIN  
        SELECT @o_estado     = 'E',
               @o_num_error  = 100,
               @o_desc_error = 'CUPON NO EXISTE'
        RETURN 1
    END

    -------------------------------------------------------------------------
    -- 2. Recuperar datos del cupón
    -------------------------------------------------------------------------
    SELECT TOP 1
           @w_id          = re_id,
           @o_cliente     = re_cliente,
           @o_cta_banco   = re_cta_banco,
           @o_tipo_cta    = re_tipo_cta,
           @o_moneda      = re_moneda,
           @o_monto       = re_monto,
           @w_estado      = re_estado,
           @w_hora_proc   = DATEDIFF(HH, re_fecha_expira, GETDATE()) ,
           @o_fecha_expira = re_fecha_expira,
           @o_num_reserva  = re_num_reserva
    FROM re_retiro_efectivo
    WHERE re_cupon = @i_cupon

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @o_estado     = 'E',
               @o_num_error  = 101,
               @o_desc_error = 'ERROR EN LOS VALORES DEL CUPON'
        RETURN 1
    END
--print '@w_id= %1! - @w_estado %2! - @w_hora_proc %3!', @w_id , @w_estado , @w_hora_proc
    -------------------------------------------------------------------------
    -- 3. Validar expiración (más de 24 horas)
    -------------------------------------------------------------------------
    IF @w_hora_proc > 24
    BEGIN
        print 'entra > 24 horas, expira cupón y lo mueve a histórico'
        UPDATE re_retiro_efectivo
        SET re_estado  = 'X',
            re_detalle = 'CUPON EXPIRADO'
        WHERE re_id = @w_id

        select @o_estado     = 'X'

        GOTO InsertaHistorico
    END


    ---------------------------------------------------------------------------------
    -- 4. Si el cupón ya está en validación y es ejecutado nuevamente, retornar éxito
    ----------------------------------------------------------------------------------
    IF @w_estado = 'V'
        GOTO Finaliza

    -------------------------------------------------------------------------
    -- 5. Validar estado actual (solo "Generado" es válido)
    -------------------------------------------------------------------------
    IF @w_estado NOT IN ('G')
    BEGIN
        SELECT @o_estado     = @w_estado,
               @o_num_error  = 102,
               @o_desc_error = 'Cupón no disponible para usar (Consumido o Expirado)'
        RETURN 1
    END

    -------------------------------------------------------------------------
    -- 6. Control de concurrencia: pasar a Validando (V)
    -------------------------------------------------------------------------
    UPDATE re_retiro_efectivo
    SET re_estado     = 'V',
        re_detalle    = 'CUPON EN PROCESO DE VALIDACION',
        re_fecha_proc = GETDATE()
    WHERE re_id = @w_id
      AND re_estado = 'G'

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @o_estado     = 'E',
               @o_num_error  = 103,
               @o_desc_error = 'Cupón tomado por otro proceso'
        RETURN 1
    END



       InsertaHistorico:
        insert into cob_bvirtual_his..re_his_retiro_efectivo (
            hr_cupon,        hr_cliente,      hr_accion,        hr_tipo_cta,     hr_cta_banco,
            hr_moneda,       hr_monto,        hr_hora_ult_proc, hr_estado,       hr_fecha_expira,
            hr_fecha_proc,   hr_usuario,      hr_terminal,      hr_oficina,      hr_resultado,
            hr_num_reserva,  hr_detalle
        )
        select
            re_cupon,        re_cliente,      re_accion,        re_tipo_cta,     re_cta_banco,
            re_moneda,       re_monto,        re_hora_ult_proc, re_estado,       re_fecha_expira,  -- cliente_dest opcional
            re_fecha_proc,   re_usuario,      re_terminal,      re_oficina,      re_resultado,
            re_num_reserva,  re_detalle
        from re_retiro_efectivo
        where re_id = @w_id

        if @@error <> 0
        begin
            select @o_estado    = 'E',
                @o_num_error = 500,
                @o_desc_error = 'Error al mover cupón al histórico'
            return 1
        end

    end
 

    -------------------------------------------------------------------------
    -- 7. Éxito
    -------------------------------------------------------------------------
    Finaliza:

    RETURN @o_num_error

go





IF OBJECT_ID('dbo.sp_re_valida_cupon') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.sp_re_valida_cupon >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.sp_re_valida_cupon >>>'
GO
