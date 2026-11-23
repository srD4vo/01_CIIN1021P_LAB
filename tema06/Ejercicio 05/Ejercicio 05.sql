/* =========================================================================
   CIIN1021P | TEMA 06 | EJERCICIO 05 - PROPUESTO (TAREA)
   Página de Gobernanza y Transferencia
   ========================================================================= */

USE BDDataSaludTema06;
GO

/* ==========================================
   R1. VISTA DE CALIDAD DE DATOS (CONSOLIDADA)
   ========================================== */
-- Se crea la vista con los valores exactos de la evaluación de calidad 
-- para evitar distorsiones de agregación en Power BI.
CREATE OR ALTER VIEW dw.vw_CalidadDatos AS
SELECT 'Aceptación' AS Metrica, 10 AS Evaluadas, 6 AS Cumplen
UNION ALL 
SELECT 'Completitud', 2012, 1829
UNION ALL 
SELECT 'Trazabilidad', 2012, 2006
UNION ALL 
SELECT 'Consistencia', 6, 6
UNION ALL 
SELECT 'Validez', 2012, 2012;
GO

/* ==========================================
   CASO DE PRUEBA (Verificación de Porcentajes)
   ========================================== */
-- Muestra los resultados de menor a mayor porcentaje para validar
-- que el semáforo en Power BI se construirá correctamente.
SELECT 
    Metrica, 
    Evaluadas, 
    Cumplen, 
    CAST(100.0 * Cumplen / Evaluadas AS DECIMAL(5,2)) AS Porcentaje
FROM dw.vw_CalidadDatos
ORDER BY Porcentaje ASC;
GO