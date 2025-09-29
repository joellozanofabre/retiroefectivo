use cob_bvirtual
go

if exists (select 1
             from sysobjects
            where name = 'sp_re_valida_pignoracion'
              and type = 'P')
   drop procedure sp_re_valida_pignoracion
go

create procedure sp_re_valida_pignoracion
(
      @i_cuenta_banco   cuenta
    , @i_monto          money
    , @i_moneda         char(3)
    , @o_cliente        int          output
    , @o_tipo_cuenta    cuenta       output
    , @o_moneda         smallint     OUTPUT
    , @o_idcuenta       int     =0   OUTPUT
    , @o_num_error      INT            OUTPUT  -- agregado para retorno explícito
    , @o_msg_error      VARCHAR(255)   OUTPUT
)
as
declare
      @w_tipo_ente     char(1)
    , @w_id_cuenta     int
    , @w_cod_error     int
    , @w_multiplo_base decimal(8)
    , @w_return        int
    , @w_cod_cliente   int



    set @w_tipo_ente = NULL

    ----------------------------------------------------------------------
    -- Validar moneda
    ----------------------------------------------------------------------
    select @o_moneda = mo_moneda
    from cobis..cl_moneda
    where mo_simbolo = @i_moneda
    and mo_estado = 'V'
    if @@rowcount = 0
    begin
        select @w_cod_error = 101045,
               @o_msg_error = 'NO EXISTE MONEDA'
        return @w_cod_error
    end


    ----------------------------------------------------------------------
    -- Determinar el tipo de producto (Ahorros o Corriente)
    ----------------------------------------------------------------------
 exec @w_return = sp_re_validacion_generales
      @i_cuenta_banco   = @i_cuenta_banco
    , @i_monto          = @i_monto
    , @i_moneda_iso     = @i_moneda
    , @o_cliente        = @w_cod_cliente output
    , @o_tipo_cuenta    = @o_tipo_cuenta output
    , @o_moneda         = @o_moneda
    , @o_idcuenta       = @w_id_cuenta   output
    , @o_msg_error      = @o_msg_error   output
    , @o_num_error      = @w_cod_error   output
    if @w_return <> 0
    begin
        select @w_cod_error = @w_return,
               @o_msg_error = @o_msg_error
        return @w_cod_error
    end

    select @o_idcuenta = @w_id_cuenta
    ----------------------------------------------------------------------
    -- Validar el tipo de cliente
    ----------------------------------------------------------------------
    if @w_cod_cliente <> 0
    begin
        select @o_cliente = @w_cod_cliente
        select @w_tipo_ente = en_subtipo
          from cobis..cl_ente
         where en_ente = @w_cod_cliente
        if @@rowcount = 0
        begin
            select @w_cod_error = 121034,
                   @o_msg_error = 'CLIENTE NO EXISTE'
            return @w_cod_error
        end
    end



    if @w_tipo_ente <> 'P'
    begin
        select @w_cod_error = 160007,
               @o_msg_error = 'CLIENTE NO ES PERSONA NATURAL'
        return @w_cod_error
    end



    if (@i_monto % 100 != 0)
    begin
        select @w_cod_error = 160008,
               @o_msg_error = "EL VALOR SOLICITADO NO ES VÁLIDO. SOLO SE PERMITEN MÚLTIPLOS DE "+ cast(@w_multiplo_base as varchar)
        return @w_cod_error

    end


    ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    set  @o_num_error = 0
    RETURN @o_num_error

go


if object_id('dbo.sp_re_valida_pignoracion') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_valida_pignoracion >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_valida_pignoracion >>>'
go

