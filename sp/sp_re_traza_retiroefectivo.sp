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
      @i_cupon          varchar(30)
    , @i_num_reserva    int
    , @i_cliente        int
    , @i_accion         varchar(5)
    , @i_tipo_cta       char(3)
    , @i_cta_banco      varchar(30)
    , @i_moneda         smallint
    , @i_monto          money
    , @i_fecha_proc     datetime
    , @i_fecha_expira   datetime     = null
    , @i_hora_ult_proc  date
    , @i_estado         char(1)
    , @i_usuario        login
    , @i_terminal       varchar(30)  = null
    , @i_oficina        smallint     = null
    , @i_resultado      char(1)
    , @i_detalle        varchar(255) = null
    , @o_cod_error      int          output
    , @o_msg_error      varchar(255) out
)
as
 
    declare @w_error     int,
            @w_nombre_sp varchar(50),
            @w_intentos  smallint

    set @w_error = 0
    set @w_nombre_sp = 'sp_re_traza_retiroefectivo'
 
    select @w_intentos = isnull(re_intentos,0) + 1
    from   re_retiro_efectivo
    where  re_cupon = @i_cupon

   
    ----------------------------------------------------------------------
    -- Insertar traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    insert into re_retiro_efectivo 
    (
          re_cupon,       re_cliente,    re_accion,     re_tipo_cta,    re_cta_banco
        , re_moneda,      re_monto,      re_fecha_proc, re_fecha_expira,re_hora_ult_proc
        , re_estado,      re_usuario,    re_terminal,   re_oficina,     re_resultado
        , re_num_reserva, re_detalle,    re_intentos
    )
    values
    (
          @i_cupon,       @i_cliente,    @i_accion,     @i_tipo_cta,    @i_cta_banco
        , @i_moneda,      @i_monto,      @i_fecha_proc, @i_fecha_expira,@i_hora_ult_proc
        , @i_estado,      @i_usuario,    @i_terminal,   @i_oficina,     @i_resultado
        , @i_num_reserva, @i_detalle,    1
    )


    if @@error <> 0
    begin
        set @w_error = 208111
        goto ERROR_HANDLER
    end

    ----------------------------------------------------------------------
    -- Insertar traza en re_retiro_efectivo
    ----------------------------------------------------------------------
    insert into re_his_retiro_efectivo
    (
          hr_cupon,       hr_cliente,    hr_accion,     hr_tipo_cta,    hr_cta_banco
        , hr_moneda,      hr_monto,      hr_fecha_proc, hr_fecha_expira,hr_hora_ult_proc
        , hr_estado,      hr_usuario,    hr_terminal,   hr_oficina,     hr_resultado
        , hr_num_reserva, hr_detalle,    hr_intentos
    )
    values
    (
          @i_cupon,       @i_cliente,    @i_accion,     @i_tipo_cta,    @i_cta_banco
        , @i_moneda,      @i_monto,      @i_fecha_proc, @i_fecha_expira,@i_hora_ult_proc
        , @i_estado,      @i_usuario,    @i_terminal,   @i_oficina,     @i_resultado
        , @i_num_reserva, @i_detalle,    @w_intentos
    )


    if @@error <> 0
    begin
        set @w_error = 208111
        goto ERROR_HANDLER
    end

   ----------------------------------------------------------------------
    -- Éxito
    ----------------------------------------------------------------------
    set @o_cod_error = 0
    set @o_msg_error = 'EXITO'
    return 0


    ----------------------------------------------------------------------
    -- Manejo de errores
    ----------------------------------------------------------------------
    ERROR_HANDLER:
        set @o_cod_error = @w_error
        set @o_msg_error = @w_nombre_sp + ' Error al insertar. Código: ' 
                           + convert(varchar, @w_error)
        return 1
 

    
 
go
if object_id('dbo.sp_re_traza_retiroefectivo') is not null
    print '<<< CREATED PROCEDURE dbo.sp_re_traza_retiroefectivo >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_re_traza_retiroefectivo >>>'
go
