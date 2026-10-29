-- ======================================================================
-- BLOQUE 1: Crear la tabla de auditoría
-- ======================================================================
USE BDDataSaludTema01;
GO

DROP TRIGGER IF EXISTS dbo.trg_Atencion_Auditoria;
DROP TRIGGER IF EXISTS dbo.trg_Atencion_AuditoriaUnaFila;
GO
DROP TABLE IF EXISTS dbo.AuditoriaAtencion;
GO
CREATE TABLE dbo.AuditoriaAtencion(
    AuditoriaId BIGINT IDENTITY(1,1)
        CONSTRAINT PK_AuditoriaAtencion PRIMARY KEY,
    AtencionId INT NOT NULL,
    Operacion VARCHAR(10) NOT NULL,
    FechaOperacion DATETIME2 NOT NULL
        CONSTRAINT DF_AuditoriaAtencion_Fecha DEFAULT (SYSDATETIME()),
    UsuarioBD NVARCHAR(128) NOT NULL,
    TerminalBD NVARCHAR(128) NULL,
    AplicacionBD NVARCHAR(128) NULL,
    PacienteIdAnterior INT NULL,
    PacienteIdNuevo INT NULL,
    EstablecimientoIdAnterior INT NULL,
    EstablecimientoIdNuevo INT NULL,
    TipoAtencionAnterior VARCHAR(30) NULL,
    TipoAtencionNuevo VARCHAR(30) NULL,
    DuracionAnterior INT NULL,
    DuracionNueva INT NULL,
    ClasificacionAnterior VARCHAR(20) NULL,
    ClasificacionNueva VARCHAR(20) NULL,
    CONSTRAINT CK_AuditoriaAtencion_Operacion
        CHECK (Operacion IN ('INSERT','UPDATE','DELETE'))
);
GO

-- ======================================================================
-- BLOQUE 2: El error clásico (Trigger incorrecto)
-- ======================================================================
USE BDDataSaludTema01;
GO

-- Trigger INCORRECTO a proposito: guarda los datos de UNA sola fila en variables.
CREATE OR ALTER TRIGGER dbo.trg_Atencion_AuditoriaUnaFila
ON dbo.Atencion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AtencionId INT, @Duracion INT;
    SELECT @AtencionId = AtencionId, @Duracion = DuracionMinutos FROM inserted;

    INSERT INTO dbo.AuditoriaAtencion (AtencionId, Operacion, UsuarioBD, DuracionNueva)
    VALUES (@AtencionId, 'INSERT', SUSER_SNAME(), @Duracion);
END;
GO

-- Prediccion: una sola sentencia INSERT con 2 filas. Cuantas filas de auditoria aparecen?
DECLARE @MaxAtencion INT = ISNULL((SELECT MAX(AtencionId) FROM dbo.Atencion), 0);

INSERT INTO dbo.Atencion
    (PacienteId, EstablecimientoId, TipoAtencion, DuracionMinutos, ClasificacionDuracion)
VALUES (1, 1, 'CONTROL', 10, 'CORTA'),
       (2, 2, 'VACUNACION', 25, 'REGULAR');

-- ⚠️ IMPORTANTE PARA EL PDF: Captura este resultado. 
-- Verás que insertamos 2 atenciones, pero "FilasDeAuditoria" dice 1.
SELECT COUNT(*) AS AtencionesInsertadas FROM dbo.Atencion WHERE AtencionId > @MaxAtencion;
SELECT COUNT(*) AS FilasDeAuditoria FROM dbo.AuditoriaAtencion;

-- Limpieza de la demostracion: se elimina el trigger incorrecto y sus datos de prueba.
DROP TRIGGER dbo.trg_Atencion_AuditoriaUnaFila;
DELETE FROM dbo.Atencion WHERE AtencionId > @MaxAtencion;
DELETE FROM dbo.AuditoriaAtencion;
GO

-- ======================================================================
-- BLOQUE 3: Trigger correcto (AFTER INSERT, UPDATE, DELETE)
-- ======================================================================
USE BDDataSaludTema01;
GO

CREATE OR ALTER TRIGGER dbo.trg_Atencion_Auditoria
ON dbo.Atencion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditoriaAtencion
    (
        AtencionId, Operacion, UsuarioBD, TerminalBD, AplicacionBD,
        PacienteIdAnterior, PacienteIdNuevo,
        EstablecimientoIdAnterior, EstablecimientoIdNuevo,
        TipoAtencionAnterior, TipoAtencionNuevo,
        DuracionAnterior, DuracionNueva,
        ClasificacionAnterior, ClasificacionNueva
    )
    SELECT
        COALESCE(I.AtencionId, D.AtencionId),
        
        -- TODO 0: Determina el tipo de operación.
        CASE
            WHEN D.AtencionId IS NULL THEN 'INSERT'
            WHEN I.AtencionId IS NULL THEN 'DELETE'
            ELSE 'UPDATE'
        END,
        
        SUSER_SNAME(),
        
        -- TODO 1: Terminal y Aplicación
        HOST_NAME(),
        APP_NAME(),
        
        D.PacienteId, I.PacienteId,
        D.EstablecimientoId, I.EstablecimientoId,
        D.TipoAtencion, I.TipoAtencion,
        D.DuracionMinutos, I.DuracionMinutos,
        D.ClasificacionDuracion, I.ClasificacionDuracion
    FROM inserted AS I
    FULL OUTER JOIN deleted AS D
        ON I.AtencionId = D.AtencionId
    -- TODO 2: Auditar INSERT, DELETE y cambios reales
    WHERE D.AtencionId IS NULL
       OR I.AtencionId IS NULL
       OR I.PacienteId <> D.PacienteId
       OR I.EstablecimientoId <> D.EstablecimientoId
       OR I.TipoAtencion <> D.TipoAtencion
       OR I.DuracionMinutos <> D.DuracionMinutos
       OR I.ClasificacionDuracion <> D.ClasificacionDuracion;
END;
GO

-- ======================================================================
-- BLOQUE 4: Prueba con una fila
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @Id INT;

-- 1) INSERT
INSERT INTO dbo.Atencion
    (PacienteId, EstablecimientoId, TipoAtencion, DuracionMinutos, ClasificacionDuracion)
VALUES (1, 1, 'CONSULTA', 20, 'REGULAR');
SET @Id = CONVERT(INT, SCOPE_IDENTITY());

-- 2) UPDATE con cambio real
UPDATE dbo.Atencion SET DuracionMinutos = 35, ClasificacionDuracion = 'PROLONGADA'
WHERE AtencionId = @Id;

-- 3) UPDATE SIN cambio real (asigna el mismo valor)
UPDATE dbo.Atencion SET DuracionMinutos = DuracionMinutos WHERE AtencionId = @Id;

-- 4) DELETE
DELETE FROM dbo.Atencion WHERE AtencionId = @Id;

-- ⚠️ IMPORTANTE PARA EL PDF: Captura este resultado.
-- Deben salir EXACTAMENTE 3 filas (INSERT, UPDATE, DELETE). 
-- El UPDATE falso no debe aparecer. Fíjate en TerminalBD y AplicacionBD.
SELECT AuditoriaId, AtencionId, Operacion, DuracionAnterior, DuracionNueva,
       ClasificacionAnterior, ClasificacionNueva, UsuarioBD, TerminalBD, AplicacionBD
FROM dbo.AuditoriaAtencion
WHERE AtencionId = @Id
ORDER BY AuditoriaId;
GO

-- ======================================================================
-- BLOQUE 5: Prueba con varias filas en una sola sentencia
-- ======================================================================
USE BDDataSaludTema01;
GO

-- Prueba con varias filas en una sola sentencia.
DECLARE @Antes BIGINT = ISNULL((SELECT MAX(AuditoriaId) FROM dbo.AuditoriaAtencion), 0);

INSERT INTO dbo.Atencion
    (PacienteId, EstablecimientoId, TipoAtencion, DuracionMinutos, ClasificacionDuracion)
VALUES (1, 1, 'CONTROL', 11, 'CORTA'),
       (2, 2, 'VACUNACION', 26, 'REGULAR');

DELETE FROM dbo.Atencion
WHERE AtencionId IN (SELECT AtencionId FROM dbo.AuditoriaAtencion WHERE AuditoriaId > @Antes);

-- ⚠️ IMPORTANTE PARA EL PDF: Captura este resultado.
-- Deben salir 2 filas: DELETE = 2 e INSERT = 2. 
SELECT Operacion, COUNT(*) AS Filas
FROM dbo.AuditoriaAtencion
WHERE AuditoriaId > @Antes
GROUP BY Operacion
ORDER BY Operacion;
GO