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
    @w_nemonico   VARCHAR(20)

-- Transacción de desembolsos
SET @w_nemonico = 'RESTD'

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
    VALUES (@wus_servicio, 'AHO', 'C', 'NIO', 253,
            '14',        'REVERSO RETIRO DE EFECTIVO SIN TD - CREDITO AHORRO CORDOBAS',
            'S', 'V')

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'AHO', 'D', 'NIO', 264,
            '17',        'RETIRO RETIRO DE EFECTIVO SIN TD - CREDITO AHORRO CORDOBAS',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Ahorros - Dólares
    ------------------------------------------------------------------------
    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'AHO', 'C', 'USD', 253,
            '166',       'REVERSO RETIRO DE EFECTIVO SIN TD - CREDITO AHORRO DOLARES',
            'S', 'V')

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'AHO', 'D', 'USD', 264,
            '17',        'RETIRO RETIRO DE EFECTIVO SIN TD - CREDITO AHORRO USD',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Cuentas Corrientes - Córdobas
    ------------------------------------------------------------------------
    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'C', 'NIO', 48,
            '536',       'REVERSO - RETIRO DE EFECTIVO SIN TD - CORDOBAS',
            'S', 'V')

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'D', 'NIO', 50,
            '507',       'RETIRO DE EFECTIVO SIN TD - CORDOBAS',
            'N', 'V')

    ------------------------------------------------------------------------
    -- Cuentas Corrientes - Dólares
    ------------------------------------------------------------------------
    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'C', 'USD', 48,
            '446',       'REVERSO RETIRO DE EFECTIVO SIN TD - DOLARES',
            'S', 'V')

    INSERT INTO cob_bvirtual..ESB_det_servicios
          (ud_servicio, ud_producto, ud_operacion, ud_moneda, ud_transaccion,
           ud_causa,    ud_descripcion, ud_reintegro, ud_estado)
    VALUES (@wus_servicio, 'CTE', 'D', 'USD', 50,
            '447',       'RETIRO RETIRO DE EFECTIVO SIN TD - DOLARES',
            'N', 'V')
END
ELSE
    PRINT 'Error en cabecera de servicio RESTD'




SELECT *
                 FROM cob_bvirtual..ESB_det_servicios
                WHERE ud_servicio = @wus_servicio

GO