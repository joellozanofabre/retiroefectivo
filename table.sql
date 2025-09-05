use cob_bvirtual
go

if exists (select 1 from sysobjects where name = 're_retiro_efectivo')
         drop TABLE re_retiro_efectivo
         
go


create table re_retiro_efectivo (
    re_id               int identity not null,         -- ID único de la traza
    re_cupon            varchar(30)     not null,   -- Código único del cupón
    re_cliente          int             not null,   -- Cliente que emite el retiro (solo naturales)
    re_accion           char(3)         not null,   -- Acción: PIGNORA, DESPIGNORA, RETIRO
    re_tipo_cta         char(3)         not null,   -- AHO - CTE
    re_cta_banco        varchar(20)     not null,   -- Número de cuenta (ahorro/corriente)
    re_moneda           smallint        not null,   -- Moneda de la transacción
    re_monto            money           not null,   -- Monto retenido (pignorado)
    re_fecha_gen        datetime        not null,   -- Fecha/hora de generación
    re_estado           char(1)         not null,   -- Estado: P=Pendiente, C=Consumido, X=Expirado, A=Anulado
    re_cliente_dest     int             null,       -- Cliente que hará efectivo (opcional, si ya está definido)
    re_fecha            datetime        not null,   -- Fecha en que se hace efectivo
    re_usuario          login           not null,   -- Usuario COBIS que genera
    re_terminal         varchar(30)     null,       -- Terminal / canal de origen
    re_oficina          smallint        null,       -- Oficina donde se genera
    re_resultado        char(1)         not null,   -- Resultado: E=éxito, F=falla
    re_num_reserva      int             not null,    -- Secuencial generado desde cobis
    re_detalle          varchar(255)    null        -- Mensaje adicional
)


go

create index ixe_re_cliente on re_retiro_efectivo(re_cliente)
create index ixe_re_cta on re_retiro_efectivo(re_cupon, re_cliente)

go



if exists (select 1 from sysobjects where name = 're_his_retiro_efectivo')
         drop TABLE re_his_retiro_efectivo
         
go


create table re_his_retiro_efectivo (
    hr_id               int identity not null,         -- ID único de la traza
    hr_cupon            varchar(30)     not null,   -- Código único del cupón
    hr_cliente          int             not null,   -- Cliente que emite el retiro (solo naturales)
    hr_accion           char(3)         not null,   -- Acción: PIGNORA, DESPIGNORA, RETIRO
    hr_tipo_cta         char(3)         not null,   -- AHO - CTE
    hr_cta_banco        varchar(20)     not null,   -- Número de cuenta (ahorro/corriente)
    hr_moneda           smallint        not null,   -- Moneda de la transacción
    hr_monto            money           not null,   -- Monto retenido (pignorado)
    hr_fecha_gen        datetime        not null,   -- Fecha/hora de generación
    hr_estado           char(1)         not null,   -- Estado: P=Pendiente, C=Consumido, X=Expirado, A=Anulado
    hr_cliente_dest     int             null,       -- Cliente que hará efectivo (opcional, si ya está definido)
    hr_fecha            datetime        not null,   -- Fecha en que se hace efectivo
    hr_usuario          login           not null,   -- Usuario COBIS que genera
    hr_terminal         varchar(30)     null,       -- Terminal / canal de origen
    hr_oficina          smallint        null,       -- Oficina donde se genera
    hr_resultado        char(1)         not null,   -- Resultado: E=éxito, F=falla
    hr_num_reserva      int             not null,    -- Secuancial generado desde cobis
    hr_detalle          varchar(255)    null       -- Mensaje adicional
    
)

go

create index ixe_hr_cliente on re_his_retiro_efectivo(hr_cliente)
create index ixe_hr_cta on re_his_retiro_efectivo(hr_cupon, hr_cliente, hr_fecha)

go

