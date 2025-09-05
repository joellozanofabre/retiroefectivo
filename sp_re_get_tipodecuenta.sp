use cob_bvirtual
go

-- ===============================================================
-- Procedimiento: sp_re_get_tipodecuenta
-- Base:         cob_cuentas
-- Propósito:    Pignorar fondos de una cuenta corriente para retiro con cupón.
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_get_tipodecuenta'
              and type = 'P')
   drop procedure sp_re_get_tipodecuenta
go


create procedure sp_re_get_tipodecuenta
      @i_cuenta_banco  varchar(20)   -- Número de cuenta (entrada)
    , @i_moneda        smallint  --moneda de la cuenta
    , @o_id_cuenta     int        = null output -- Id único de la cuenta
    , @o_id_cliente    int        output
    , @o_tipo_cuenta   char(3)    output -- 'AHO' o 'CTE'
    , @o_msg_error     varchar(255) = null output -- Mensaje de error
as
declare 
    @w_sp_name   varchar(30),
    @w_cod_error int

set @w_sp_name = 'sp_get_id_cuenta'
set @w_cod_error = 0

---------------------------------------------------------------
-- Buscar en cuentas de Ahorros
---------------------------------------------------------------
select @o_id_cuenta   = ah_cuenta, 
       @o_tipo_cuenta = 'AHO',
       @o_id_cliente  = ah_cliente
  from cob_ahorros..ah_cuenta
 where ah_cta_banco = @i_cuenta_banco
       and ah_moneda = @i_moneda

if @@rowcount > 0
    return 0


---------------------------------------------------------------
-- Buscar en cuentas Corrientes
---------------------------------------------------------------
select @o_id_cuenta = cc_ctacte, 
       @o_tipo_cuenta = 'CTE',
       @o_id_cliente  = cc_cliente
  from cob_cuentas..cc_ctacte
 where cc_cta_banco = @i_cuenta_banco
     and cc_moneda = @i_moneda
if @@rowcount > 0
    return 0

---------------------------------------------------------------
-- Si no se encuentra en ninguna tabla
---------------------------------------------------------------
select @w_cod_error = 201004,
       @o_msg_error = 'LA CUENTA NO EXISTE O NO ES VÁLIDA'


return @w_cod_error
go

if object_id('dbo.sp_re_get_tipodecuenta') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_get_tipodecuenta >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_get_tipodecuenta >>>'
go
