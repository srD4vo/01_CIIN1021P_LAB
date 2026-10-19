CREATE OR ALTER PROCEDURE dbo.usp_EvaluarCalidadLote
    @LoteCarga VARCHAR(20),
    @TotalValidos INT OUTPUT,
    @TotalObservados INT OUTPUT,
    @TotalInvalidos INT OUTPUT,
    @Mensaje VARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @TotalValidos = 0;
        SET @TotalObservados = 0;
        SET @TotalInvalidos = 0;
        SET @Mensaje = NULL;

        IF @LoteCarga IS NULL OR LTRIM(RTRIM(@LoteCarga)) = ''
        BEGIN
            ;THROW 50041, 'El codigo del lote es obligatorio.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.AtencionStaging WHERE LoteCarga = @LoteCarga)
        BEGIN
            ;THROW 50042, 'El lote indicado no contiene registros.', 1;
        END;

        DECLARE @Evaluacion TABLE
        (
            RegistroId INT,
            Clasificacion VARCHAR(15),
            Motivo VARCHAR(200)
        );

        -- Paso previo (completo): todos los registros del lote entran SIN clasificar.
        INSERT INTO @Evaluacion (RegistroId, Clasificacion, Motivo)
        SELECT A.RegistroId, NULL, NULL
        FROM dbo.AtencionStaging AS A
        WHERE A.LoteCarga = @LoteCarga;

        -- Regla 1 (MODELO RESUELTO): campos obligatorios.
        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Campo obligatorio no informado.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND (A.CodigoPaciente IS NULL
               OR A.CodigoEstablecimiento IS NULL
               OR A.TipoAtencion IS NULL
               OR A.FechaAtencion IS NULL);

        -- TODO 1 (concepto: duracion invalida)
        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Duracion invalida.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND (A.DuracionMinutos IS NULL OR A.DuracionMinutos <= 0);

        -- TODO 2 (concepto: valor fuera de la lista permitida)
        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Tipo de atencion no permitido.'
        FROM @Evaluacion AS E  
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND A.TipoAtencion NOT IN ('CONSULTA', 'CONTROL', 'VACUNACION');

        -- TODO 3 (concepto: duplicado posterior)
        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Posible registro duplicado.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND EXISTS
          (
              SELECT 1
              FROM dbo.AtencionStaging AS B
              WHERE B.LoteCarga = A.LoteCarga
                AND B.RegistroId < A.RegistroId -- El duplicado debe tener un ID menor (es anterior)
                AND B.CodigoPaciente = A.CodigoPaciente
                AND B.CodigoEstablecimiento = A.CodigoEstablecimiento
                AND B.TipoAtencion = A.TipoAtencion
                AND B.DuracionMinutos = A.DuracionMinutos
                AND B.FechaAtencion = A.FechaAtencion
          );

        -- TODO 4 (concepto: dato atipico que se observa, no se descarta)
        UPDATE E
        SET E.Clasificacion = 'OBSERVADO',
            E.Motivo = 'Duracion mayor a 180 minutos.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND A.DuracionMinutos > 180;

        -- TODO 5 (concepto: lo que ninguna regla marco)
        UPDATE @Evaluacion
        SET Clasificacion = 'VALIDO',
            Motivo = 'Cumple las reglas.'
        WHERE Clasificacion IS NULL;

        -- TODO 6 (concepto: contar con SUM + CASE)
        SELECT
            @TotalValidos =
                SUM(CASE WHEN Clasificacion = 'VALIDO' THEN 1 ELSE 0 END),
            @TotalObservados =
                SUM(CASE WHEN Clasificacion = 'OBSERVADO' THEN 1 ELSE 0 END),
            @TotalInvalidos =
                SUM(CASE WHEN Clasificacion = 'INVALIDO' THEN 1 ELSE 0 END)
        FROM @Evaluacion;

        -- Resultado 1: detalle por registro (completo)
        SELECT
            A.RegistroId, A.CodigoPaciente, A.CodigoEstablecimiento,
            A.TipoAtencion, A.DuracionMinutos, A.FechaAtencion,
            E.Clasificacion, E.Motivo
        FROM dbo.AtencionStaging AS A
        INNER JOIN @Evaluacion AS E ON E.RegistroId = A.RegistroId
        WHERE A.LoteCarga = @LoteCarga
        ORDER BY A.RegistroId;

        -- Resultado 2: tabla de problemas de calidad con conteo (completo)
        SELECT E.Motivo AS ProblemaDeCalidad, COUNT(*) AS RegistrosAfectados
        FROM @Evaluacion AS E
        GROUP BY E.Motivo
        ORDER BY COUNT(*) DESC, E.Motivo;

        SET @Mensaje = CONCAT('Evaluacion completada. Validos: ', @TotalValidos,
                              ', observados: ', @TotalObservados,
                              ', invalidos: ', @TotalInvalidos, '.');
    END TRY
    BEGIN CATCH
        SET @Mensaje = CONCAT('Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
        THROW;
    END CATCH;
END;
GO

--------
USE BBDatosSaludTema01; -- <--- Agrega esta línea
GO

DECLARE @V INT, @O INT, @I INT;
DECLARE @M VARCHAR(300);

EXEC dbo.usp_EvaluarCalidadLote 
    @LoteCarga = 'LOTE-001',
    @TotalValidos = @V OUTPUT,
    @TotalObservados = @O OUTPUT,
    @TotalInvalidos = @I OUTPUT,
    @Mensaje = @M OUTPUT;

SELECT @V AS Validos, @O AS Observados, @I AS Invalidos, @M AS Mensaje;
GO

-----------


USE BBDatosSaludTema01;
GO

-- 1. Crear la tabla de Staging (por si no existe)
DROP TABLE IF EXISTS dbo.AtencionStaging;
GO
CREATE TABLE dbo.AtencionStaging(
    RegistroId INT IDENTITY(1,1)
        CONSTRAINT PK_AtencionStaging PRIMARY KEY,
    LoteCarga VARCHAR(20) NOT NULL,
    CodigoPaciente VARCHAR(20) NULL,
    CodigoEstablecimiento VARCHAR(20) NULL,
    TipoAtencion VARCHAR(30) NULL,
    DuracionMinutos INT NULL,
    FechaAtencion DATE NULL
);
GO

-- 2. Insertar los datos del LOTE-001 (según la guía)
INSERT INTO dbo.AtencionStaging
(
    LoteCarga, CodigoPaciente, CodigoEstablecimiento, 
    TipoAtencion, DuracionMinutos, FechaAtencion
)
VALUES
('LOTE-001', 'PAC-001', 'EST-001', 'CONSULTA', 20, '2026-08-19'),
('LOTE-001', NULL, 'EST-001', 'CONSULTA', 15, '2026-08-19'),
('LOTE-001', 'PAC-002', 'EST-002', 'CONTROL', 0, '2026-08-19'),
('LOTE-001', 'PAC-001', 'EST-001', 'LABORATORIO', 30, '2026-08-19'),
('LOTE-001', 'PAC-002', 'EST-002', 'CONSULTA', 240, '2026-08-19'),
('LOTE-001', 'PAC-001', 'EST-001', 'CONSULTA', 20, '2026-08-19');
GO

-- 3. Ejecutar la prueba del procedimiento
DECLARE @V INT, @O INT, @I INT;
DECLARE @M VARCHAR(300);

EXEC dbo.usp_EvaluarCalidadLote 
    @LoteCarga = 'LOTE-001',
    @TotalValidos = @V OUTPUT,
    @TotalObservados = @O OUTPUT,
    @TotalInvalidos = @I OUTPUT,
    @Mensaje = @M OUTPUT;

SELECT @V AS Validos, @O AS Observados, @I AS Invalidos, @M AS Mensaje;
GO