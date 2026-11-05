/* ======================================================================
   EJERCICIO 04 - CÓDIGO CONSOLIDADO
   ====================================================================== */

/* ----------------------------------------------------------------------
   [FOTO 1 PARA EL WORD]: BLOQUE 1 - MEDICIÓN INICIAL (ANTES)
   Captura la pestaña "Messages" (Tiempos y Lecturas) y el Plan de Ejecución.
   ---------------------------------------------------------------------- */
USE BDDataSaludTema01;
GO

DROP TABLE IF EXISTS dbo.AtencionRendimientoTema03;
GO

CREATE TABLE dbo.AtencionRendimientoTema03(
    AtencionRendimientoId INT IDENTITY(1,1)
        CONSTRAINT PK_AtencionRendimientoTema03 PRIMARY KEY,
    EstablecimientoId INT NOT NULL,
    FechaAtencion DATETIME2 NOT NULL,
    TipoAtencion VARCHAR(30) NOT NULL,
    DuracionMinutos INT NOT NULL
);
GO

-- Insertamos 50,000 filas sintéticas
WITH Numeros AS
(
    SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Numero
    FROM sys.all_objects AS A
    CROSS JOIN sys.all_objects AS B
)
INSERT INTO dbo.AtencionRendimientoTema03
    (EstablecimientoId, FechaAtencion, TipoAtencion, DuracionMinutos)
SELECT ((Numero * 17) % 50) + 1,
       DATEADD(MINUTE, Numero % 1440,
               DATEADD(DAY, Numero % 365, CAST('2025-09-01' AS DATETIME2))),
       CASE Numero % 3 WHEN 0 THEN 'CONSULTA' WHEN 1 THEN 'CONTROL' ELSE 'VACUNACION' END,
       ((Numero * 7) % 50) + 10
FROM Numeros;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Consulta A (Antes)
SELECT AtencionRendimientoId, EstablecimientoId, FechaAtencion
FROM dbo.AtencionRendimientoTema03
WHERE EstablecimientoId = 17
  AND FechaAtencion >= '2026-07-01'
  AND FechaAtencion < '2026-08-01';
GO

-- Consulta B (Antes)
SELECT AtencionRendimientoId, FechaAtencion, TipoAtencion, DuracionMinutos
FROM dbo.AtencionRendimientoTema03
WHERE EstablecimientoId = 17
  AND FechaAtencion >= '2026-07-01'
  AND FechaAtencion < '2026-07-16';
GO


/* ----------------------------------------------------------------------
   [FOTO 2 PARA EL WORD]: BLOQUE 2 - DECISIÓN 1 (CREAR ÍNDICE BÁSICO)
   Captura la creación del índice y el plan de la Consulta A (Index Seek).
   ---------------------------------------------------------------------- */
-- Decisión 1: índice para la consulta A (igualdad primero, rango después).
CREATE NONCLUSTERED INDEX IX_AtencionRendimiento_Estab_Fecha
ON dbo.AtencionRendimientoTema03 (EstablecimientoId, FechaAtencion);
GO

-- Re-ejecución de Consulta A (Después)
SELECT AtencionRendimientoId, EstablecimientoId, FechaAtencion
FROM dbo.AtencionRendimientoTema03
WHERE EstablecimientoId = 17
  AND FechaAtencion >= '2026-07-01'
  AND FechaAtencion < '2026-08-01';
GO

-- Re-ejecución de Consulta B (Para ver el Key Lookup)
-- Captura el Plan de Ejecución mostrando el "Key Lookup" o "Clustered Index Lookup".
SELECT AtencionRendimientoId, FechaAtencion, TipoAtencion, DuracionMinutos
FROM dbo.AtencionRendimientoTema03
WHERE EstablecimientoId = 17
  AND FechaAtencion >= '2026-07-01'
  AND FechaAtencion < '2026-07-16';
GO


/* ----------------------------------------------------------------------
   [FOTO 3 PARA EL WORD]: BLOQUE 3 - DECISIÓN 2 (ÍNDICE CON INCLUDE)
   Captura la creación del índice y cómo desaparece el Key Lookup.
   ---------------------------------------------------------------------- */
-- Decisión 2: Ajustar el índice para cubrir la consulta B (elimina el Key Lookup).
DROP INDEX IX_AtencionRendimiento_Estab_Fecha ON dbo.AtencionRendimientoTema03;
GO

CREATE NONCLUSTERED INDEX IX_AtencionRendimiento_Estab_Fecha
ON dbo.AtencionRendimientoTema03 (EstablecimientoId, FechaAtencion)
INCLUDE (AtencionRendimientoId, TipoAtencion, DuracionMinutos);
GO

-- Re-ejecución de Consulta B (Después del INCLUDE)
-- El plan ahora solo debe mostrar un "Index Seek" limpio.
SELECT AtencionRendimientoId, FechaAtencion, TipoAtencion, DuracionMinutos
FROM dbo.AtencionRendimientoTema03
WHERE EstablecimientoId = 17
  AND FechaAtencion >= '2026-07-01'
  AND FechaAtencion < '2026-07-16';
GO


/* ----------------------------------------------------------------------
   [FOTO 4 PARA EL WORD]: BLOQUE 4 - CIERRE Y VERIFICACIÓN
   Captura la lista final de índices.
   ---------------------------------------------------------------------- */
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

SELECT name AS Indice, type_desc AS Tipo
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.AtencionRendimientoTema03')
ORDER BY index_id;
GO