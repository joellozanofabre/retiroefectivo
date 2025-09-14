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
/* Orquestar el proceso de pignoración/despignoración de cuentas de ahorro o  */ 
/* corriente para operaciones de Retiro Efectivo mediante cupón.              */ 
/******************************************************************************/ 
/*                               MODIFICACIONES                               */ 
/* FECHA        AUTOR                     TAREA             RAZÓN             */ 
/* 2025.08.21   Joel Lozano TechnoFocus   interfaz bus      Emisión Inicial.  */ 
/******************************************************************************/ 

if exists (select 1
             from sysobjects
            where name = 'sp_re_valida_cupon'
              and type = 'P')
   drop procedure sp_re_valida_cupon
go
create procedure sp_re_valida_cupon
    @i_cupon        varchar(30),
    @o_cliente      int             output,
    @o_cta_banco    varchar(20)     output,
    @o_tipo_cta     char(3)         output,
    @o_moneda       smallint        output,
    @o_monto        money           output,
    @o_estado       char(1)         output,
    @o_cod_error    int             output,
    @o_msg_error    varchar(255)    output
as
begin
    set nocount on

    declare @w_estado    char(1),
            @w_hora_proc datetime,
            @w_id        int

    -- Buscar el cupón
    select top 1
           @w_id        = re_id,
           @o_cliente   = re_cliente,
           @o_cta_banco = re_cta_banco,
           @o_tipo_cta  = re_tipo_cta,
           @o_moneda    = re_moneda,
           @o_monto     = re_monto,
           @w_estado    = re_estado,
           @w_hora_proc = re_hora_ult_proc
    from re_retiro_efectivo
    where re_cupon = @i_cupon

    if @@rowcount = 0
    begin
        select @o_estado = 'E',
               @o_cod_error = 100,
               @o_msg_error = 'Cupón no existe'
        return 1
    end

    -- Validar expiración (24 horas)
    if datediff(hh, @w_hora_proc, getdate()) > 24
    begin
        update re_retiro_efectivo
        set re_estado = 'X',
            re_detalle = 'Cupón expirado por validación'
        where re_id = @w_id



        insert into re_his_retiro_efectivo (
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
                @o_cod_error = 500,
                @o_msg_error = 'Error al mover cupón al histórico'
            return 1
        end




        select @o_estado = 'X',
               @o_cod_error = 101,
               @o_msg_error = 'Cupón expirado'
        return 1
    end

    -- Validar estado actual
    if @w_estado <> 'G'
    begin
        select @o_estado   = @w_estado,
               @o_cod_error = 102,
               @o_msg_error = 'Cupón no disponible para uso'
        return 1
    end

    -- Control de concurrencia: pasar a Validando (V)
    update re_retiro_efectivo
    set re_estado = 'V',
        re_detalle = 'Cupón en validación',
        re_fecha_proc = getdate()
    where re_id = @w_id
      and re_estado = 'G'

    if @@rowcount = 0
    begin
        select @o_estado   = 'E',
               @o_cod_error = 103,
               @o_msg_error = 'Cupón tomado por otro proceso'
        return 1
    end

    -- Registrar traza
        insert into re_his_retiro_efectivo (
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
                @o_cod_error = 500,
                @o_msg_error = 'Error al mover cupón al histórico'
            return 1
        end
    -- Éxito
    select @o_estado = 'V',
           @o_cod_error = 0,
           @o_msg_error = 'EXITO'
    return 0
end
go





IF OBJECT_ID('dbo.sp_re_valida_cupon') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.sp_re_valida_cupon >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.sp_re_valida_cupon >>>'
GO
