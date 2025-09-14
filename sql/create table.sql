create  table dbo.ESB_det_servicios(
   ud_secuencial   numeric(18,0)  identity,
   ud_servicio   int  not null,
   ud_producto   varchar(5)  not null,
   ud_operacion   char(1)  not null,
   ud_moneda   varchar(3)  not null,
   ud_transaccion   int  not null,
   ud_causa   varchar(5)  not null,
   ud_descripcion   varchar(100)  not null,
   ud_reintegro   char(1)  not null,
   ud_estado   char(1)  not null
)
alter table dbo.ESB_det_servicios lock allpages
go

grant select on dbo.ESB_det_servicios
   to Query_Rol /*dbo*/
create unique clustered index idx_ESB_det_servicios on dbo.ESB_det_servicios ( ud_servicio ASC,ud_producto ASC,ud_operacion ASC,ud_moneda ASC,ud_reintegro ASC)


create  table dbo.ESB_det_servicios(
   ud_secuencial   numeric(18,0)  identity,
   ud_servicio   int  not null,
   ud_producto   varchar(5)  not null,
   ud_operacion   char(1)  not null,
   ud_moneda   varchar(3)  not null,
   ud_transaccion   int  not null,
   ud_causa   varchar(5)  not null,
   ud_descripcion   varchar(100)  not null,
   ud_reintegro   char(1)  not null,
   ud_estado   char(1)  not null
)
alter table dbo.ESB_det_servicios lock allpages
go

grant select on dbo.ESB_det_servicios
   to Query_Rol /*dbo*/
create unique clustered index idx_ESB_det_servicios on dbo.ESB_det_servicios ( ud_servicio ASC,ud_producto ASC,ud_operacion ASC,ud_moneda ASC,ud_reintegro ASC)