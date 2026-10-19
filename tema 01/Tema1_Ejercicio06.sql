-- ==========================================
-- EJERCICIO 06 - PARTE A
-- ==========================================
USE BBDatosSaludTema01;
GO

-- 1. Datos de apoyo (Paciente 004 y 005)
IF NOT EXISTS (SELECT 1 FROM dbo.Paciente WHERE CodigoPaciente = 'PAC-004')
BEGIN
    INSERT INTO dbo.Paciente(CodigoPaciente, Estado)
    VALUES ('PAC-004','A'), ('PAC-005','A');

    INSERT INTO dbo.Atencion
        (PacienteId, EstablecimientoId, TipoAtencion, DuracionMinutos, ClasificacionDuracion, FechaAtencion)
    SELECT PacienteId, 1, 'CONSULTA', 20, 'REGULAR', DATEADD(MONTH, -30, SYSDATETIME())
    FROM dbo.Paciente WHERE CodigoPaciente = 'PAC-004';
END;
GO

-- 2. Procedimiento para marcar inactivos
CREATE OR ALTER PROCEDURE dbo.usp_MarcarPacientesInactivos
    @MesesSinAtencion INT,
    @PacientesMarcados INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @PacientesMarcados = 0;
        IF @MesesSinAtencion IS NULL OR @MesesSinAtencion <= 0
        BEGIN
            ;THROW 50043, 'Los meses sin atencion deben ser mayores que cero.', 1;
        END;

        DECLARE @FechaLimite DATETIME2 = DATEADD(MONTH, -@MesesSinAtencion, SYSDATETIME());

        UPDATE P
        SET P.Estado = 'I'
        FROM dbo.Paciente AS P
        WHERE P.Estado = 'A'
          AND EXISTS (SELECT 1 FROM dbo.Atencion AS A WHERE A.PacienteId = P.PacienteId)
          AND NOT EXISTS (SELECT 1 FROM dbo.Atencion AS A WHERE A.PacienteId = P.PacienteId AND A.FechaAtencion >= @FechaLimite);

        SET @PacientesMarcados = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- 3. Prueba de la Parte A
DECLARE @N INT;
EXEC dbo.usp_MarcarPacientesInactivos @MesesSinAtencion = 24, @PacientesMarcados = @N OUTPUT;
SELECT @N AS PacientesMarcados;
SELECT CodigoPaciente, Estado FROM dbo.Paciente ORDER BY PacienteId;
GO


-- ==========================================
-- EJERCICIO 06 - PARTE B
-- ==========================================

-- 4. Procedimiento para el reporte por fechas
CREATE OR ALTER PROCEDURE dbo.usp_ReporteAtencionesPorTipo
    @Desde DATE,
    @Hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Desde IS NULL OR @Hasta IS NULL OR @Desde > @Hasta
        BEGIN
            ;THROW 50044, 'El rango de fechas es obligatorio y Desde no puede ser mayor que Hasta.', 1;
        END;

        SELECT
            A.TipoAtencion,
            COUNT(*) AS TotalAtenciones,
            AVG(CAST(A.DuracionMinutos AS DECIMAL(10,2))) AS PromedioMinutos
        FROM dbo.Atencion AS A
        WHERE A.FechaAtencion >= @Desde
          AND A.FechaAtencion < DATEADD(DAY, 1, @Hasta)
        GROUP BY A.TipoAtencion
        ORDER BY A.TipoAtencion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- 5. Prueba de la Parte B
DECLARE @D DATE = CAST(DATEADD(DAY, -7, SYSDATETIME()) AS DATE);
DECLARE @H DATE = CAST(SYSDATETIME() AS DATE);
EXEC dbo.usp_ReporteAtencionesPorTipo @Desde = @D, @Hasta = @H;
GO