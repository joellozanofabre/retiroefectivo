use cob_bvirtual
go
/******************************************************************************/
/* Archivo:              sp_OSB_re_is_cta_bloqueada                           */
/* Stored procedure:     sp_OSB_re_is_cta_bloqueada                           */
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
/* Orquestar el proceso de  liberacion de fondos reservados  en las cuentas   */
/* de ahorro o corriente  mediante cupón.                                     */
/******************************************************************************/
/*                               MODIFICACIONES                               */
/* FECHA        AUTOR                     TAREA             RAZÓN             */
/* 2025.08.21   Joel Lozano TechnoFocus   sp consulta cta   Emisión Inicial.  */
/******************************************************************************/

-- ===============================================================
-- Procedimiento: sp_OSB_re_is_cta_bloqueada
-- Base:         cob_ahorros
-- Propósito:    Pignorar fondos de una cuenta de ahorro para retiro con cupón.
-- ===============================================================
if exists (select 1
             from sysobjects
            where name = 'sp_OSB_re_is_cta_bloqueada'
              and type = 'P')
   drop procedure sp_OSB_re_is_cta_bloqueada
go


CREATE PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada
(
      @i_DEBIT_ACCOUNT         cuenta      -- Cuenta origen a pignorar
    , @i_CURRENCY              char(3)     -- Moneda
    , @o_num_error             int output  -- Código de salida
    , @o_desc_error            varchar(100) output -- Mensaje detalle
)
AS


declare
     @w_sp_name          varchar(30)
   , @w_tipo_bloqueo     varchar(2)
   , @w_mensaje          varchar(255)
   , @w_tipo_cuenta      char(3)
   , @w_return           int
   , @w_codigo_cliente   int
   , @w_idcuenta         int
   , @w_num_transaccion  smallint
   , @w_cod_error        int
   , @w_msg_error        varchar(255)


  set  @w_sp_name   = 'sp_OSB_re_is_cta_bloqueada'
	SET @o_num_error  = 0
	SET @o_desc_error = 'SIN BLOQUEO'
  SET @w_idcuenta        = 0



     --------------------------------------------------------------------------
    -- Paso 1: Validaciones previas de la pignoración
    --------------------------------------------------------------------------
 exec @w_return = sp_re_validacion_generales
      @i_cuenta_banco   = @i_DEBIT_ACCOUNT
    , @i_monto          = 0
    , @i_moneda_iso     = @i_CURRENCY
    , @o_cliente        = @w_codigo_cliente output
    , @o_tipo_cuenta    = @w_tipo_cuenta    output
    , @o_moneda         = @w_num_transaccion OUTPUT
    , @o_idcuenta       = @w_idcuenta   output
    , @o_msg_error      = @w_msg_error   output
    , @o_num_error      = @w_cod_error   output
    IF @w_return != 0
    BEGIN
        SET @o_num_error  = @w_cod_error
        SET @o_desc_error = 'Error en sp_re_validacion_generales: ' + @w_msg_error
        RETURN @w_cod_error
    END

if @w_tipo_cuenta = 'CTE'
begin
    -- ===== CUENTA CORRIENTE =====

    select @w_tipo_bloqueo = cb_tipo_bloqueo
      from cob_cuentas..cc_ctabloqueada
     where cb_cuenta = @w_idcuenta
       and cb_estado = 'V'
       and cb_tipo_bloqueo in     (
        '2',  --	CONTRA RETIRO
        '3'    -- CONTRA DEPOSITO Y RETIRO
      )


    if @@rowcount != 0
    begin
        select @w_mensaje = rtrim(valor)
          from cobis..cl_catalogo
         where tabla = (select codigo from cobis..cl_tabla
                         where tabla = 'cc_tbloqueo')
           and codigo = @w_tipo_bloqueo

        select @w_mensaje = 'Cuenta bloqueada: ' + @w_mensaje

        SET @o_num_error  = 201008
        SET @o_desc_error =  @w_mensaje
        RETURN @o_num_error
    end
end
else if @w_tipo_cuenta = 'AHO'
begin
    /* ===== CUENTA DE AHORROS ===== */


    select @w_tipo_bloqueo = cb_tipo_bloqueo
      from cob_ahorros..ah_ctabloqueada
     where cb_cuenta = @w_idcuenta
       and cb_estado = 'V'
       and cb_tipo_bloqueo in
       (
        '2',  --	CONTRA RETIRO
        '3'    -- CONTRA DEPOSITO Y RETIRO
      )
    if @@rowcount != 0
    begin
        select @w_mensaje = rtrim(valor)
          from cobis..cl_catalogo
         where tabla = (select codigo from cobis..cl_tabla
                         where tabla = 'ah_tbloqueo')
           and codigo = @w_tipo_bloqueo

        select @w_mensaje = 'Cuenta bloqueada: ' + @w_mensaje

        SET @o_num_error  = 201009
        SET @o_desc_error = @w_mensaje
        RETURN @o_num_error

    end
end

return 0
go

-------------------------------------------------------------------------------
-- PERMISOS DE EJECUCIÓN
-------------------------------------------------------------------------------
IF (ROLE_ID('Service_Rol_Dev') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol_Dev

IF (ROLE_ID('Service_Rol_QA') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol_QA

IF (ROLE_ID('Service_Rol') > 0)
    GRANT EXECUTE ON dbo.sp_OSB_re_despignorar TO Service_Rol
GO

EXEC sp_procxmode 'dbo.sp_OSB_re_despignorar', 'anymode'
GO


if object_id('dbo.sp_OSB_re_is_cta_bloqueada') is not null
    print '<<< CREATED PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada >>>'
else
    print '<<< FAILED CREATING PROCEDURE dbo.sp_OSB_re_is_cta_bloqueada >>>'
go
