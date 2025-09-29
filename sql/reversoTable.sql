use cob_bvirtual
go

if exists (select 1 from sysobjects where name = 're_retiro_efectivo')
         drop TABLE re_retiro_efectivo

go


use cob_bvirtual_his
go

if exists (select 1 from sysobjects where name = 're_his_retiro_efectivo')
         drop TABLE re_his_retiro_efectivo

go
