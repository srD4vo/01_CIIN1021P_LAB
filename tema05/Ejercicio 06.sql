/* ======================================================================================
   BLOQUE 1: R2 - CREACIÓN DE LA DIMENSIÓN VACUNA Y HECHO VACUNACIÓN
   ====================================================================================== */
USE BDDataSaludTema05;
GO

PRINT '--- R2: Creando DimVacuna y FactVacunacion ---';

-- 1. Crear la dimensión DimVacuna (con su miembro desconocido 0)
IF OBJECT_ID(N'dw.DimVacuna', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimVacuna (
        VacunaKey INT NOT NULL CONSTRAINT PK_DimVacuna PRIMARY KEY,
        Vacuna    VARCHAR(20) NOT NULL
    );
    
    INSERT INTO dw.DimVacuna (VacunaKey, Vacuna) VALUES 
    (0, 'NO REGISTRADA'),
    (1, 'SIM-V');
END;
GO

-- 2. Crear la tabla de hechos FactVacunacion
IF OBJECT_ID(N'dw.FactVacunacion', N'U') IS NULL
BEGIN
    CREATE TABLE dw.FactVacunacion (
        CodigoDosis        VARCHAR(10) NOT NULL,
        FechaKey           INT NOT NULL CONSTRAINT FK_FactVacunacion_Fecha REFERENCES dw.DimFecha(FechaKey),
        EstablecimientoKey INT NOT NULL CONSTRAINT FK_FactVacunacion_Establecimiento REFERENCES dw.DimEstablecimiento(EstablecimientoKey),
        GrupoEtarioKey     INT NOT NULL CONSTRAINT FK_FactVacunacion_GrupoEtario REFERENCES dw.DimGrupoEtario(GrupoEtarioKey),
        VacunaKey          INT NOT NULL CONSTRAINT FK_FactVacunacion_Vacuna REFERENCES dw.DimVacuna(VacunaKey),
        NumeroDosis        TINYINT NOT NULL,
        CONSTRAINT PK_FactVacunacion PRIMARY KEY (CodigoDosis) -- Llave primaria para evitar duplicados
    );
END;
GO

/* ======================================================================================
   BLOQUE 2: R3 - CARGA DE DOSIS SIN DUPLICADOS Y REPETIBLE
   ====================================================================================== */
USE BDDataSaludTema05;
GO

PRINT '--- R3: Cargando dosis aplicadas ---';

-- Insertamos los datos limpios
INSERT INTO dw.FactVacunacion (CodigoDosis, FechaKey, EstablecimientoKey, GrupoEtarioKey, VacunaKey, NumeroDosis)
SELECT 
    v.CodigoDosis, 
    f.FechaKey, 
    e.EstablecimientoKey, 
    0 AS GrupoEtarioKey, -- Se deja 0 por simplicidad en este ejercicio
    dv.VacunaKey, 
    v.NumeroDosis
FROM (
    -- Subconsulta para eliminar duplicados (VAC-004)
    SELECT *, ROW_NUMBER() OVER(PARTITION BY CodigoDosis ORDER BY CodigoDosis) AS rn
    FROM src.VacunaAplicada
) AS v
INNER JOIN dw.DimFecha AS f ON f.Fecha = v.FechaAplicacion
INNER JOIN dw.DimEstablecimiento AS e ON e.CodigoEstablecimiento = v.CodigoEstablecimiento
INNER JOIN dw.DimVacuna AS dv ON dv.Vacuna = v.Vacuna
WHERE v.rn = 1 -- Solo toma el primer registro de cada código (elimina el duplicado)
  AND NOT EXISTS (SELECT 1 FROM dw.FactVacunacion AS h WHERE h.CodigoDosis = v.CodigoDosis); -- Hace la carga repetible
GO

-- Verificación de la carga (Deben ser 7)
SELECT COUNT(*) AS DosisCargadas FROM dw.FactVacunacion;
GO


/* ======================================================================================
   BLOQUE 3: R4 - INDICADOR DE COBERTURA DE PRIMERA DOSIS
   ====================================================================================== */
USE BDDataSaludTema05;
GO

PRINT '--- R4: Calculando cobertura de primera dosis ---';

SELECT 
    e.Provincia,
    COUNT(DISTINCT v.CodigoPaciente) AS PacientesPrimeraDosis,
    p.Poblacion AS PoblacionObjetivo,
    CAST(COUNT(DISTINCT v.CodigoPaciente) * 100.0 / p.Poblacion AS DECIMAL(10,2)) AS CoberturaPorcentaje
FROM src.VacunaAplicada AS v
INNER JOIN ope.Establecimiento AS e ON e.CodigoEstablecimiento = v.CodigoEstablecimiento
INNER JOIN ope.PoblacionObjetivo AS p ON p.Provincia = e.Provincia AND p.Anio = 2026 AND p.Vacuna = 'SIM-V'
WHERE v.NumeroDosis = 1 -- Solo evaluamos la primera dosis
GROUP BY e.Provincia, p.Poblacion
ORDER BY e.Provincia;
GO

/* ======================================================================================
   BLOQUE 4: R5 - CONSULTA DRILL-ACROSS (ATENCIONES Y DOSIS)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

PRINT '--- R5: Consulta Drill-across por Provincia ---';

WITH AtencionesVacunacion AS (
    -- Resumen del Hecho 1: Atenciones del tipo VACUNACION
    SELECT e.Provincia, COUNT(*) AS Atenciones
    FROM dw.FactAtencion AS h
    INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
    INNER JOIN dw.DimTipoAtencion AS t ON t.TipoAtencionKey = h.TipoAtencionKey
    WHERE t.TipoAtencion = 'VACUNACION'
    GROUP BY e.Provincia
),
DosisAplicadas AS (
    -- Resumen del Hecho 2: Dosis aplicadas
    SELECT e.Provincia, COUNT(*) AS Dosis
    FROM dw.FactVacunacion AS h
    INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
    GROUP BY e.Provincia
)
-- Unión de los dos hechos a través de la dimensión conformada Provincia
SELECT 
    COALESCE(a.Provincia, d.Provincia) AS Provincia,
    ISNULL(a.Atenciones, 0) AS Atenciones,
    ISNULL(d.Dosis, 0) AS DosisAplicadas
FROM AtencionesVacunacion AS a
FULL OUTER JOIN DosisAplicadas AS d ON a.Provincia = d.Provincia
ORDER BY Provincia;
GO