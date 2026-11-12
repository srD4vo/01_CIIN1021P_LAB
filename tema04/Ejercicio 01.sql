-- ANTES CAPTURA

USE BDDataSaludTema04;
GO

-- Reiniciamos el índice por si acaso ya existía
IF EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE object_id=OBJECT_ID(N'dbo.Atencion')
    AND name=N'IX_T04_Atencion_Establecimiento_Fecha'
)
  DROP INDEX IX_T04_Atencion_Establecimiento_Fecha ON dbo.Atencion;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT AtencionId, EstablecimientoId, FechaAtencion
FROM dbo.Atencion
WHERE EstablecimientoId = 2
  AND FechaAtencion >= '20260901'
  AND FechaAtencion <  '20261001'
ORDER BY FechaAtencion;
GO

------------------------------------------------------------------------------
-- DESPUES CAPTURA

-- Creamos el índice
CREATE NONCLUSTERED INDEX IX_T04_Atencion_Establecimiento_Fecha
ON dbo.Atencion (EstablecimientoId, FechaAtencion);
GO

-- Volvemos a ejecutar exactamente la misma consulta
SELECT AtencionId, EstablecimientoId, FechaAtencion
FROM dbo.Atencion
WHERE EstablecimientoId = 2
  AND FechaAtencion >= '20260901'
  AND FechaAtencion <  '20261001'
ORDER BY FechaAtencion;
GO

-- Apagamos las mediciones
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO