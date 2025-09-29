use cob_bvirtual
go

if exists (select 1 from sysobjects where name = 're_retiro_efectivo')
         drop TABLE re_retiro_efectivo

go


create table re_retiro_efectivo (
    re_id               int identity not null,      -- ID único de la traza
    re_cupon            varchar(80)     not null,   -- Código único del cupón
    re_cliente          int             not null,   -- Cliente que emite el retiro (solo naturales)
    re_accion           char(3)         not null,   -- Acción: PIGNORA, DESPIGNORA, APLICA
    re_tipo_cta         char(3)         not null,   -- AHO - CTE
    re_cta_banco        varchar(20)     not null,   -- Número de cuenta (ahorro/corriente)
    re_moneda           smallint        not null,   -- Moneda de la transacción
    re_monto            money           not null,   -- Monto retenido (pignorado)
    re_hora_ult_proc    datetime        not null,   -- Fecha/hora de generación última vez que se proceso
    re_fecha_proc       datetime        not null,   -- Fecha de proceso
    re_fecha_expira     datetime        not null,
    re_estado           char(1)         not null,   -- Estado: P=Pendiente, C=Consumido, X=Expirado, A=Anulado
    re_usuario          login           not null,   -- Usuario COBIS que genera
    re_terminal         varchar(30)     null,       -- Terminal / canal de origen
    re_oficina          smallint        null,       -- Oficina donde se genera
    re_resultado        char(1)         not null,   -- Resultado: E=éxito, F=falla
    re_num_reserva      int             not null,   -- Secuencial generado desde cobis
    re_intentos         int             default 0,  -- control de concurrencia
    re_detalle          varchar(255)    null        -- Mensaje adicional
)


go

create index ixe_re_cliente on re_retiro_efectivo(re_cta_banco)
create index ixe_re_cta on re_retiro_efectivo(re_cupon, re_cliente)

go


use cob_bvirtual_his
go

if exists (select 1 from sysobjects where name = 're_his_retiro_efectivo')
         drop TABLE re_his_retiro_efectivo

go


create table re_his_retiro_efectivo (
    hr_id               int identity not null,      -- ID único de la traza
    hr_cupon            varchar(80)     not null,   -- Código único del cupón
    hr_cliente          int             not null,   -- Cliente que emite el retiro (solo naturales)
    hr_accion           char(3)         not null,   -- Acción: PIGNORA, DESPIGNORA, RETIRO
    hr_tipo_cta         char(3)         not null,   -- AHO - CTE
    hr_cta_banco        varchar(20)     not null,   -- Número de cuenta (ahorro/corriente)
    hr_moneda           smallint        not null,   -- Moneda de la transacción
    hr_monto            money           not null,   -- Monto retenido (pignorado)
    hr_hora_ult_proc    datetime        null    ,     -- última vez que se procesó
    hr_fecha_proc       datetime        not null,   -- Fecha en que se hace efectivo
    hr_fecha_expira     datetime        not null,   -- Fecha de expiración del cupón
    hr_estado           char(1)         not null,   -- Estado: P=Pendiente, C=Consumido, X=Expirado, A=Anulado
    hr_usuario          login           not null,   -- Usuario COBIS que genera
    hr_terminal         varchar(30)     null,       -- Terminal / canal de origen
    hr_oficina          smallint        null,       -- Oficina donde se genera
    hr_resultado        char(1)         not null,   -- Resultado: E=éxito, F=falla
    hr_num_reserva      int             not null,   -- Secuancial generado desde cobis
    hr_intentos         int             default 0,  -- control de concurrencia
    hr_detalle          varchar(255)    null       -- Mensaje adicional

)

go

create index ixe_hr_fecha on re_his_retiro_efectivo(hr_fecha_proc,hr_cupon)
create index ixe_hr_cliente on re_his_retiro_efectivo(hr_cta_banco)


go

