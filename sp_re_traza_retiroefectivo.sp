use cob_bvirtual
go

-- ===============================================================
-- Procedimiento: sp_re_traza_retiroefectivo
-- Base:         cob_bvirtual
-- Propósito:    Registro de historial de transacciones .
-- ===============================================================

if exists (select 1
             from sysobjects
            where name = 'sp_re_traza_retiroefectivo'
              and type = 'P')
   drop procedure sp_re_traza_retiroefectivo
go


create proc sp_re_traza_retiroefectivo
(
      @i_cupon        varchar(30)
    , @i_num_reserva  int
    , @i_cliente      int
    , @i_accion       varchar(5)
    , @i_tipo_cta     char(3)
    , @i_cta_banco    varchar(30)
    , @i_moneda       smallint
    , @i_monto        money
    , @i_fecha_gen    datetime
    , @i_estado       char(1)
    , @i_cliente_dest int          = null
    , @i_fecha        datetime
    , @i_usuario      login
    , @i_terminal     varchar(30)  = null
    , @i_oficina      smallint     = null
    , @i_resultado    char(1)
    , @i_detalle      varchar(255) = null
    , @o_msg_error    varchar(255) out
)
as
begin
    declare @w_error     int,

            @w_nombre_sp varchar(50)

    set @w_error = 0
    set @w_nombre_sp = 'sp_re_traza_retiroefectivo'

    ----------------------------------------------------------------------
    -- Insertar traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    insert into re_retiro_efectivo 
    (
          re_cupon         , re_cliente       , re_accion      , re_cta_banco    , re_moneda
        , re_monto         , re_fecha_gen     , re_estado      , re_cliente_dest , re_fecha
        , re_usuario       , re_terminal      , re_oficina     , re_resultado    , re_detalle
        , re_tipo_cta      , re_num_reserva
    )
    values
    (
          @i_cupon         , @i_cliente       , @i_accion      , @i_cta_banco    , @i_moneda
        , @i_monto         , @i_fecha_gen     , @i_estado      , @i_cliente_dest , @i_fecha
        , @i_usuario       , @i_terminal      , @i_oficina     , @i_resultado    , @i_detalle
        , @i_tipo_cta      , @i_num_reserva
    )

    if @@rowcount = 0
    begin
        print 'Error al insertar en re_retiro_efectivo.'
        select @w_error = 208111
    end

    ----------------------------------------------------------------------
    -- Insertar traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    insert into re_his_retiro_efectivo 
    (
          hr_cupon         , hr_cliente       , hr_accion      , hr_cta_banco    , hr_moneda
        , hr_monto         , hr_fecha_gen     , hr_estado      , hr_cliente_dest , hr_fecha
        , hr_usuario       , hr_terminal      , hr_oficina     , hr_resultado    , hr_detalle
        , hr_tipo_cta      , hr_num_reserva      
    )
    values
    (
          @i_cupon         , @i_cliente       , @i_accion      , @i_cta_banco    , @i_moneda
        , @i_monto         , @i_fecha_gen     , @i_estado      , @i_cliente_dest , @i_fecha
        , @i_usuario       , @i_terminal      , @i_oficina     , @i_resultado    , @i_detalle
        , @i_tipo_cta      , @i_num_reserva
    )

    if @@rowcount = 0
    begin
        print 'Error al insertar en hr_retiro_efectivo.'
        select @w_error = 208112
    end

    ----------------------------------------------------------------------
    -- Manejo de error
    ----------------------------------------------------------------------
    if @w_error <> 0
    begin
        set @o_msg_error = @w_nombre_sp + 'Error al insertar en re_retiro_efectivo. Código: ' 
                           + convert(varchar, @w_error)
        return @w_error
    end

    return 0
end
go
if object_id('dbo.sp_re_traza_retiroefectivo') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_traza_retiroefectivo >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_traza_retiroefectivo >>>'
go
