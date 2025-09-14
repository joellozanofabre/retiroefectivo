USE cob_bvirtual
GO

IF EXISTS (
    SELECT 1
    FROM sysobjects
    WHERE name = 'sp_re_validacion_generales'
      AND type = 'P'
)
    DROP PROCEDURE sp_re_validacion_generales
GO

CREATE PROCEDURE sp_re_validacion_generales
(
      @i_cuenta_banco   cuenta
    , @i_monto          money
    , @i_moneda_iso     CHAR(3)
    , @o_cliente        INT            OUTPUT
    , @o_tipo_cuenta    cuenta         OUTPUT
    , @o_moneda         SMALLINT       OUTPUT
    , @o_idcuenta       INT       = 0  OUTPUT
    , @o_msg_error      VARCHAR(255)   OUTPUT
    , @o_num_error      INT            OUTPUT  -- agregado para retorno explícito
)
AS
DECLARE
      @w_tipo_ente     CHAR(1)
    , @w_id_cuenta     INT
    , @w_cod_error     INT
    , @w_multiplo_base DECIMAL(8)
    , @w_return        INT
    , @w_cod_cliente   INT

    SET @w_tipo_ente = NULL



    ----------------------------------------------------------------------
    -- Verificar productos habilitados
    ----------------------------------------------------------------------
    EXEC @w_return = cob_bvirtual..sp_ESB_verifica_productos @t_trn = 16

    IF @w_return <> 0
    BEGIN
        SELECT @o_num_error = @w_return,
               @o_msg_error = 'Producto Bancario Deshabilitado.'
        RETURN @o_num_error
    END


    ----------------------------------------------------------------------
    -- Validar moneda
    ----------------------------------------------------------------------
    if @i_moneda_iso is null
    begin
        select @w_cod_error = 18479,
               @o_msg_error = 'ERROR - MONEDA NO INGRESADA',
               @o_num_error = @w_cod_error
        return @o_num_error 
    end

    if len(@i_moneda_iso) <> 3
    begin
        select @w_cod_error = 121035,
               @o_msg_error = ' NO EXISTEN DATOS PARA LA MONEDA ESPECIFICADA',
               @o_num_error = @w_cod_error
        return @o_num_error 
    end

    if @i_moneda_iso not in ('USD','NIO')
    begin
        select @w_cod_error = 1880033,
               @o_msg_error = 'LA MONEDA EURO NO ESTA PERMITIDA PARA PIGNORACION',
               @o_num_error = @w_cod_error
        return @o_num_error 
    end   

    
    SELECT @o_moneda = mo_moneda
    FROM cobis..cl_moneda
    WHERE mo_simbolo = @i_moneda_iso
      AND mo_estado  = 'V'

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @w_cod_error = 101045,
               @o_msg_error = 'NO EXISTE MONEDA',
               @o_num_error = @w_cod_error
        RETURN @o_num_error
    END


    ----------------------------------------------------------------------
    -- Validación de monto null
    ----------------------------------------------------------------------
    if @i_cuenta_banco is null
    begin
        select @o_num_error = 708150,
               @o_msg_error = 'Campo requerido esta con valor nulo'
    return 1
    end

    ----------------------------------------------------------------------
    -- Validación de monto negativo
    ----------------------------------------------------------------------
    EXEC @w_return = cob_remesas..sp_valida_valor_negativo
         @i_val_otro = @i_monto

    IF @w_return <> 0
    BEGIN
        SELECT @o_num_error = @w_return
        RETURN @o_num_error
    END


    ----------------------------------------------------------------------
    -- Determinar el tipo de producto (Ahorros o Corriente)
    ----------------------------------------------------------------------
    EXEC @w_return = cob_bvirtual.dbo.sp_ESB_cons_tipo_cta
         @i_canal      = 0,
         @i_cta        = @i_cuenta_banco,
         @o_mon        = @o_moneda       OUT,
         @o_cuenta     = @w_id_cuenta    OUT,
         @o_tipo_cta   = @o_tipo_cuenta  OUT,
         @o_cliente    = @w_cod_cliente  OUT,
         @o_num_error  = @w_cod_error    OUT,
         @o_msg_error  = @o_msg_error    OUT

    IF @w_return <> 0
    BEGIN
        SELECT @w_cod_error = @w_return,
               @o_msg_error = @o_msg_error,
               @o_num_error = @w_cod_error
        RETURN @o_num_error
    END

    SELECT @o_idcuenta = @w_id_cuenta

    ----------------------------------------------------------------------
    -- Validar el tipo de cliente
    ----------------------------------------------------------------------
    IF @w_cod_cliente <> 0
    BEGIN
        SELECT @o_cliente = @w_cod_cliente

        SELECT @w_tipo_ente = en_subtipo
        FROM cobis..cl_ente
        WHERE en_ente = @w_cod_cliente

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT @w_cod_error = 121034,
                   @o_msg_error = 'CLIENTE NO EXISTE',
                   @o_num_error = @w_cod_error
            RETURN @o_num_error
        END
    END

    IF @w_tipo_ente <> 'P'
    BEGIN
        SELECT @w_cod_error = 160007,
               @o_msg_error = 'CLIENTE NO ES PERSONA NATURAL',
               @o_num_error = @w_cod_error
        RETURN @o_num_error
    END

    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    set  @o_num_error = 0
    RETURN @o_num_error
 
GO

IF OBJECT_ID('dbo.sp_re_validacion_generales') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.sp_re_validacion_generales >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.sp_re_validacion_generales >>>'
GO

GRANT EXECUTE ON dbo.sp_re_validacion_generales TO usrnetbanking
GO
