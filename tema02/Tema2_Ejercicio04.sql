-- ======================================================================
-- ====================== BLOQUE 1 ======================================
-- ============ LOTE DE PRUEBA Y TABLA DE RESULTADOS ====================
-- ======================================================================
USE BDDataSaludTema01;
GO

-- Seguro por si PAC-002 quedó inactivo en el Ejercicio 02
UPDATE dbo.Paciente SET Estado = 'A' WHERE CodigoPaciente = 'PAC-002';

DELETE FROM dbo.AtencionStaging WHERE LoteCarga = 'LOTE-006';
GO
INSERT INTO dbo.AtencionStaging
    (LoteCarga, CodigoPaciente, CodigoEstablecimiento, TipoAtencion, DuracionMinutos, FechaAtencion)
VALUES
('LOTE-006','PAC-001','EST-001','CONSULTA',25,'2026-09-10'),
('LOTE-006','PAC-003','EST-001','CONSULTA',20,'2026-09-10'),
('LOTE-006','PAC-002','EST-002','CONTROL',12,'2026-09-10'),
('LOTE-006','PAC-001','EST-003','VACUNACION',15,'2026-09-10'),
('LOTE-006','PAC-002','EST-001','CONTROL',210,'2026-09-10');
GO

DROP TABLE IF EXISTS dbo.ResultadoCargaFila;
GO
CREATE TABLE dbo.ResultadoCargaFila(
    ResultadoId INT IDENTITY(1,1)
        CONSTRAINT PK_ResultadoCargaFila PRIMARY KEY,
    LoteCarga VARCHAR(20) NOT NULL,
    RegistroId INT NOT NULL,
    Resultado VARCHAR(10) NOT NULL,
    AtencionId INT NULL,
    NumeroError INT NULL,
    Mensaje VARCHAR(300) NULL,
    FechaProceso DATETIME2 NOT NULL
        CONSTRAINT DF_ResultadoCargaFila_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_ResultadoCargaFila_Resultado CHECK (Resultado IN ('CARGADO','RECHAZADO'))
);
GO


-- ======================================================================
-- ====================== BLOQUE 2 ======================================
-- ============ PROCEDIMIENTO CON CURSOR ================================
-- ======================================================================
USE BDDataSaludTema01;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarLoteFilaPorFila
    @LoteCarga VARCHAR(20),
    @Cargadas INT OUTPUT,
    @Rechazadas INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RegistroId INT, @PacienteId INT, @EstablecimientoId INT,
            @TipoAtencion VARCHAR(30), @DuracionMinutos INT,
            @A INT, @C VARCHAR(20), @M VARCHAR(300);
    BEGIN TRY
        SET @Cargadas = 0; SET @Rechazadas = 0;
        
        IF @LoteCarga IS NULL
           OR NOT EXISTS (SELECT 1 FROM dbo.AtencionStaging WHERE LoteCarga = @LoteCarga)
        BEGIN
            ;THROW 53001, 'El lote es obligatorio y debe tener registros.', 1;
        END;

        BEGIN TRANSACTION;

        -- TODO 1: Cursor de solo lectura y solo hacia adelante (LOCAL FAST_FORWARD)
        DECLARE cur_Filas CURSOR LOCAL FAST_FORWARD
        FOR
            SELECT S.RegistroId, P.PacienteId, E.EstablecimientoId,
                   S.TipoAtencion, S.DuracionMinutos
            FROM dbo.AtencionStaging AS S
            LEFT JOIN dbo.Paciente AS P ON P.CodigoPaciente = S.CodigoPaciente
            LEFT JOIN dbo.EstablecimientoSalud AS E
                ON E.CodigoEstablecimiento = S.CodigoEstablecimiento
            WHERE S.LoteCarga = @LoteCarga
            ORDER BY S.RegistroId;

        -- TODO 2: Abrir y leer la primera fila
        OPEN cur_Filas;
        FETCH NEXT FROM cur_Filas
            INTO @RegistroId, @PacienteId, @EstablecimientoId, @TipoAtencion, @DuracionMinutos;

        -- TODO 3: Repetir mientras la lectura fue exitosa
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- TODO 4: Un punto de guardado POR FILA
            SAVE TRANSACTION FilaActual;
            
            BEGIN TRY
                -- Se reutiliza el procedimiento del Tema 01
                EXEC dbo.usp_RegistrarAtencion
                    @PacienteId = @PacienteId, @EstablecimientoId = @EstablecimientoId,
                    @TipoAtencion = @TipoAtencion, @DuracionMinutos = @DuracionMinutos,
                    @AtencionId = @A OUTPUT, @Clasificacion = @C OUTPUT, @Mensaje = @M OUTPUT;
                    
                INSERT INTO dbo.ResultadoCargaFila
                    (LoteCarga, RegistroId, Resultado, AtencionId, Mensaje)
                VALUES (@LoteCarga, @RegistroId, 'CARGADO', @A, @M);
                
                SET @Cargadas += 1;
            END TRY
            BEGIN CATCH
                -- TODO 5: Si la transacción quedó condenada (-1), se relanza el error
                IF XACT_STATE() = -1
                BEGIN
                    ;THROW;
                END;
                
                -- Si sigue confirmable, se deshace SOLO esta fila y se registra el rechazo.
                ROLLBACK TRANSACTION FilaActual;
                
                INSERT INTO dbo.ResultadoCargaFila
                    (LoteCarga, RegistroId, Resultado, NumeroError, Mensaje)
                VALUES (@LoteCarga, @RegistroId, 'RECHAZADO', ERROR_NUMBER(),
                        LEFT(ERROR_MESSAGE(), 300));
                        
                SET @Rechazadas += 1;
            END CATCH;

            -- TODO 6: Avanzar a la siguiente fila
            FETCH NEXT FROM cur_Filas
                INTO @RegistroId, @PacienteId, @EstablecimientoId, @TipoAtencion, @DuracionMinutos;
        END;

        -- TODO 7: Cerrar y liberar el cursor
        CLOSE cur_Filas;
        DEALLOCATE cur_Filas;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        THROW;
    END CATCH;
END;
GO


-- ======================================================================
-- ====================== BLOQUE 3 ======================================
-- ============ PRUEBA DEL CURSOR =======================================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @Cargadas INT, @Rechazadas INT;
EXEC dbo.usp_CargarLoteFilaPorFila @LoteCarga = 'LOTE-006',
     @Cargadas = @Cargadas OUTPUT, @Rechazadas = @Rechazadas OUTPUT;

SELECT @Cargadas AS Cargadas, @Rechazadas AS Rechazadas;

SELECT RegistroId, Resultado, AtencionId, NumeroError, Mensaje
FROM dbo.ResultadoCargaFila WHERE LoteCarga = 'LOTE-006' ORDER BY RegistroId;

SELECT AlertaId, AtencionId, DuracionMinutos FROM dbo.AlertaAtencion WHERE DuracionMinutos = 210;
GO


-- ======================================================================
-- ====================== BLOQUE 4 ======================================
-- ============ VERSIÓN POR CONJUNTOS ===================================
-- ======================================================================
USE BDDataSaludTema01;
GO

SELECT RegistroId, CodigoPaciente, CodigoEstablecimiento, DuracionMinutos
FROM dbo.ufn_RegistrosAptosCarga('LOTE-006')
ORDER BY RegistroId;
GO


-- ======================================================================
-- ====================== BLOQUE 5 ======================================
-- ============ MEDICIÓN OPCIONAL (CURSOR VS CONJUNTOS) =================
-- ======================================================================
USE BDDataSaludTema01;
GO

DECLARE @N INT = 1000;
DELETE FROM dbo.AtencionStaging WHERE LoteCarga IN ('LOTE-007A', 'LOTE-007B');

;WITH Numeros AS (
    SELECT TOP (@N) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.AtencionStaging
    (LoteCarga, CodigoPaciente, CodigoEstablecimiento, TipoAtencion, DuracionMinutos, FechaAtencion)
SELECT L.Lote,
       CASE WHEN n % 2 = 0 THEN 'PAC-001' ELSE 'PAC-002' END,
       CASE WHEN (n / 2) % 2 = 0 THEN 'EST-001' ELSE 'EST-002' END,
       CASE (n / 4) % 3 WHEN 0 THEN 'CONSULTA' WHEN 1 THEN 'CONTROL' ELSE 'VACUNACION' END,
       (n / 12) % 180 + 1,
       '2026-09-20'
FROM Numeros CROSS JOIN (VALUES ('LOTE-007A'), ('LOTE-007B')) AS L(Lote);

DECLARE @t0 DATETIME2, @c INT, @r INT, @cid INT, @f INT, @m VARCHAR(300);

SET @t0 = SYSDATETIME();
EXEC dbo.usp_CargarLoteFilaPorFila @LoteCarga = 'LOTE-007A',
     @Cargadas = @c OUTPUT, @Rechazadas = @r OUTPUT;
SELECT 'Cursor (fila por fila)' AS Estrategia, @c AS Filas,
       DATEDIFF(MILLISECOND, @t0, SYSDATETIME()) AS Milisegundos;

SET @t0 = SYSDATETIME();
EXEC dbo.usp_CargarLoteTransaccional @LoteCarga = 'LOTE-007B', @Confirmar = 1,
     @CargaId = @cid OUTPUT, @FilasCargadas = @f OUTPUT, @Mensaje = @m OUTPUT;
SELECT 'Por conjuntos (INSERT ... SELECT)' AS Estrategia, @f AS Filas,
       DATEDIFF(MILLISECOND, @t0, SYSDATETIME()) AS Milisegundos;
GO


-- ======================================================================
-- ====================== BLOQUE 6 ======================================
-- ============ LIMPIEZA (SOLO SI NECESITAS REPETIR) ====================
-- ======================================================================
DELETE A FROM dbo.Atencion AS A
INNER JOIN dbo.ResultadoCargaFila AS R ON R.AtencionId = A.AtencionId
WHERE R.LoteCarga = 'LOTE-006';
DELETE FROM dbo.ResultadoCargaFila WHERE LoteCarga = 'LOTE-006';
GO