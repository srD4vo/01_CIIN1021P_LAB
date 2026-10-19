-- Verificacion del entorno (ejecutala en SSMS)
SELECT @@VERSION AS VersionSQLServer;
GO

-- ATENCION: este bloque REINICIA el Tema 01. Elimina la base si ya existía (con todos sus datos) y la crea limpia.
USE master;
GO
IF DB_ID('BBDatosSaludTema01') IS NOT NULL
BEGIN
    ALTER DATABASE BBDatosSaludTema01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BBDatosSaludTema01;
END;
GO
CREATE DATABASE BBDatosSaludTema01;
GO
USE BBDatosSaludTema01;
GO

-- Crear tabla Paciente
CREATE TABLE dbo.Paciente(
    PacienteId INT IDENTITY(1,1)
        CONSTRAINT PK_Paciente PRIMARY KEY,
    CodigoPaciente VARCHAR(20) NOT NULL,
    Estado CHAR(1) NOT NULL
        CONSTRAINT DF_Paciente_Estado DEFAULT ('A'),
    CONSTRAINT UQ_Paciente_Codigo UNIQUE (CodigoPaciente),
    CONSTRAINT CK_Paciente_Estado CHECK (Estado IN ('A', 'I'))
);
GO

-- Crear tabla EstablecimientoSalud
CREATE TABLE dbo.EstablecimientoSalud(
    EstablecimientoId INT IDENTITY(1,1)
        CONSTRAINT PK_EstablecimientoSalud PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(20) NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Provincia VARCHAR(60) NOT NULL,
    Estado CHAR(1) NOT NULL
        CONSTRAINT DF_Establecimiento_Estado DEFAULT ('A'),
    CONSTRAINT UQ_Establecimiento_Codigo UNIQUE (CodigoEstablecimiento),
    CONSTRAINT CK_Establecimiento_Estado CHECK (Estado IN ('A', 'I'))
);
GO

-- Crear tabla Atencion
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
        CHECK (TipoAtencion IN ('CONSULTA', 'CONTROL', 'VACUNACION')),
    CONSTRAINT CK_Atencion_Clasificacion
        CHECK (ClasificacionDuracion IN ('CORTA', 'REGULAR', 'PROLONGADA'))
);
GO

-- Insertar Pacientes
INSERT INTO dbo.Paciente(CodigoPaciente, Estado)
VALUES
('PAC-001', 'A'),
('PAC-002', 'A'),
('PAC-003', 'I');
GO

-- Insertar Establecimientos
INSERT INTO dbo.EstablecimientoSalud 
    (CodigoEstablecimiento, Nombre, Provincia, Estado)
VALUES
('EST-001', 'Centro de Salud Norte', 'Trujillo', 'A'),
('EST-002', 'Puesto de Salud Esperanza', 'Trujillo', 'A'),
('EST-003', 'Centro de Salud Temporal', 'Trujillo', 'I');
GO

-- Verificar inserción
SELECT PacienteId, CodigoPaciente, Estado FROM dbo.Paciente;
SELECT EstablecimientoId, CodigoEstablecimiento, Estado FROM dbo.EstablecimientoSalud;
GO

-------------------------

/* ------------------------------------------------------
   EJERCICIO 01 - PASO 5: BLOQUE DE VALIDACION (IF / ELSE IF / CASE)
------------------------------------------------------ */
-- Las cuatro primeras son los datos de entrada; las tres siguientes son los resultados.
DECLARE @PacienteId INT = 1;
DECLARE @EstablecimientoId INT = 1;
DECLARE @TipoAtencion VARCHAR(30) = 'CONSULTA';
DECLARE @DuracionMinutos INT = 20;
DECLARE @EstadoValidacion VARCHAR(15);
DECLARE @Clasificacion VARCHAR(20);
DECLARE @Mensaje VARCHAR(250);

-- Se parte de la hipótesis 'VALIDO' y las reglas la van descartando.
SET @EstadoValidacion = 'VALIDO';
SET @Clasificacion = NULL;
SET @Mensaje = NULL;

IF @PacienteId IS NULL
    OR NOT EXISTS
        (SELECT 1 FROM dbo.Paciente
        WHERE PacienteId = @PacienteId AND Estado = 'A')
BEGIN
    SET @EstadoValidacion = 'INVALIDO';
    SET @Mensaje = 'El paciente no existe o se encuentra inactivo.';
END
ELSE IF @EstablecimientoId IS NULL
    OR NOT EXISTS
        (SELECT 1 FROM dbo.EstablecimientoSalud
        WHERE EstablecimientoId = @EstablecimientoId
        AND Estado = 'A')
BEGIN
    SET @EstadoValidacion = 'INVALIDO';
    SET @Mensaje = 'El establecimiento no existe o esta inactivo.';
END
ELSE IF @TipoAtencion IS NULL
    OR LTRIM(RTRIM(@TipoAtencion)) = ''
BEGIN
    SET @EstadoValidacion = 'INVALIDO';
    SET @Mensaje = 'El tipo de atencion es obligatorio.';
END
ELSE IF @TipoAtencion NOT IN
    ('CONSULTA','CONTROL','VACUNACION')
BEGIN
    SET @EstadoValidacion = 'INVALIDO';
    SET @Mensaje = 'El tipo de atencion indicado no es valido.';
END
ELSE IF @DuracionMinutos IS NULL
    OR @DuracionMinutos <= 0
BEGIN
    SET @EstadoValidacion = 'INVALIDO';
    SET @Mensaje = 'La duracion debe ser mayor que cero.';
END
ELSE
BEGIN
    SET @Clasificacion = 
        CASE
            -- TODO 0. Completar la clasificación REGULAR.
            -- 1. BETWEEN incluye ambos extremos del rango.
            WHEN @DuracionMinutos BETWEEN 0 AND 14 
                THEN 'CORTA'
            WHEN @DuracionMinutos BETWEEN 15 AND 30 
                THEN 'REGULAR'
            -- Si no corresponde a los rangos anteriores,
            -- la duración es PROLONGADA.
            ELSE 'PROLONGADA'
        END;

    SET @Mensaje = 'Los datos de la atencion son validos.';
END;

SELECT 
    @PacienteId AS PacienteId,
    @EstablecimientoId AS EstablecimientoId,
    @TipoAtencion AS TipoAtencion,
    @DuracionMinutos AS DuracionMinutos,
    @EstadoValidacion AS EstadoValidacion,
    @Clasificacion AS Clasificacion,
    @Mensaje AS Mensaje;
GO


------------------------

DECLARE @Minutos INT = 10;

-- TODO 1 (concepto: condición de repetición)
-- 1) WHILE repite su bloque mientras la condición sea verdadera.
-- 2) Queremos probar 10, 20, 30 y 40 minutos: 40 es el último valor que debe entrar al ciclo.
-- 3) Escribe la condición comparando @Minutos con ese límite.
WHILE @Minutos <= 40
BEGIN
    PRINT CONCAT(@Minutos, ' min -> ',
        CASE
            WHEN @Minutos BETWEEN 1 AND 15 THEN 'CORTA'
            WHEN @Minutos BETWEEN 16 AND 30 THEN 'REGULAR'
            ELSE 'PROLONGADA'
        END);

    -- TODO 2 (concepto: avance del ciclo)
    -- 1) Si la variable no cambia dentro del ciclo, la condición nunca deja de cumplirse.
    -- 2) Avanza de 10 en 10 reasignando la propia variable.
    SET @Minutos = @Minutos + 10;
END;
GO