/* ======================================================================================
   BLOQUE 1: CREACIÓN DE LA TABLA DE LOG Y LINAJE (Paso 1)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

-- 1.1. Crear la tabla de auditoría de ejecuciones
IF OBJECT_ID(N'etl.EjecucionCarga', N'U') IS NULL
CREATE TABLE etl.EjecucionCarga (
    EjecucionId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EjecucionCarga PRIMARY KEY,
    Proceso         VARCHAR(40)    NOT NULL,
    Inicio          DATETIME2(0)   NOT NULL CONSTRAINT DF_EjecucionCarga_Inicio DEFAULT (SYSDATETIME()),
    Fin             DATETIME2(0)   NULL,
    Estado          VARCHAR(10)    NOT NULL,        -- EN_CURSO, OK o ERROR
    FilasStaging    INT            NULL,
    FilasValidas    INT            NULL,
    FilasRechazadas INT            NULL,
    FilasInsertadas INT            NULL,
    Mensaje         NVARCHAR(4000) NULL
);

-- 1.2. Agregar la clave foránea de EjecucionId a la tabla de hechos
IF OBJECT_ID(N'dw.FK_FactAtencion_Ejecucion', N'F') IS NULL
    ALTER TABLE dw.FactAtencion ADD CONSTRAINT FK_FactAtencion_Ejecucion
        FOREIGN KEY (EjecucionId) REFERENCES etl.EjecucionCarga (EjecucionId);
GO

/* ======================================================================================
   BLOQUE 2: DETECTAR LO PENDIENTE DE PUBLICAR (TODO E04-1)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

-- Consultar qué atenciones válidas aún no están en el Data Warehouse
SELECT v.Origen, v.CodigoAtencion, v.DuracionMinutos
FROM stg.AtencionValida AS v
WHERE NOT EXISTS (SELECT 1 FROM dw.FactAtencion AS h
                  WHERE h.Origen = v.Origen
                    AND h.CodigoAtencion = v.CodigoAtencion)
ORDER BY v.Origen, v.CodigoAtencion;
GO



/* ======================================================================================
   BLOQUE 3: PROCEDIMIENTO ALMACENADO DE CARGA (TODO E04-2A y E04-2B)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

CREATE OR ALTER PROCEDURE etl.usp_CargarAtencionesDW
    @FilasInsertadas INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @EjecucionId INT;
    SET @FilasInsertadas = 0;

    INSERT INTO etl.EjecucionCarga (Proceso, Estado, FilasStaging, FilasValidas, FilasRechazadas)
    SELECT 'CARGA_DW_ATENCION', 'EN_CURSO',
           (SELECT COUNT(*) FROM stg.Atencion),
           (SELECT COUNT(*) FROM stg.AtencionValida),
           (SELECT COUNT(*) FROM stg.AtencionRechazada);
    SET @EjecucionId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- TODO E04-2A: Insertar los tipos de atención nuevos (dimensión antes que hecho).
        INSERT INTO dw.DimTipoAtencion (TipoAtencion)
        SELECT DISTINCT v.TipoAtencion
        FROM stg.AtencionValida AS v
        WHERE NOT EXISTS (SELECT 1 FROM dw.DimTipoAtencion AS d
                          WHERE d.TipoAtencion = v.TipoAtencion);

        -- Control: cada fila válida debe encontrar su fecha, establecimiento y tipo.
        IF EXISTS (
            SELECT 1
            FROM stg.AtencionValida AS v
            LEFT JOIN dw.DimFecha           AS f ON f.Fecha = v.FechaAtencion
            LEFT JOIN dw.DimEstablecimiento AS e ON e.CodigoEstablecimiento = v.CodigoEstablecimiento
            LEFT JOIN dw.DimTipoAtencion    AS t ON t.TipoAtencion = v.TipoAtencion
            WHERE f.FechaKey IS NULL OR e.EstablecimientoKey IS NULL OR t.TipoAtencionKey IS NULL)
                BEGIN
            ;THROW 50001, 'Hay atenciones validas sin correspondencia dimensional.', 1;
        END;

        -- TODO E04-2B: INSERT incremental de hechos.
        INSERT INTO dw.FactAtencion (Origen, CodigoAtencion, FechaKey, EstablecimientoKey, TipoAtencionKey, DuracionMinutos, EjecucionId)
        SELECT v.Origen, v.CodigoAtencion, f.FechaKey, e.EstablecimientoKey, t.TipoAtencionKey, v.DuracionMinutos, @EjecucionId
        FROM stg.AtencionValida AS v
        INNER JOIN dw.DimFecha           AS f ON f.Fecha = v.FechaAtencion
        INNER JOIN dw.DimEstablecimiento AS e ON e.CodigoEstablecimiento = v.CodigoEstablecimiento
        INNER JOIN dw.DimTipoAtencion    AS t ON t.TipoAtencion = v.TipoAtencion
        WHERE NOT EXISTS (SELECT 1 FROM dw.FactAtencion AS h
                          WHERE h.Origen = v.Origen
                            AND h.CodigoAtencion = v.CodigoAtencion);

        SET @FilasInsertadas = @@ROWCOUNT;

        UPDATE etl.EjecucionCarga
        SET Fin = SYSDATETIME(), Estado = 'OK', FilasInsertadas = @FilasInsertadas
        WHERE EjecucionId = @EjecucionId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @FilasInsertadas = 0;
        UPDATE etl.EjecucionCarga
        SET Fin = SYSDATETIME(), Estado = 'ERROR', FilasInsertadas = 0, Mensaje = ERROR_MESSAGE()
        WHERE EjecucionId = @EjecucionId;
        THROW;
    END CATCH;
END;
GO


/* ======================================================================================
   BLOQUE 4: EJECUTAR DOS VECES PARA PROBAR LA REPETIBILIDAD (Paso 3)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

-- PRIMERA EJECUCIÓN (Debe insertar 4 filas y llegar a 10 hechos)
PRINT '--- PRIMERA EJECUCIÓN ---';
DECLARE @Nuevas INT;
EXEC etl.usp_CargarAtencionesDW @FilasInsertadas = @Nuevas OUTPUT;
SELECT @Nuevas AS FilasInsertadas;
SELECT COUNT(*) AS Hechos, SUM(DuracionMinutos) AS MinutosTotales FROM dw.FactAtencion;

-- SEGUNDA EJECUCIÓN (Debe insertar 0 filas, manteniendo 10 hechos)
PRINT '--- SEGUNDA EJECUCIÓN ---';
DECLARE @Nuevas2 INT;
EXEC etl.usp_CargarAtencionesDW @FilasInsertadas = @Nuevas2 OUTPUT;
SELECT @Nuevas2 AS FilasInsertadas;
SELECT COUNT(*) AS Hechos, SUM(DuracionMinutos) AS MinutosTotales FROM dw.FactAtencion;

-- VER EL LOG DE EJECUCIONES
PRINT '--- LOG DE EJECUCIONES ---';
SELECT EjecucionId, Estado, FilasStaging, FilasValidas, FilasRechazadas, FilasInsertadas, Mensaje
FROM etl.EjecucionCarga ORDER BY EjecucionId;
GO



/* ======================================================================================
   BLOQUE 5: CREAR LA VISTA DEL INDICADOR (TODO E04-3)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

CREATE OR ALTER VIEW dw.vw_KpiAtencionProvinciaMes
AS
SELECT
    e.Provincia,
    f.Anio,
    f.Mes,
    COUNT(*) AS Atenciones,
    SUM(h.DuracionMinutos) AS MinutosTotales,
    CAST(AVG(CAST(h.DuracionMinutos AS DECIMAL(6,2))) AS DECIMAL(6,2)) AS PromedioMinutos
FROM dw.FactAtencion AS h
INNER JOIN dw.DimFecha AS f ON f.FechaKey = h.FechaKey
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY e.Provincia, f.Anio, f.Mes;
GO

-- Consultar la vista para ver el resultado (deben salir 7 filas)
SELECT * FROM dw.vw_KpiAtencionProvinciaMes ORDER BY Provincia, Anio, Mes;
GO


/* ======================================================================================
   BLOQUE 6: INCORPORAR UN LOTE NUEVO (Paso 5)
   ====================================================================================== */
USE BDDataSaludTema05;
GO

-- 1. Insertar el lote nuevo en las fuentes (HIS y Campania)
PRINT '--- INSERTANDO LOTE NUEVO EN LAS FUENTES ---';
IF NOT EXISTS (SELECT 1 FROM src.AtencionHIS WHERE CodigoAtencion = 'HIS-005')
    INSERT INTO src.AtencionHIS VALUES
    ('HIS-005','20261102','EST-004','LABORATORIO',30,'VALIDO','PAC-0004');

IF NOT EXISTS (SELECT 1 FROM src.AtencionCampania WHERE CodigoAtencion = 'CAM-005')
    INSERT INTO src.AtencionCampania VALUES
    ('CAM-005','20261103','est-005','vacuna',7,'V','PAC-0006');
GO

-- 2. Volver a ejecutar el procedimiento (simulando la corrida del ETL con el nuevo lote)
PRINT '--- TERCERA EJECUCIÓN (CON LOTE NUEVO) ---';
DECLARE @Nuevas3 INT;
EXEC etl.usp_CargarAtencionesDW @FilasInsertadas = @Nuevas3 OUTPUT;
SELECT @Nuevas3 AS FilasInsertadas;
SELECT COUNT(*) AS Hechos, SUM(DuracionMinutos) AS MinutosTotales FROM dw.FactAtencion;

-- Ver el log final
PRINT '--- LOG FINAL ---';
SELECT EjecucionId, Estado, FilasStaging, FilasValidas, FilasRechazadas, FilasInsertadas, Mensaje
FROM etl.EjecucionCarga ORDER BY EjecucionId;
GO


DECLARE @Nuevas INT;
EXEC etl.usp_CargarAtencionesDW @FilasInsertadas = @Nuevas OUTPUT;