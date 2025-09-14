



este archivo no dee ir ya lo hace el sp de pignoracion





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
    , @o_msg_error      varchar(255) output
)
as
declare 
      @w_tipo_ente     char(1)
	, @w_id_cuenta     int
	, @w_cod_error     int
	, @w_multiplo_base decimal(8)
	, @w_return        int
	, @w_cod_cliente   int

begin
    
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


  -- Verificamos que los productos se encuentren habilitados.
  exec @w_return = cob_bvirtual..sp_ESB_verifica_productos @t_trn =
  if @w_return <> 0
  begin
   select @o_num_error  = @w_return,
          @o_desc_error = 'Producto Bancario Deshabilitado.'

   return @o_num_error
  end

--Validacion Monto Negativo
  exec @w_return   = cob_remesas..sp_valida_valor_negativo
       @i_val_otro = @i_monto
  if @w_return != 0
     return @w_return




    if @i_cuenta_banco is null
    begin
        select @o_num_error = 708150,
                @o_desc_error = 'Campo requerido esta con valor nulo'
    return 1
    end


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
         @o_desc_error = @o_msg_error    OUT

    IF @w_return <> 0
    BEGIN
        select @w_cod_error = @w_return, 
               @o_msg_error = @o_msg_error
        return @w_cod_error
    END


    select @o_idcuenta = @w_id_cuenta




  -- Verifica el codigo de la moneda de la OPERACION
  if @i_OPERATION_CURRENCY not in (@w_moneda_deb_iso, @w_moneda_cre_iso)
  begin
    set @o_desc_error = @w_sp_name+ ' - ' + 'ERROR MONEDA DE LA OPERACION NO VALIDA: '+@i_OPERATION_CURRENCY
    set @o_num_error  = 30028
    exec cobis..sp_cerror
          @i_sev  = 0,
          @i_msg  = @o_desc_error,
          @i_num  = @o_num_error
     return @o_num_error
  end




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


    return 0
end
go


if object_id('dbo.sp_re_valida_pignoracion') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_valida_pignoracion >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_valida_pignoracion >>>'
go

grant execute on dbo.sp_re_valida_pignoracion to usrnetbanking
go
