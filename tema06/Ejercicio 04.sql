USE BDDataSaludTema06;
GO

CREATE TABLE dw.CatalogoKPI (
    KpiID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Definicion VARCHAR(255) NOT NULL,
    Formula VARCHAR(255) NOT NULL,
    Fuente VARCHAR(100) NOT NULL,
    Responsable VARCHAR(100) NOT NULL,
    Frecuencia VARCHAR(50) NOT NULL,
    Meta VARCHAR(50) NOT NULL,
    CriterioCalidad VARCHAR(255) NOT NULL
);

INSERT INTO dw.CatalogoKPI (Nombre, Definicion, Formula, Fuente, Responsable, Frecuencia, Meta, CriterioCalidad)
VALUES 
('Tiempo Promedio', 'Minutos promedio que dura una atención médica', 'SUM(DuracionMinutos) / COUNT(*)', 'dw.FactAtencion', 'Dirección de Salud', 'Mensual', '< 30 min', 'Duración mayor a 0'),
('Cobertura 1ra Dosis', 'Porcentaje de la población objetivo que recibió su primera dosis', 'Dosis Aplicadas / Población Objetivo', 'dw.FactVacunacion, dw.MetaCobertura', 'Inmunizaciones', 'Anual', '>= 80%', 'Dosis > 0 y Población > 0'),
('Atenciones por Establecimiento', 'Promedio de atenciones registradas por cada sede de salud', 'COUNT(Atenciones) / Nro Establecimientos', 'dw.FactAtencion, dw.DimEstablecimiento', 'Dirección de Salud', 'Mensual', 'N/A', 'Establecimiento válido');

SELECT COUNT(*) AS KpiCatalogados FROM dw.CatalogoKPI;



------------------

USE BDDataSaludTema06;
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Identificador del origen de la atención (NUCLEO, HIS, CAMPANIA)', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'Origen';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Código único de la atención', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'CodigoAtencion';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Clave foránea de la fecha de atención', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'FechaKey';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Clave foránea del establecimiento', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'EstablecimientoKey';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Clave foránea del tipo de atención', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'TipoAtencionKey';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Duración de la atención en minutos (debe ser > 0)', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'DuracionMinutos';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ID de la ejecución ETL de origen', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'EjecucionId';
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Clave foránea del grupo etario', @level0type=N'SCHEMA', @level0name=N'dw', @level1type=N'TABLE', @level1name=N'FactAtencion', @level2type=N'COLUMN', @level2name=N'GrupoEtarioKey';
GO

SELECT 
    c.name AS Columna, 
    t.name AS TipoDato, 
    CAST(ep.value AS VARCHAR(255)) AS Descripcion
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = N'MS_Description'
WHERE c.object_id = OBJECT_ID(N'dw.FactAtencion');

--------------------

USE BDDataSaludTema06;
GO

-- 1. Completitud del Grupo Etario
SELECT 'Completitud Grupo Etario' AS Metrica, COUNT(*) AS Evaluadas, 
       SUM(CASE WHEN GrupoEtarioKey <> 0 THEN 1 ELSE 0 END) AS Cumplen, 
       CAST(100.0 * SUM(CASE WHEN GrupoEtarioKey <> 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS Porcentaje
FROM dw.FactAtencion;

-- 2. Trazabilidad (EjecucionId no nulo)
SELECT 'Trazabilidad ETL' AS Metrica, COUNT(*) AS Evaluadas, 
       SUM(CASE WHEN EjecucionId IS NOT NULL THEN 1 ELSE 0 END) AS Cumplen,
       CAST(100.0 * SUM(CASE WHEN EjecucionId IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS Porcentaje
FROM dw.FactAtencion;

-- 3. Validez de la duración
SELECT 'Validez Duración' AS Metrica, COUNT(*) AS Evaluadas, 
       SUM(CASE WHEN DuracionMinutos > 0 THEN 1 ELSE 0 END) AS Cumplen,
       CAST(100.0 * SUM(CASE WHEN DuracionMinutos > 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS Porcentaje
FROM dw.FactAtencion;

-- 4. Consistencia Staging vs Hecho
SELECT 'Consistencia Staging-Hecho' AS Metrica, COUNT(*) AS Evaluadas, 
       (SELECT COUNT(*) FROM stg.AtencionValida v INNER JOIN dw.FactAtencion h ON v.Origen = h.Origen AND v.CodigoAtencion = h.CodigoAtencion) AS Cumplen
FROM stg.AtencionValida;

-- 5. Aceptación del último lote (EjecucionId = 5)
SELECT 'Aceptación Último Lote' AS Metrica, COUNT(*) AS Evaluadas, 
       SUM(CASE WHEN Origen = 'HIS' THEN 1 ELSE 0 END) AS Cumplen
FROM dw.FactAtencion WHERE EjecucionId = 5;

------------------------------------------------

USE BDDataSaludTema06;
GO

CREATE OR ALTER VIEW dw.vw_AtencionPublica AS
SELECT 
    e.Provincia,
    g.EtapaVida,
    t.TipoAtencion,
    CASE WHEN COUNT(*) < 5 THEN NULL ELSE COUNT(*) END AS Atenciones,
    CASE WHEN COUNT(*) < 5 THEN 'Suprimido' ELSE 'Publicable' END AS Estado
FROM dw.FactAtencion h
INNER JOIN dw.DimEstablecimiento e ON h.EstablecimientoKey = e.EstablecimientoKey
INNER JOIN dw.DimGrupoEtario g ON h.GrupoEtarioKey = g.GrupoEtarioKey
INNER JOIN dw.DimTipoAtencion t ON h.TipoAtencionKey = t.TipoAtencionKey
GROUP BY e.Provincia, g.EtapaVida, t.TipoAtencion;
GO

SELECT Estado, COUNT(*) AS Grupos FROM dw.vw_AtencionPublica GROUP BY Estado;