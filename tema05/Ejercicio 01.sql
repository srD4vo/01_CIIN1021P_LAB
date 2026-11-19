USE BDDataSaludTema05;
GO

SELECT a.AtencionId, e.CodigoEstablecimiento, e.Provincia, a.FechaAtencion,
       a.TipoAtencion, a.DuracionMinutos, a.EstadoRegistro
FROM ope.Atencion AS a
INNER JOIN ope.Establecimiento AS e ON e.EstablecimientoId = a.EstablecimientoId
ORDER BY a.AtencionId;

------------

SELECT COUNT(*) AS Atenciones, SUM(DuracionMinutos) AS MinutosTotales
FROM ope.Atencion;

---------------

SELECT e.Provincia, a.TipoAtencion,
       COUNT(*)                                             AS Atenciones,
       SUM(a.DuracionMinutos)                               AS MinutosTotales,
       CAST(AVG(CAST(a.DuracionMinutos AS DECIMAL(6,2))) AS DECIMAL(6,2)) AS PromedioMinutos
FROM ope.Atencion AS a
INNER JOIN ope.Establecimiento AS e ON e.EstablecimientoId = a.EstablecimientoId
WHERE a.EstadoRegistro = 'VALIDO'
GROUP BY e.Provincia, a.TipoAtencion
ORDER BY e.Provincia, a.TipoAtencion;

--------------------


SELECT e.Provincia,
       COUNT(*)                AS Atenciones,
       SUM(a.DuracionMinutos)  AS MinutosTotales,
       CAST(AVG(CAST(a.DuracionMinutos AS DECIMAL(6,2))) AS DECIMAL(6,2)) AS PromedioMinutos
FROM ope.Atencion AS a
INNER JOIN ope.Establecimiento AS e ON e.EstablecimientoId = a.EstablecimientoId
WHERE a.EstadoRegistro = 'VALIDO'
GROUP BY e.Provincia
ORDER BY e.Provincia;

---------------------

WITH PorProvincia AS (
    SELECT e.Provincia,
           COUNT(*) AS Atenciones,
           SUM(a.DuracionMinutos) AS MinutosTotales,
           AVG(CAST(a.DuracionMinutos AS DECIMAL(6,2))) AS Promedio
    FROM ope.Atencion AS a
    INNER JOIN ope.Establecimiento AS e ON e.EstablecimientoId = a.EstablecimientoId
    WHERE a.EstadoRegistro = 'VALIDO'
    GROUP BY e.Provincia
)
SELECT CAST(AVG(Promedio) AS DECIMAL(6,2))                                        AS PromedioDePromedios,
       CAST(SUM(MinutosTotales) * 1.0 / SUM(Atenciones) AS DECIMAL(6,2))          AS PromedioGlobal
FROM PorProvincia;