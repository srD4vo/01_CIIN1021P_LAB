-- ======================================================================
-- ====================== BLOQUE 1 ======================================
-- ============ REPASO DE TRANSACCIONES =================================
-- ======================================================================
USE BDDataSaludTema01;
GO

SELECT @@TRANCOUNT AS Antes;

BEGIN TRANSACTION;
    UPDATE dbo.EstablecimientoSalud SET Nombre = CONCAT(Nombre, ' (prueba)')
    WHERE EstablecimientoId = 1;
    
    SELECT @@TRANCOUNT AS Dentro, Nombre FROM dbo.EstablecimientoSalud WHERE EstablecimientoId = 1;
ROLLBACK TRANSACTION;

SELECT @@TRANCOUNT AS Despues, Nombre FROM dbo.EstablecimientoSalud WHERE EstablecimientoId = 1;
GO


-- ======================================================================
-- ====================== BLOQUE 2 ======================================
-- ============ AISLAMIENTO Y BLOQUEO (2 VENTANAS) ======================
-- ======================================================================
-- ⚠️ ATENCIÓN: Este bloque se ejecuta en 2 pestañas diferentes de SSMS.

-- ----------------------------------------------------------------------
-- BLOQUE 2 (PARTE A): Ejecutar en la VENTANA A
-- ----------------------------------------------------------------------
USE BDDataSaludTema01;
GO
BEGIN TRANSACTION;
UPDATE dbo.EstablecimientoSalud SET Provincia = 'Ascope' WHERE EstablecimientoId = 2;
SELECT @@TRANCOUNT AS TransaccionesAbiertas;
-- No ejecutes nada mas aqui hasta que la guia lo indique.
GO

-- ----------------------------------------------------------------------
-- BLOQUE 2 (PARTE B): Ejecutar en la VENTANA B
-- (Esta consulta se quedará "pensando" porque el dato está bloqueado)
-- ----------------------------------------------------------------------
USE BDDataSaludTema01;
GO
SELECT EstablecimientoId, Provincia FROM dbo.EstablecimientoSalud WHERE EstablecimientoId = 2;
GO

-- ----------------------------------------------------------------------
-- BLOQUE 2 (PARTE C): Volver a la VENTANA A para liberar el bloqueo
-- ----------------------------------------------------------------------
ROLLBACK TRANSACTION;
SELECT @@TRANCOUNT AS TransaccionesAbiertas;
GO


-- ======================================================================
-- ====================== BLOQUE 3 ======================================
-- ====== LOTE DE PRUEBA, TABLA DE CONTROL Y PROCEDIMIENTO ==============
-- ======================================================================
USE BDDataSaludTema01;
GO

DELETE FROM dbo.AtencionStaging WHERE LoteCarga = 'LOTE-004';
GO
INSERT INTO dbo.AtencionStaging
    (LoteCarga, CodigoPaciente, CodigoEstablecimiento, TipoAtencion, DuracionMinutos, FechaAtencion)
VALUES
('LOTE-004','PAC-001','EST-001','CONTROL',13,'2026-09-05'),
('LOTE-004','PAC-002','EST-002','VACUNACION',27,'2026-09-05');
GO

SELECT RegistroId, CodigoPaciente, TipoAtencion, DuracionMinutos, ClasificacionDuracion
FROM dbo.ufn_RegistrosAptosCarga('LOTE-004');
GO

DROP TABLE IF EXISTS dbo.ControlCargaLote;
GO
CREATE TABLE dbo.ControlCargaLote(
    CargaId INT IDENTITY(1,1) CONSTRAINT PK_ControlCargaLote PRIMARY KEY,
    LoteCarga VARCHAR(20) NOT NULL,
    FechaInicio DATETIME2 NOT NULL CONSTRAINT DF_ControlCarga_FechaInicio DEFAULT (SYSDATETIME()),
    FechaFin DATETIME2 NULL,
    Estado VARCHAR(15) NOT NULL,
    TotalAptos INT NOT NULL CONSTRAINT DF_ControlCarga_TotalAptos DEFAULT (0),
    FilasCargadas INT NOT NULL CONSTRAINT DF_ControlCarga_Filas DEFAULT (0),
    UsuarioBD NVARCHAR(128) NOT NULL,
    Mensaje VARCHAR(300) NULL,
    CONSTRAINT CK_ControlCarga_Estado CHECK (Estado IN ('INICIADO','CONFIRMADO','CANCELADO','ERROR'))
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarLoteTransaccional
    @LoteCarga VARCHAR(20),
    @Confirmar BIT,
    @SimularError BIT = 0,
    @CargaId INT OUTPUT,
    @FilasCargadas INT OUTPUT,
    @Mensaje VARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalAptos INT, @EnTransaccion BIT = 0;
    BEGIN TRY
        SET @CargaId = NULL; SET @FilasCargadas = 0; SET @Mensaje = NULL;

        IF @LoteCarga IS NULL OR LTRIM(RTRIM(@LoteCarga)) = ''
        BEGIN
            ;THROW 52001, 'El codigo del lote es obligatorio.', 1;
        END;
        
        IF NOT EXISTS (SELECT 1 FROM dbo.AtencionStaging WHERE LoteCarga = @LoteCarga)
        BEGIN
            ;THROW 52002, 'El lote indicado no tiene registros.', 1;
        END;
        
        IF @Confirmar IS NULL
        BEGIN
            ;THROW 52003, 'Debe indicar si la carga se confirma (1) o se cancela (0).', 1;
        END;

        SELECT @TotalAptos = COUNT(*) FROM dbo.ufn_RegistrosAptosCarga(@LoteCarga);

        BEGIN TRANSACTION;
        SET @EnTransaccion = 1;

        INSERT INTO dbo.ControlCargaLote (LoteCarga, Estado, TotalAptos, UsuarioBD)
        VALUES (@LoteCarga, 'INICIADO', @TotalAptos, SUSER_SNAME());
        SET @CargaId = CONVERT(INT, SCOPE_IDENTITY());

        SAVE TRANSACTION AntesCargaAtenciones;

        INSERT INTO dbo.Atencion
            (PacienteId, EstablecimientoId, TipoAtencion, DuracionMinutos,
             ClasificacionDuracion, FechaAtencion)
        SELECT R.PacienteId, R.EstablecimientoId, R.TipoAtencion, R.DuracionMinutos,
               R.ClasificacionDuracion, R.FechaAtencion
        FROM dbo.ufn_RegistrosAptosCarga(@LoteCarga) AS R
        WHERE NOT EXISTS
        (   
            SELECT 1 FROM dbo.Atencion AS A
            WHERE A.PacienteId = R.PacienteId AND A.EstablecimientoId = R.EstablecimientoId
              AND A.TipoAtencion = R.TipoAtencion AND A.DuracionMinutos = R.DuracionMinutos
              AND CAST(A.FechaAtencion AS DATE) = R.FechaAtencion
        );
        
        SET @FilasCargadas = @@ROWCOUNT;

        IF @SimularError = 1
        BEGIN
            ;THROW 52004, 'Error simulado durante la carga (prueba del CATCH).', 1;
        END;

        IF @Confirmar = 0
        BEGIN
            ROLLBACK TRANSACTION AntesCargaAtenciones;
            SET @FilasCargadas = 0;
            
            UPDATE dbo.ControlCargaLote
            SET Estado = 'CANCELADO', FilasCargadas = 0, FechaFin = SYSDATETIME(),
                Mensaje = 'Carga cancelada por el usuario.'
            WHERE CargaId = @CargaId;
            
            COMMIT TRANSACTION;
            SET @Mensaje = 'La carga fue cancelada. No se insertaron atenciones.';
            RETURN;
        END;

        UPDATE dbo.ControlCargaLote
        SET Estado = 'CONFIRMADO', FilasCargadas = @FilasCargadas, FechaFin = SYSDATETIME(),
            Mensaje = CONCAT('Filas insertadas: ', @FilasCargadas)
        WHERE CargaId = @CargaId;
        
        COMMIT TRANSACTION;
        SET @Mensaje = CONCAT('Carga confirmada. Filas insertadas: ', @FilasCargadas, '.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        IF @EnTransaccion = 1
        BEGIN
            INSERT INTO dbo.ControlCargaLote (LoteCarga, Estado, FechaFin, UsuarioBD, Mensaje)
            VALUES (@LoteCarga, 'ERROR', SYSDATETIME(), SUSER_SNAME(), LEFT(ERROR_MESSAGE(), 300));
            SET @CargaId = CONVERT(INT, SCOPE_IDENTITY());
        END;
        SET @Mensaje = CONCAT('Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
        THROW;
    END CATCH;
END;
GO


-- ======================================================================
-- VERIFICACIÓN VISUAL DEL BLOQUE 3 (Solo para capturar)
-- ======================================================================
USE BDDataSaludTema01;
GO

SELECT RegistroId, CodigoPaciente, TipoAtencion, DuracionMinutos, ClasificacionDuracion
FROM dbo.ufn_RegistrosAptosCarga('LOTE-004');
GO


-- ======================================================================
-- ====================== BLOQUE 4 ======================================
-- ============ PRUEBA 1 - CANCELAR LA CARGA ============================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @CargaId INT, @Filas INT, @Mensaje VARCHAR(300);
EXEC dbo.usp_CargarLoteTransaccional @LoteCarga = 'LOTE-004', @Confirmar = 0,
     @CargaId = @CargaId OUTPUT, @FilasCargadas = @Filas OUTPUT, @Mensaje = @Mensaje OUTPUT;

-- Forzar la visualización de los resultados
SELECT @CargaId AS CargaId, @Filas AS FilasCargadas, @Mensaje AS Mensaje,
       @@TRANCOUNT AS TransaccionesAbiertas;
GO

-- ======================================================================
-- ====================== BLOQUE 5 ======================================
-- ============ PRUEBA 2 - SIMULAR UN ERROR =============================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @CargaId INT, @Filas INT, @Mensaje VARCHAR(300);
BEGIN TRY
    EXEC dbo.usp_CargarLoteTransaccional @LoteCarga = 'LOTE-004', @Confirmar = 1, @SimularError = 1,
         @CargaId = @CargaId OUTPUT, @FilasCargadas = @Filas OUTPUT, @Mensaje = @Mensaje OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError,
           @@TRANCOUNT AS TransaccionesAbiertas;
END CATCH;
GO


-- ======================================================================
-- ====================== BLOQUE 6 ======================================
-- ============ PRUEBA 3 - CONFIRMAR LA CARGA ===========================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @CargaId INT, @Filas INT, @Mensaje VARCHAR(300);
EXEC dbo.usp_CargarLoteTransaccional @LoteCarga = 'LOTE-004', @Confirmar = 1,
     @CargaId = @CargaId OUTPUT, @FilasCargadas = @Filas OUTPUT, @Mensaje = @Mensaje OUTPUT;

SELECT @CargaId AS CargaId, @Filas AS FilasCargadas, @Mensaje AS Mensaje;
GO


-- ======================================================================
-- ====================== BLOQUE 7 ======================================
-- ============ VERIFICACIÓN DE LA EVIDENCIA ============================
-- ======================================================================
USE BDDataSaludTema01;
GO

SELECT CargaId, LoteCarga, Estado, TotalAptos, FilasCargadas, Mensaje
FROM dbo.ControlCargaLote WHERE LoteCarga = 'LOTE-004' ORDER BY CargaId;

SELECT A.AtencionId, P.CodigoPaciente, A.TipoAtencion, A.DuracionMinutos, A.FechaAtencion
FROM dbo.Atencion AS A INNER JOIN dbo.Paciente AS P ON P.PacienteId = A.PacienteId
WHERE CAST(A.FechaAtencion AS DATE) = '2026-09-05';

SELECT TOP (5) AuditoriaId, AtencionId, Operacion, DuracionNueva
FROM dbo.AuditoriaAtencion ORDER BY AuditoriaId DESC;
GO