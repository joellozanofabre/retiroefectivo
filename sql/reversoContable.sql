
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

    -- Eliminar detalle previo si existía
    IF EXISTS (SELECT 1
                 FROM cob_bvirtual..ESB_det_servicios
                WHERE ud_servicio = @wus_servicio)
        DELETE cob_bvirtual..ESB_det_servicios
         WHERE ud_servicio = @wus_servicio

go