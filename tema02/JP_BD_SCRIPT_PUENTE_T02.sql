/* ======================================================================
   SCRIPT PUENTE - ESTADO DEL TEMA 01 PARA INICIAR EL TEMA 02
   Curso: Base de Datos Avanzadas y Big Data (CIIN1021P) - Tema 02
   Docente: Ing. Andres E. Araujo Acuna
   Reconstruye BDDataSaludTema01 con TODO lo que el Tema 02 necesita del Tema 01:
   tablas, datos sinteticos, ufn_ClasificarDuracionAtencion, usp_RegistrarAtencion, AtencionStaging,
   LOTE-001, usp_EvaluarCalidadLote, ufn_RegistrosAptosCarga, LOTE-002 y 3 atenciones de prueba.
   ATENCION: contiene DROP DATABASE. Borra tu base del Tema 01 y la crea de nuevo.
   Usalo solo si tu base no existe o esta incompleta. Si solo te falta la funcion tabular,
   usa JP_BD_SCRIPT_COMPLEMENTO_T02.sql, que no borra nada.
   No lo ejecutes a mitad del Tema 02: perderias los objetos que ya creaste.
   Ejecucion: abre el archivo en SSMS y presiona F5 (todo el script).
   ====================================================================== */

/* ------------------------------------------------------------------
   TEMA 01 - Base nueva
   ------------------------------------------------------------------ */
USE master;
GO
IF DB_ID('BDDataSaludTema01') IS NOT NULL
BEGIN
    ALTER DATABASE BDDataSaludTema01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BDDataSaludTema01;
END;
GO
CREATE DATABASE BDDataSaludTema01;
GO
USE BDDataSaludTema01;
GO

/* ------------------------------------------------------------------
   TEMA 01 - Tablas maestras y Atencion
   ------------------------------------------------------------------ */
CREATE TABLE dbo.Paciente(
    PacienteId INT IDENTITY(1,1)
        CONSTRAINT PK_Paciente PRIMARY KEY,
    CodigoPaciente VARCHAR(20) NOT NULL,
    Estado CHAR(1) NOT NULL
        CONSTRAINT DF_Paciente_Estado DEFAULT ('A'),
    CONSTRAINT UQ_Paciente_Codigo UNIQUE (CodigoPaciente),
    CONSTRAINT CK_Paciente_Estado CHECK (Estado IN ('A','I'))
);
GO
CREATE TABLE dbo.EstablecimientoSalud(
    EstablecimientoId INT IDENTITY(1,1)
        CONSTRAINT PK_EstablecimientoSalud PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(20) NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Provincia VARCHAR(60) NOT NULL,
    Estado CHAR(1) NOT NULL
        CONSTRAINT DF_Establecimiento_Estado DEFAULT ('A'),
    CONSTRAINT UQ_Establecimiento_Codigo UNIQUE (CodigoEstablecimiento),
    CONSTRAINT CK_Establecimiento_Estado CHECK (Estado IN ('A','I'))
);
GO
CREATE TABLE dbo.Atencion(
    AtencionId INT IDENTITY(1,1)
        CONSTRAINT PK_Atencion PRIMARY KEY,
    PacienteId INT NOT NULL,
    EstablecimientoId INT NOT NULL,
    TipoAtencion VARCHAR(30) NOT NULL,
    DuracionMinutos INT NOT NULL,
    ClasificacionDuracion VARCHAR(20) NOT NULL,
    FechaAtencion DATETIME2 NOT NULL
        CONSTRAINT DF_Atencion_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Atencion_Paciente
        FOREIGN KEY (PacienteId) REFERENCES dbo.Paciente(PacienteId),
    CONSTRAINT FK_Atencion_Establecimiento
        FOREIGN KEY (EstablecimientoId)
        REFERENCES dbo.EstablecimientoSalud(EstablecimientoId),
    CONSTRAINT CK_Atencion_Duracion CHECK (DuracionMinutos > 0),
    CONSTRAINT CK_Atencion_Tipo
        CHECK (TipoAtencion IN ('CONSULTA','CONTROL','VACUNACION')),
    CONSTRAINT CK_Atencion_Clasificacion
        CHECK (ClasificacionDuracion IN ('CORTA','REGULAR','PROLONGADA'))
);
GO

/* ------------------------------------------------------------------
   TEMA 01 - Datos sinteticos (PAC-003 y EST-003 inactivos)
   ------------------------------------------------------------------ */
INSERT INTO dbo.Paciente(CodigoPaciente, Estado)
VALUES
('PAC-001','A'),
('PAC-002','A'),
('PAC-003','I');
GO
INSERT INTO dbo.EstablecimientoSalud
    (CodigoEstablecimiento, Nombre, Provincia, Estado)
VALUES
('EST-001','Centro de Salud Norte','Trujillo','A'),
('EST-002','Puesto de Salud Esperanza','Trujillo','A'),
('EST-003','Centro de Salud Temporal','Trujillo','I');
GO
SELECT PacienteId, CodigoPaciente, Estado FROM dbo.Paciente;
SELECT EstablecimientoId, CodigoEstablecimiento, Estado FROM dbo.EstablecimientoSalud;
GO

/* ------------------------------------------------------------------
   TEMA 01 - Funcion escalar
   ------------------------------------------------------------------ */
USE BDDataSaludTema01;
GO
CREATE OR ALTER FUNCTION dbo.ufn_ClasificarDuracionAtencion(
    @Minutos INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Clasificacion VARCHAR(20);

    IF @Minutos IS NULL OR @Minutos <= 0
    BEGIN
        RETURN NULL;
    END;

    SET @Clasificacion =
        CASE
            WHEN @Minutos BETWEEN 1 AND 15 THEN 'CORTA'
            WHEN @Minutos BETWEEN 16 AND 30 THEN 'REGULAR'
            ELSE 'PROLONGADA'
        END;

    RETURN @Clasificacion;
END;
GO

/* ------------------------------------------------------------------
   TEMA 01 - Procedimiento de registro
   ------------------------------------------------------------------ */
USE BDDataSaludTema01;
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
        SET @AtencionId = NULL;
        SET @Clasificacion = NULL;
        SET @Mensaje = NULL;

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

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Paciente
            WHERE PacienteId = @PacienteId
              AND Estado = 'A'
        )
        BEGIN
            ;THROW 50033, 'El paciente se encuentra inactivo.', 1;
        END;

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

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.EstablecimientoSalud
            WHERE EstablecimientoId = @EstablecimientoId
              AND Estado = 'A'
        )
        BEGIN
            ;THROW 50036, 'El establecimiento se encuentra inactivo.', 1;
        END;

        IF @TipoAtencion IS NULL
           OR LTRIM(RTRIM(@TipoAtencion)) = ''
        BEGIN
            ;THROW 50037, 'El tipo de atencion es obligatorio.', 1;
        END;

        IF @TipoAtencion NOT IN ('CONSULTA','CONTROL','VACUNACION')
        BEGIN
            ;THROW 50038, 'El tipo de atencion indicado no es valido.', 1;
        END;

        IF @DuracionMinutos IS NULL
           OR @DuracionMinutos <= 0
        BEGIN
            ;THROW 50039, 'La duracion debe ser mayor que cero.', 1;
        END;

        SET @Clasificacion = dbo.ufn_ClasificarDuracionAtencion(@DuracionMinutos);

        IF @Clasificacion IS NULL
        BEGIN
            ;THROW 50040, 'No fue posible clasificar la duracion.', 1;
        END;

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

/* ------------------------------------------------------------------
   TEMA 01 - Staging
   ------------------------------------------------------------------ */
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

/* ------------------------------------------------------------------
   TEMA 01 - LOTE-001
   ------------------------------------------------------------------ */
INSERT INTO dbo.AtencionStaging
(
    LoteCarga, CodigoPaciente, CodigoEstablecimiento,
    TipoAtencion, DuracionMinutos, FechaAtencion
)
VALUES
('LOTE-001','PAC-001','EST-001','CONSULTA',20,'2026-08-19'),
('LOTE-001',NULL,'EST-001','CONSULTA',15,'2026-08-19'),
('LOTE-001','PAC-002','EST-002','CONTROL',0,'2026-08-19'),
('LOTE-001','PAC-001','EST-001','LABORATORIO',30,'2026-08-19'),
('LOTE-001','PAC-002','EST-002','CONSULTA',240,'2026-08-19'),
('LOTE-001','PAC-001','EST-001','CONSULTA',20,'2026-08-19');
GO

/* ------------------------------------------------------------------
   TEMA 01 - Evaluacion de calidad
   ------------------------------------------------------------------ */
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

        INSERT INTO @Evaluacion (RegistroId, Clasificacion, Motivo)
        SELECT A.RegistroId, NULL, NULL
        FROM dbo.AtencionStaging AS A
        WHERE A.LoteCarga = @LoteCarga;

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

        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Duracion invalida.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND (A.DuracionMinutos IS NULL OR A.DuracionMinutos <= 0);

        UPDATE E
        SET E.Clasificacion = 'INVALIDO',
            E.Motivo = 'Tipo de atencion no permitido.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND A.TipoAtencion NOT IN ('CONSULTA','CONTROL','VACUNACION');

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
                AND B.RegistroId < A.RegistroId
                AND B.CodigoPaciente = A.CodigoPaciente
                AND B.CodigoEstablecimiento = A.CodigoEstablecimiento
                AND B.TipoAtencion = A.TipoAtencion
                AND B.DuracionMinutos = A.DuracionMinutos
                AND B.FechaAtencion = A.FechaAtencion
          );

        UPDATE E
        SET E.Clasificacion = 'OBSERVADO',
            E.Motivo = 'Duracion mayor a 180 minutos.'
        FROM @Evaluacion AS E
        INNER JOIN dbo.AtencionStaging AS A ON A.RegistroId = E.RegistroId
        WHERE E.Clasificacion IS NULL
          AND A.DuracionMinutos > 180;

        UPDATE @Evaluacion
        SET Clasificacion = 'VALIDO',
            Motivo = 'Cumple las reglas.'
        WHERE Clasificacion IS NULL;

        SELECT
            @TotalValidos =
                SUM(CASE WHEN Clasificacion = 'VALIDO' THEN 1 ELSE 0 END),
            @TotalObservados =
                SUM(CASE WHEN Clasificacion = 'OBSERVADO' THEN 1 ELSE 0 END),
            @TotalInvalidos =
                SUM(CASE WHEN Clasificacion = 'INVALIDO' THEN 1 ELSE 0 END)
        FROM @Evaluacion;

        SELECT
            A.RegistroId, A.CodigoPaciente, A.CodigoEstablecimiento,
            A.TipoAtencion, A.DuracionMinutos, A.FechaAtencion,
            E.Clasificacion, E.Motivo
        FROM dbo.AtencionStaging AS A
        INNER JOIN @Evaluacion AS E ON E.RegistroId = A.RegistroId
        WHERE A.LoteCarga = @LoteCarga
        ORDER BY A.RegistroId;

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

/* ------------------------------------------------------------------
   TEMA 01 - Funcion tabular de registros aptos
   ------------------------------------------------------------------ */
CREATE OR ALTER FUNCTION dbo.ufn_RegistrosAptosCarga(
    @LoteCarga VARCHAR(20)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        S.RegistroId,
        P.PacienteId,
        E.EstablecimientoId,
        S.CodigoPaciente,
        S.CodigoEstablecimiento,
        S.TipoAtencion,
        S.DuracionMinutos,
        dbo.ufn_ClasificarDuracionAtencion(S.DuracionMinutos) AS ClasificacionDuracion,
        S.FechaAtencion
    FROM dbo.AtencionStaging AS S
    INNER JOIN dbo.Paciente AS P
        ON P.CodigoPaciente = S.CodigoPaciente
       AND P.Estado = 'A'
    INNER JOIN dbo.EstablecimientoSalud AS E
        ON E.CodigoEstablecimiento = S.CodigoEstablecimiento
       AND E.Estado = 'A'
    WHERE S.LoteCarga = @LoteCarga
      AND S.TipoAtencion IN ('CONSULTA','CONTROL','VACUNACION')
      AND S.DuracionMinutos BETWEEN 1 AND 180
      AND S.FechaAtencion IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.AtencionStaging AS B
          WHERE B.LoteCarga = S.LoteCarga
            AND B.RegistroId < S.RegistroId
            AND B.CodigoPaciente = S.CodigoPaciente
            AND B.CodigoEstablecimiento = S.CodigoEstablecimiento
            AND B.TipoAtencion = S.TipoAtencion
            AND B.DuracionMinutos = S.DuracionMinutos
            AND B.FechaAtencion = S.FechaAtencion
      )
);
GO

/* ------------------------------------------------------------------
   TEMA 01 - LOTE-002
   ------------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM dbo.AtencionStaging WHERE LoteCarga = 'LOTE-002')
BEGIN
    INSERT INTO dbo.AtencionStaging
    (
        LoteCarga, CodigoPaciente, CodigoEstablecimiento,
        TipoAtencion, DuracionMinutos, FechaAtencion
    )
    VALUES
    ('LOTE-002','PAC-001','EST-001','CONTROL',10,'2026-08-20'),
    ('LOTE-002','PAC-002','EST-002','VACUNACION',25,'2026-08-20'),
    ('LOTE-002','PAC-003','EST-001','CONSULTA',15,'2026-08-20'),
    ('LOTE-002','PAC-999','EST-001','CONSULTA',20,'2026-08-20');
END;
GO
SELECT *
FROM dbo.ufn_RegistrosAptosCarga('LOTE-002')
ORDER BY RegistroId;
GO

/* ------------------------------------------------------------------
   TEMA 01 - Atenciones de prueba (las del Ejercicio 03 del Tema 01)
   ------------------------------------------------------------------ */
DECLARE @A INT, @C VARCHAR(20), @M VARCHAR(300);
EXEC dbo.usp_RegistrarAtencion @PacienteId = 1, @EstablecimientoId = 1, @TipoAtencion = 'CONSULTA', @DuracionMinutos = 20,
     @AtencionId = @A OUTPUT, @Clasificacion = @C OUTPUT, @Mensaje = @M OUTPUT;
EXEC dbo.usp_RegistrarAtencion @PacienteId = 2, @EstablecimientoId = 2, @TipoAtencion = 'CONTROL', @DuracionMinutos = 12,
     @AtencionId = @A OUTPUT, @Clasificacion = @C OUTPUT, @Mensaje = @M OUTPUT;
EXEC dbo.usp_RegistrarAtencion @PacienteId = 1, @EstablecimientoId = 2, @TipoAtencion = 'VACUNACION', @DuracionMinutos = 45,
     @AtencionId = @A OUTPUT, @Clasificacion = @C OUTPUT, @Mensaje = @M OUTPUT;
GO

/* ------------------------------------------------------------------
   VERIFICACION FINAL
   Deben aparecer 8 objetos y 3 atenciones.
   ------------------------------------------------------------------ */
-- Deben aparecer 8 objetos del Tema 01.
SELECT name, type_desc
FROM sys.objects
WHERE name IN ('Paciente', 'EstablecimientoSalud', 'Atencion', 'AtencionStaging',
               'ufn_ClasificarDuracionAtencion', 'usp_RegistrarAtencion',
               'usp_EvaluarCalidadLote', 'ufn_RegistrosAptosCarga')
ORDER BY name;

-- PAC-001 y PAC-002 deben estar activos ('A'); PAC-003 inactivo ('I').
SELECT CodigoPaciente, Estado FROM dbo.Paciente ORDER BY PacienteId;
SELECT CodigoEstablecimiento, Estado FROM dbo.EstablecimientoSalud ORDER BY EstablecimientoId;
GO
SELECT COUNT(*) AS Atenciones FROM dbo.Atencion;
GO
