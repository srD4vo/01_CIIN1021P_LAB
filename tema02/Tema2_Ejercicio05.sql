-- ======================================================================
-- ====================== BLOQUE 1 ======================================
-- ============ CREACIÓN DE TABLAS (RESUMEN Y CIERRE) ===================
-- ======================================================================
USE BDDataSaludTema01;
GO

DROP TABLE IF EXISTS dbo.ResumenDiarioAtencion;
DROP TABLE IF EXISTS dbo.CierreDiario;
GO

CREATE TABLE dbo.ResumenDiarioAtencion(
    FechaAtencion DATE NOT NULL,
    EstablecimientoId INT NOT NULL,
    TipoAtencion VARCHAR(30) NOT NULL,
    TotalAtenciones INT NOT NULL,
    TotalMinutos INT NOT NULL,
    PromedioMinutos DECIMAL(10,2) NOT NULL,
    FechaCierre DATETIME2 NOT NULL
        CONSTRAINT DF_ResumenDiario_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ResumenDiarioAtencion PRIMARY KEY (FechaAtencion, EstablecimientoId, TipoAtencion)
);
GO

CREATE TABLE dbo.CierreDiario(
    CierreId INT IDENTITY(1,1)
        CONSTRAINT PK_CierreDiario PRIMARY KEY,
    FechaAtencion DATE NOT NULL
        CONSTRAINT UQ_CierreDiario_Fecha UNIQUE,
    FilasResumen INT NOT NULL,
    TotalAtenciones INT NOT NULL,
    FechaCierre DATETIME2 NOT NULL
        CONSTRAINT DF_CierreDiario_Fecha DEFAULT (SYSDATETIME()),
    UsuarioBD NVARCHAR(128) NOT NULL
);
GO


-- ======================================================================
-- ====================== BLOQUE 2 ======================================
-- ============ PROCEDIMIENTO usp_CerrarDiaAtenciones ===================
-- ======================================================================
USE BDDataSaludTema01;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CerrarDiaAtenciones
    @Fecha DATE,
    @FilasResumen INT OUTPUT,
    @Mensaje VARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @FilasResumen = 0;
    SET @Mensaje = NULL;

    BEGIN TRY
        -- Validaciones (antes de abrir la transaccion)
        IF @Fecha IS NULL
        BEGIN
            ;THROW 54001, 'La fecha es obligatoria.', 1;
        END;

        IF @Fecha > CAST(SYSDATETIME() AS DATE)
        BEGIN
            ;THROW 54002, 'La fecha no puede ser posterior a hoy.', 1;
        END;

        IF EXISTS (SELECT 1 FROM dbo.CierreDiario WHERE FechaAtencion = @Fecha)
        BEGIN
            ;THROW 54003, 'El dia ya fue cerrado.', 1;
        END;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Atencion 
            WHERE FechaAtencion >= @Fecha 
              AND FechaAtencion < DATEADD(DAY, 1, @Fecha)
        )
        BEGIN
            ;THROW 54004, 'No hay atenciones en esa fecha.', 1;
        END;

        BEGIN TRANSACTION;

        INSERT INTO dbo.ResumenDiarioAtencion 
            (FechaAtencion, EstablecimientoId, TipoAtencion, TotalAtenciones, TotalMinutos, PromedioMinutos)
        SELECT 
            @Fecha,
            EstablecimientoId,
            TipoAtencion,
            COUNT(*),
            SUM(DuracionMinutos),
            CAST(AVG(CAST(DuracionMinutos AS DECIMAL(10,2))) AS DECIMAL(10,2))
        FROM dbo.Atencion
        WHERE FechaAtencion >= @Fecha 
          AND FechaAtencion < DATEADD(DAY, 1, @Fecha)
        GROUP BY EstablecimientoId, TipoAtencion;

        SET @FilasResumen = @@ROWCOUNT;

        DECLARE @TotalAtenciones INT = (
            SELECT COUNT(*) FROM dbo.Atencion 
            WHERE FechaAtencion >= @Fecha 
              AND FechaAtencion < DATEADD(DAY, 1, @Fecha)
        );

        INSERT INTO dbo.CierreDiario (FechaAtencion, FilasResumen, TotalAtenciones, UsuarioBD)
        VALUES (@Fecha, @FilasResumen, @TotalAtenciones, SUSER_SNAME());

        COMMIT TRANSACTION;
        SET @Mensaje = CONCAT('Cierre exitoso. Filas en resumen: ', @FilasResumen, '.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 
        BEGIN
            ROLLBACK TRANSACTION;
        END;
            
        SET @Mensaje = CONCAT('Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
        THROW;
    END CATCH;
END;
GO


-- ======================================================================
-- ====================== BLOQUE 3 ======================================
-- ============ CASO 1 - CIERRE EXITOSO =================================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @F INT, @M VARCHAR(300);
EXEC dbo.usp_CerrarDiaAtenciones @Fecha = '2026-09-05',
     @FilasResumen = @F OUTPUT, @Mensaje = @M OUTPUT;

-- ⚠️ IMPORTANTE PARA EL PDF: Captura este resultado (FilasResumen debe ser 2).
SELECT @F AS FilasResumen, @M AS Mensaje;

-- ⚠️ IMPORTANTE PARA EL PDF: Captura esta tabla.
-- Debe salir: EST-001 CONTROL 1 atención 13 min prom 13.00; EST-002 VACUNACION 1 atención 27 min prom 27.00
SELECT * FROM dbo.ResumenDiarioAtencion WHERE FechaAtencion = '2026-09-05';
GO


-- ======================================================================
-- ====================== BLOQUE 4 ======================================
-- ============ CASOS 2 Y 3 - VALIDACIONES DE ERROR =====================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @F INT, @M VARCHAR(300);

-- Caso 2: Repetir el cierre
BEGIN TRY
    EXEC dbo.usp_CerrarDiaAtenciones @Fecha = '2026-09-05',
         @FilasResumen = @F OUTPUT, @Mensaje = @M OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'Segundo cierre' AS Caso, ERROR_NUMBER() AS NumeroError,
           ERROR_MESSAGE() AS MensajeError;
END CATCH;

-- Caso 3: Día sin atenciones
BEGIN TRY
    EXEC dbo.usp_CerrarDiaAtenciones @Fecha = '2026-01-01',
         @FilasResumen = @F OUTPUT, @Mensaje = @M OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'Dia sin atenciones' AS Caso, ERROR_NUMBER() AS NumeroError,
           ERROR_MESSAGE() AS MensajeError;
END CATCH;

-- ⚠️ IMPORTANTE PARA EL PDF: Captura esta tabla final.
-- Solo debe haber UNA fila, la del 2026-09-05.
SELECT CierreId, FechaAtencion, FilasResumen, TotalAtenciones FROM dbo.CierreDiario;
GO