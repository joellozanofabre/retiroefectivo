/******************************************************************************/
/* Proyecto:           RETIRO EFECTIVO                                        */
/* Archivo:            cob_bvirtual.sql                                       */
/* Base de datos:      cob_bvirtual                                           */
/* Diseñado por:       Technofocus                                            */
/* Fecha escritura:    10/sep/2025                                            */
/******************************************************************************/
/*                                 PROPÓSITO                                  */
/******************************************************************************/
/* Parametrización en tabla de COBIS:                                         */
/*   1. Nuevos parámetros de CONTRACT para Claro Recargas                     */
/******************************************************************************/
/*                              MODIFICACIONES                                */
/******************************************************************************/
/* FECHA        AUTOR                   RAZÓN                                 */
/* 21/JUN/2022  Joel Lozano Technofocus                                       */
/******************************************************************************/

------------------------------------------------------------------------
-- Definición de parametría contable: Transacciones y causas
------------------------------------------------------------------------

USE cob_bvirtual
GO

DECLARE
    @wus_servicio INT,
    @w_nemonico   VARCHAR(20),
    @w_causa      varchar(5)

-- Transacción de desembolsos
SET @w_nemonico = 'RESTD'
set @w_causa    = '740'
-- Limpieza previa: eliminar si ya existe
IF EXISTS (SELECT 1
             FROM cob_bvirtual..ESB_servicios
            WHERE us_nemonico = @w_nemonico)
    DELETE cob_bvirtual..ESB_servicios
     WHERE us_nemonico = @w_nemonico

-- Insert de cabecera de servicio
INSERT INTO cob_bvirtual..ESB_servicios (us_descripcion, us_nemonico, us_estado)
VALUES ('RETIRO DE EFECTIVO SIN TD', @w_nemonico, 'V')

-- Obtener el ID del servicio recién insertado
SELECT @wus_servicio = us_servicio
  FROM cob_bvirtual..ESB_servicios
 WHERE us_nemonico = @w_nemonico

IF @@ROWCOUNT <> 0
BEGIN
    -- Eliminar detalle previo si existía
    IF EXISTS (SELECT 1
                 FROM cob_bvirtual..ESB_det_servicios
                WHERE ud_servicio = @wus_servicio)
        DELETE cob_bvirtual..ESB_det_servicios
         WHERE ud_servicio = @wus_servicio

    ------------------------------------------------------------------------
    -- Ahorros - Córdobas
    ------------------------------------------------------------------------


    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'AHO', 'D', 'NIO', 264,
            @w_causa ,        'ND RETIRO DE EFECTIVO SIN TD - AHO CORDOBAS',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Ahorros - Dólares
    ------------------------------------------------------------------------


    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'AHO', 'D', 'USD', 264,
            @w_causa ,        'ND RETIRO DE EFECTIVO SIN TD - AHO USD',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Cuentas Corrientes - Córdobas
    ------------------------------------------------------------------------

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'D', 'NIO', 50,
            @w_causa ,       'ND RETIRO DE EFECTIVO SIN TD - CTE CORDOBAS',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Cuentas Corrientes - Dólares
    ------------------------------------------------------------------------

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'D', 'USD', 50,
            @w_causa ,       'ND RETIRO DE EFECTIVO SIN TD - CTE  USD',
            'N', 'V')
END
ELSE
    PRINT 'Error en cabecera de servicio RESTD'




SELECT *
                 FROM cob_bvirtual..ESB_det_servicios
                WHERE ud_servicio = @wus_servicio

GO
