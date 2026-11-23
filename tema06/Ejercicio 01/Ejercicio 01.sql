USE BDDataSaludTema06;
GO
SELECT COUNT(*) AS Atenciones, SUM(DuracionMinutos) AS Minutos,
       CAST(SUM(DuracionMinutos) * 1.0 / COUNT(*) AS DECIMAL(6,2)) AS TiempoPromedio
FROM dw.FactAtencion;
---------------
SELECT e.Provincia,
       COUNT(*)                 AS Atenciones,
       SUM(h.DuracionMinutos)   AS Minutos,
       CAST(SUM(h.DuracionMinutos) * 1.0 / COUNT(*) AS DECIMAL(6,2)) AS TiempoPromedio
FROM dw.FactAtencion AS h
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY e.Provincia
ORDER BY e.Provincia;
--------------------
SELECT CASE WHEN GROUPING(e.Provincia) = 1 THEN 'TOTAL REGIONAL'
            ELSE e.Provincia END                                   AS Provincia,
       CASE WHEN GROUPING(e.CodigoEstablecimiento) = 1
                 AND GROUPING(e.Provincia) = 0 THEN 'SUBTOTAL PROVINCIA'
            WHEN GROUPING(e.CodigoEstablecimiento) = 1 THEN ''
            ELSE e.CodigoEstablecimiento END                       AS Establecimiento,
       COUNT(*)               AS Atenciones,
       SUM(h.DuracionMinutos) AS Minutos
FROM dw.FactAtencion AS h
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY ROLLUP (e.Provincia, e.CodigoEstablecimiento)
ORDER BY GROUPING(e.Provincia), e.Provincia, GROUPING(e.CodigoEstablecimiento), e.CodigoEstablecimiento;
--------------------
-- 3A. Slice
SELECT e.CodigoEstablecimiento, e.Distrito, COUNT(*) AS Atenciones
FROM dw.FactAtencion AS h
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
WHERE e.Provincia = 'TRUJILLO'
GROUP BY e.CodigoEstablecimiento, e.Distrito
ORDER BY e.CodigoEstablecimiento;

-- 3B. Dice
SELECT COUNT(*) AS Atenciones, SUM(h.DuracionMinutos) AS Minutos
FROM dw.FactAtencion AS h
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
INNER JOIN dw.DimFecha          AS f ON f.FechaKey = h.FechaKey
INNER JOIN dw.DimTipoAtencion   AS t ON t.TipoAtencionKey = h.TipoAtencionKey
WHERE e.Provincia IN ('TRUJILLO', 'CHEPEN')
  AND f.Semestre = 2
  AND t.TipoAtencion = 'CONSULTA';
---------------------------------

SELECT CASE WHEN GROUPING(t.TipoAtencion) = 1 THEN '(todos)' ELSE t.TipoAtencion END AS Tipo,
       CASE WHEN GROUPING(f.Semestre) = 1 THEN '(todos)' ELSE CAST(f.Semestre AS VARCHAR(7)) END AS Semestre,
       COUNT(*) AS Atenciones
FROM dw.FactAtencion AS h
INNER JOIN dw.DimTipoAtencion AS t ON t.TipoAtencionKey = h.TipoAtencionKey
INNER JOIN dw.DimFecha        AS f ON f.FechaKey = h.FechaKey
GROUP BY CUBE (t.TipoAtencion, f.Semestre)
ORDER BY GROUPING(t.TipoAtencion), t.TipoAtencion, GROUPING(f.Semestre), f.Semestre;
------------------------
SELECT CASE WHEN GROUPING(t.TipoAtencion) = 1 THEN '(todos)' ELSE t.TipoAtencion END AS Tipo,
       CASE WHEN GROUPING(f.Semestre) = 1 THEN '(todos)' ELSE CAST(f.Semestre AS VARCHAR(7)) END AS Semestre,
       COUNT(*) AS Atenciones
FROM dw.FactAtencion AS h
INNER JOIN dw.DimTipoAtencion AS t ON t.TipoAtencionKey = h.TipoAtencionKey
INNER JOIN dw.DimFecha        AS f ON f.FechaKey = h.FechaKey
GROUP BY GROUPING SETS ( (t.TipoAtencion), (f.Semestre), () )
ORDER BY GROUPING(t.TipoAtencion), t.TipoAtencion, GROUPING(f.Semestre), f.Semestre;
---------------
SELECT e.Provincia,
       COUNT(*) AS Atenciones,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Participacion
FROM dw.FactAtencion AS h
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY e.Provincia
ORDER BY Participacion DESC, e.Provincia;