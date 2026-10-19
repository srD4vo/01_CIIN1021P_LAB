USE BBDatosSaludTema01;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RegistrarAtencion
    @PacienteId INT,
    @EstablecimientoId INT,
    @TipoAtencion VARCHAR(30),
    @DuracionMinutos INT,
    @AtencionId INT OUTPUT,
    @Clasificacion VARCHAR(20) OUTPUT,
    @Mensaje VARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Inicializar parámetros de salida
        SET @AtencionId = NULL;
        SET @Clasificacion = NULL;
        SET @Mensaje = NULL;

        -- TODO 1 (concepto: validar paciente)
        IF @PacienteId IS NULL
        BEGIN
            ;THROW 50031, 'El identificador del paciente es obligatorio.', 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1 
            FROM dbo.Paciente 
            WHERE PacienteId = @PacienteId 
        )
        BEGIN
            ;THROW 50032, 'El paciente indicado no existe.', 1;
        END;

        -- CORREGIDO: Quitamos el NOT para que valide correctamente a los inactivos
        IF EXISTS 
        (
            SELECT 1 
            FROM dbo.Paciente 
            WHERE PacienteId = @PacienteId 
            AND Estado = 'I' 
        )
        BEGIN
            ;THROW 50033, 'El paciente se encuentra inactivo.', 1;
        END;

        -- TODO 2 (concepto: repetir el patrón con otra tabla)
        IF @EstablecimientoId IS NULL
        BEGIN
            ;THROW 50034, 'El identificador del establecimiento es obligatorio.', 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1 
            FROM dbo.EstablecimientoSalud 
            WHERE EstablecimientoId = @EstablecimientoId
        )
        BEGIN
            ;THROW 50035, 'El establecimiento indicado no existe.', 1;
        END;

        -- CORREGIDO: Quitamos el NOT
        IF EXISTS 
        (
            SELECT 1 
            FROM dbo.EstablecimientoSalud 
            WHERE EstablecimientoId = @EstablecimientoId
            AND Estado = 'I' 
        )
        BEGIN
            ;THROW 50036, 'El establecimiento se encuentra inactivo.', 1;
        END;

        -- Validar tipo de atencion (completo)
        IF @TipoAtencion IS NULL
            OR LTRIM(RTRIM(@TipoAtencion)) = ''
        BEGIN
            ;THROW 50037, 'El tipo de atencion es obligatorio.', 1;
        END;

        IF @TipoAtencion NOT IN ('CONSULTA','CONTROL','VACUNACION')
        BEGIN
            ;THROW 50038, 'El tipo de atencion indicado no es valido.', 1;
        END;

        -- TODO 3
        IF @DuracionMinutos IS NULL 
           OR @DuracionMinutos <= 0
        BEGIN
            ;THROW 50039, 'La duracion debe ser mayor que cero.', 1;
        END;

        -- TODO 4
        SET @Clasificacion = dbo.ufn_ClasificarDuracionAtencion(@DuracionMinutos);

        IF @Clasificacion IS NULL
        BEGIN
            ;THROW 50040, 'No fue posible clasificar la duracion.', 1;
        END;

        -- TODO 5
        INSERT INTO dbo.Atencion
        (
            PacienteId, EstablecimientoId, TipoAtencion, 
            DuracionMinutos, ClasificacionDuracion
        )
        VALUES
        (
            @PacienteId, @EstablecimientoId, @TipoAtencion, 
            @DuracionMinutos, @Clasificacion
        );

        SET @AtencionId = CONVERT(INT, SCOPE_IDENTITY());

        SET @Mensaje = CONCAT('Atencion registrada correctamente. Codigo: ', @AtencionId, '.');

    END TRY
    BEGIN CATCH
        SET @Mensaje = CONCAT('Error ', ERROR_NUMBER(),
                            ' en ', COALESCE(ERROR_PROCEDURE(), 'dbo.usp_RegistrarAtencion'),
                            ', linea ', ERROR_LINE(), ': ', ERROR_MESSAGE());
        THROW;
    END CATCH;
END;
GO


-- Ejecuta el caso exitoso y muestra los parámetros de salida en una tabla
DECLARE @AtencionId INT;
DECLARE @Clasificacion VARCHAR(20);
DECLARE @Mensaje VARCHAR(300);

EXEC dbo.usp_RegistrarAtencion 
    @PacienteId = 1, 
    @EstablecimientoId = 1, 
    @TipoAtencion = 'CONSULTA', 
    @DuracionMinutos = 20,
    @AtencionId = @AtencionId OUTPUT,
    @Clasificacion = @Clasificacion OUTPUT,
    @Mensaje = @Mensaje OUTPUT;

SELECT @AtencionId AS AtencionId, @Clasificacion AS Clasificacion, @Mensaje AS Mensaje;
GO



------------------------------------


-- Panel de pruebas: cambia los 4 valores de la primera línea y ejecuta.
-- Por defecto está configurado para el Caso 2 de la tabla de la guía.
DECLARE @p INT = 2, @e INT = 2, @t VARCHAR(30) = 'CONTROL', @d INT = 12;
DECLARE @A INT, @C VARCHAR(20), @M VARCHAR(300);

BEGIN TRY
    EXEC dbo.usp_RegistrarAtencion 
        @PacienteId = @p, @EstablecimientoId = @e, 
        @TipoAtencion = @t, @DuracionMinutos = @d,
        @AtencionId = @A OUTPUT, @Clasificacion = @C OUTPUT, @Mensaje = @M OUTPUT;
    
    -- Si todo sale bien, muestra esto:
    SELECT @A AS AtencionId, @C AS Clasificacion, @M AS Mensaje;
END TRY
BEGIN CATCH
    -- Si hay error, lo captura y lo muestra como tabla
    SELECT ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;
GO

------------

-- Consulta con JOIN para ver el detalle de lo que se insertó
SELECT 
    A.AtencionId, P.CodigoPaciente, E.CodigoEstablecimiento, 
    A.TipoAtencion, A.DuracionMinutos, A.ClasificacionDuracion, A.FechaAtencion
FROM dbo.Atencion AS A
INNER JOIN dbo.Paciente AS P ON P.PacienteId = A.PacienteId
INNER JOIN dbo.EstablecimientoSalud AS E ON E.EstablecimientoId = A.EstablecimientoId
ORDER BY A.AtencionId;
GO