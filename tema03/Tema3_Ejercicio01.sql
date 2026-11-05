/* ======================================================================
   EJERCICIO 01 - BLOQUE 1: CREACIÓN DE TABLAS E INSERCIÓN DE STOCK
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- Limpieza de intentos anteriores (Evita errores de "objeto ya existe")
DROP PROCEDURE IF EXISTS dbo.usp_DispensarVacuna;
DROP TABLE IF EXISTS dbo.AlertaStock;
DROP TABLE IF EXISTS dbo.DispensacionVacuna;
DROP TABLE IF EXISTS dbo.StockVacuna;
GO

-- 1. Tabla de Stock de Vacunas
-- CONCEPTO: Almacena el inventario. El CHECK evita que el stock quede negativo por errores de lógica.
CREATE TABLE dbo.StockVacuna(
    StockVacunaId INT IDENTITY(1,1)
        CONSTRAINT PK_StockVacuna PRIMARY KEY,
    EstablecimientoId INT NOT NULL
        CONSTRAINT FK_StockVacuna_Establecimiento
        REFERENCES dbo.EstablecimientoSalud(EstablecimientoId), -- FK: Asegura que el establecimiento exista
    Vacuna VARCHAR(30) NOT NULL,
    Stock INT NOT NULL,
    StockMinimo INT NOT NULL,
    CONSTRAINT UQ_StockVacuna UNIQUE (EstablecimientoId, Vacuna), -- UQ: Un establecimiento no puede tener dos registros de la misma vacuna
    CONSTRAINT CK_StockVacuna_Stock CHECK (Stock >= 0) -- CK: Blindaje a nivel de motor para evitar stock negativo
);
GO

-- 2. Tabla de Dispensación (Vacunas aplicadas)
-- CONCEPTO: Registra el historial (quién, cuándo y qué se aplicó).
CREATE TABLE dbo.DispensacionVacuna(
    DispensacionId INT IDENTITY(1,1)
        CONSTRAINT PK_DispensacionVacuna PRIMARY KEY,
    AtencionId INT NOT NULL
        CONSTRAINT FK_Dispensacion_Atencion REFERENCES dbo.Atencion(AtencionId), -- FK: Toda dispensación debe estar atada a una atención médica
    StockVacunaId INT NOT NULL
        CONSTRAINT FK_Dispensacion_Stock REFERENCES dbo.StockVacuna(StockVacunaId), -- FK: Apunta al lote de stock exacto
    Dosis INT NOT NULL
        CONSTRAINT CK_Dispensacion_Dosis CHECK (Dosis > 0), -- CK: No se puede aplicar 0 o dosis negativas
    FechaDispensacion DATETIME2 NOT NULL
        CONSTRAINT DF_Dispensacion_Fecha DEFAULT (SYSDATETIME()), -- DEFAULT: Sella la hora exacta automáticamente
    UsuarioBD NVARCHAR(128) NOT NULL
        CONSTRAINT DF_Dispensacion_Usuario DEFAULT (SUSER_SNAME()) -- DEFAULT: Captura el usuario de Windows automáticamente para auditoría
);
GO

-- 3. Tabla de Alertas (Secundaria)
-- CONCEPTO: Registro de eventos anómalos (stock bajo). No tiene FK a propósito para sobrevivir si se borra el stock original.
CREATE TABLE dbo.AlertaStock(
    AlertaStockId INT IDENTITY(1,1)
        CONSTRAINT PK_AlertaStock PRIMARY KEY,
    StockVacunaId INT NOT NULL,
    StockRestante INT NOT NULL,
    FechaAlerta DATETIME2 NOT NULL
        CONSTRAINT DF_AlertaStock_Fecha DEFAULT (SYSDATETIME())
);
GO

-- 4. Datos sintéticos iniciales
INSERT INTO dbo.StockVacuna (EstablecimientoId, Vacuna, Stock, StockMinimo)
VALUES (1, 'INFLUENZA', 5, 3),
       (1, 'HEPATITIS B', 1, 2),
       (2, 'INFLUENZA', 10, 3);
GO

-- Verificación
SELECT StockVacunaId, EstablecimientoId, Vacuna, Stock, StockMinimo
FROM dbo.StockVacuna ORDER BY StockVacunaId;
GO


/* ======================================================================
   EJERCICIO 01 - BLOQUE 2: PROCEDIMIENTO ALMACENADO CON TRANSACCIÓN
   ====================================================================== */
USE BDDataSaludTema01;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DispensarVacuna
    @PacienteId INT,
    @EstablecimientoId INT,
    @Vacuna VARCHAR(30),
    @Dosis INT = 1,
    @SimularFalloAlerta BIT = 0 -- Parámetro de prueba para forzar el fallo en la alerta
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StockVacunaId INT, @StockMinimo INT, @StockRestante INT,
            @AtencionId INT, @Clasificacion VARCHAR(20), @Mensaje VARCHAR(300);

    -- 1) Validaciones previas
    -- CONCEPTO: Validar antes de abrir la transacción. Las transacciones bloquean recursos, así que deben durar lo mínimo posible.
    IF @Dosis IS NULL OR @Dosis <= 0
    BEGIN
        ;THROW 56003, 'La cantidad de dosis debe ser mayor que cero.', 1; -- THROW: Lanza un error personalizado y detiene la ejecución
    END;

    SELECT @StockVacunaId = StockVacunaId, @StockMinimo = StockMinimo
    FROM dbo.StockVacuna
    WHERE EstablecimientoId = @EstablecimientoId AND Vacuna = @Vacuna;

    IF @StockVacunaId IS NULL
    BEGIN
        ;THROW 56002, 'La vacuna no esta registrada en el establecimiento indicado.', 1;
    END;

    -- CONCEPTO: TRY/CATCH captura errores para poder hacer ROLLBACK y no dejar la base de datos inconsistente.
    BEGIN TRY
        BEGIN TRANSACTION; -- Inicia la transacción (Bloquea y asegura atomicidad)

        -- 2) Descontar stock
        -- CONCEPTO: El "AND Stock >= @Dosis" evita condiciones de carrera. Si dos usuarios compran a la vez, la base de datos evalúa esto en milisegundos y solo deja pasar si hay stock real.
        UPDATE dbo.StockVacuna
        SET Stock = Stock - @Dosis
        WHERE StockVacunaId = @StockVacunaId
          AND Stock >= @Dosis; 

        -- CONCEPTO: @@ROWCOUNT devuelve las filas afectadas por el UPDATE. Si es 0, es porque el WHERE no encontró stock suficiente.
        IF @@ROWCOUNT = 0
        BEGIN
            ;THROW 56001, 'Stock insuficiente: la vacunacion no se registro.', 1; -- THROW: Dispara el error y salta al CATCH general
        END;

        -- 3) Registrar la atención
        -- CONCEPTO: Reutiliza el procedimiento del Tema 01 (No reinventes la rueda). Si el paciente está inactivo, esto fallará y saltará al CATCH.
        EXEC dbo.usp_RegistrarAtencion
            @PacienteId = @PacienteId, @EstablecimientoId = @EstablecimientoId,
            @TipoAtencion = 'VACUNACION', @DuracionMinutos = 10,
            @AtencionId = @AtencionId OUTPUT, @Clasificacion = @Clasificacion OUTPUT,
            @Mensaje = @Mensaje OUTPUT;

        -- 4) Registrar la dispensación
        INSERT INTO dbo.DispensacionVacuna (AtencionId, StockVacunaId, Dosis)
        VALUES (@AtencionId, @StockVacunaId, @Dosis);

        SELECT @StockRestante = Stock FROM dbo.StockVacuna WHERE StockVacunaId = @StockVacunaId;

        -- 5) Alerta de stock bajo protegida
        -- CONCEPTO: SAVEPOINT crea un "checkpoint" dentro de la transacción. Si algo falla después de aquí, no volvemos al inicio, solo volvemos a este punto.
        SAVE TRANSACTION AntesDeAlerta;
        BEGIN TRY
            IF @SimularFalloAlerta = 1
            BEGIN
                ;THROW 56004, 'Fallo simulado al registrar la alerta de stock.', 1;
            END;

            IF @StockRestante < @StockMinimo
            BEGIN
                INSERT INTO dbo.AlertaStock (StockVacunaId, StockRestante)
                VALUES (@StockVacunaId, @StockRestante);
            END;
        END TRY
        BEGIN CATCH
            -- CONCEPTO: XACT_STATE() = 1 significa que la transacción está "sana" y abierta, por lo que podemos hacer un ROLLBACK PARCIAL (al SAVEPOINT).
            IF XACT_STATE() = 1
            BEGIN
                ROLLBACK TRANSACTION AntesDeAlerta; -- Deshace SOLO la alerta fallida, mantiene el descuento de stock y la atención.
                PRINT 'No se pudo registrar la alerta; la vacunacion se mantiene.';
            END
            ELSE
            BEGIN
                ;THROW; -- Si la transacción está condenada (XACT_STATE = -1), relanza el error al CATCH principal.
            END;
        END CATCH;

        -- CONCEPTO: COMMIT confirma y guarda todos los cambios de forma permanente en el disco.
        COMMIT TRANSACTION;

        SELECT @AtencionId AS AtencionId, @StockRestante AS StockRestante,
               'Vacunacion registrada.' AS Resultado;
    END TRY
    BEGIN CATCH
        -- CONCEPTO: Si cualquier cosa falla en el proceso principal, verificamos si hay transacción abierta y la deshacemos por completo.
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION; -- Deshace TODO (stock y atenciones) para que no queden datos huérfanos.
        END;
        ;THROW; -- Relanza el error para que SSMS muestre la alerta roja y el programador sepa qué pasó.
    END CATCH;
END;
GO


/* ======================================================================
   EJERCICIO 01 - BLOQUE 3: PRUEBAS
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- PRUEBA 1: Vacunación normal
PRINT '--- PRUEBA 1: Vacunación normal ---'; -- PRINT: Imprime texto en la pestaña "Mensajes" de SSMS para guiarnos.
EXEC dbo.usp_DispensarVacuna @PacienteId = 1, @EstablecimientoId = 1,
     @Vacuna = 'INFLUENZA', @Dosis = 1;

SELECT Vacuna, Stock FROM dbo.StockVacuna WHERE EstablecimientoId = 1 ORDER BY Vacuna;
GO

-- PRUEBA 2: Stock insuficiente
PRINT '--- PRUEBA 2: Stock insuficiente ---';
DECLARE @Antes INT = (SELECT COUNT(*) FROM dbo.Atencion); -- Guardamos el conteo previo para comparar después
BEGIN TRY
    EXEC dbo.usp_DispensarVacuna @PacienteId = 1, @EstablecimientoId = 1,
         @Vacuna = 'HEPATITIS B', @Dosis = 2;
END TRY
BEGIN CATCH
    -- CONCEPTO: Capturamos el error para que la prueba no se caiga y podamos ver los datos de interés.
    SELECT ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError,
           @@TRANCOUNT AS TransaccionesAbiertas; -- @@TRANCOUNT debe ser 0 para confirmar que el ROLLBACK limpió todo.
END CATCH;

SELECT Stock AS StockHepatitisB
FROM dbo.StockVacuna WHERE EstablecimientoId = 1 AND Vacuna = 'HEPATITIS B';

-- CONCEPTO: Restamos el conteo actual menos el anterior. Si es 0, la transacción no insertó atenciones "fantasma".
SELECT COUNT(*) - @Antes AS AtencionesNuevas FROM dbo.Atencion; 
GO

-- PRUEBA 3: Paciente inactivo
PRINT '--- PRUEBA 3: Paciente inactivo ---';
BEGIN TRY
    EXEC dbo.usp_DispensarVacuna @PacienteId = 3, @EstablecimientoId = 1,
         @Vacuna = 'INFLUENZA', @Dosis = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError,
           @@TRANCOUNT AS TransaccionesAbiertas;
END CATCH;

SELECT Stock AS StockInfluenza
FROM dbo.StockVacuna WHERE EstablecimientoId = 1 AND Vacuna = 'INFLUENZA';
GO

-- PRUEBA 4a: Alerta de stock bajo
PRINT '--- PRUEBA 4a: Alerta de stock bajo ---';
EXEC dbo.usp_DispensarVacuna @PacienteId = 2, @EstablecimientoId = 1,
     @Vacuna = 'INFLUENZA', @Dosis = 2;
GO

-- PRUEBA 4b: Fallo simulado en alerta (Usando SAVEPOINT)
PRINT '--- PRUEBA 4b: Fallo simulado en alerta ---';
EXEC dbo.usp_DispensarVacuna @PacienteId = 2, @EstablecimientoId = 1,
     @Vacuna = 'INFLUENZA', @Dosis = 1, @SimularFalloAlerta = 1;
GO

-- Verificación final
SELECT Vacuna, Stock FROM dbo.StockVacuna WHERE EstablecimientoId = 1 ORDER BY Vacuna;
SELECT AlertaStockId, StockVacunaId, StockRestante FROM dbo.AlertaStock ORDER BY AlertaStockId;
SELECT COUNT(*) AS Dispensaciones FROM dbo.DispensacionVacuna;
GO


