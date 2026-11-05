/* ======================================================================
   EJERCICIO 05 - RESPALDO Y RECUPERACIÓN (COMPLETO)
   ====================================================================== */

/* ----------------------------------------------------------------------
   [FOTO 1 PARA EL WORD]: BLOQUE 1 - PREPARACIÓN Y RESPALDO FULL
   Captura la creación de la función, la tabla y el mensaje de éxito del FULL.
   ---------------------------------------------------------------------- */
USE BDDataSaludTema01;
GO

-- Función que detecta la ruta de respaldo
CREATE OR ALTER FUNCTION dbo.ufn_RutaRespaldo()
RETURNS NVARCHAR(260)
AS
BEGIN
    DECLARE @Ruta NVARCHAR(260) = CONVERT(NVARCHAR(260),
        COALESCE(SERVERPROPERTY('InstanceDefaultBackupPath'),
                 SERVERPROPERTY('InstanceDefaultDataPath')));
    IF RIGHT(@Ruta, 1) NOT IN ('\', '/')
    BEGIN
        SET @Ruta = @Ruta + N'\';
    END;
    RETURN @Ruta;
END;
GO

-- Tabla para llevar la evidencia de qué datos existían en cada momento
DROP TABLE IF EXISTS dbo.EvidenciaBackupTema03;
CREATE TABLE dbo.EvidenciaBackupTema03(
    EvidenciaId INT IDENTITY(1,1) CONSTRAINT PK_EvidenciaBackupTema03 PRIMARY KEY,
    Descripcion VARCHAR(100) NOT NULL,
    FechaRegistro DATETIME2 NOT NULL CONSTRAINT DF_EvidenciaBackup_Fecha DEFAULT (SYSDATETIME())
);
INSERT INTO dbo.EvidenciaBackupTema03 (Descripcion) VALUES ('1. Antes del FULL');
GO

-- Respaldo COMPLETO (FULL)
DECLARE @ArchivoFull NVARCHAR(400) = dbo.ufn_RutaRespaldo() + N'BDDataSaludTema03_FULL.bak';
BACKUP DATABASE BDDataSaludTema01
TO DISK = @ArchivoFull
WITH INIT, CHECKSUM, NAME = N'DataSalud Tema 03 - FULL', STATS = 25;
SELECT @ArchivoFull AS ArchivoGenerado;
GO

-- Insertamos un dato DESPUÉS del FULL
INSERT INTO dbo.EvidenciaBackupTema03 (Descripcion) VALUES ('2. Despues del FULL');
GO


/* ----------------------------------------------------------------------
   [FOTO 2 PARA EL WORD]: BLOQUE 2 - RESPALDO DIFERENCIAL Y VERIFICACIÓN
   Captura el mensaje de éxito del DIFF, el VERIFYONLY y el historial de msdb.
   ---------------------------------------------------------------------- */
-- Respaldo DIFERENCIAL
DECLARE @ArchivoDiff NVARCHAR(400) = dbo.ufn_RutaRespaldo() + N'BDDataSaludTema03_DIFF.bak';
BACKUP DATABASE BDDataSaludTema01
TO DISK = @ArchivoDiff
WITH DIFFERENTIAL, INIT, CHECKSUM, NAME = N'DataSalud Tema 03 - DIFF', STATS = 25;
SELECT @ArchivoDiff AS ArchivoGenerado;
GO

-- Insertamos un dato DESPUÉS del DIFF (Este ya NO se respaldará en los archivos anteriores)
INSERT INTO dbo.EvidenciaBackupTema03 (Descripcion) VALUES ('3. Despues del DIFF');
GO

-- Verificar la integridad de los respaldos (VERIFYONLY)
DECLARE @ArchivoFull NVARCHAR(400) = dbo.ufn_RutaRespaldo() + N'BDDataSaludTema03_FULL.bak';
DECLARE @ArchivoDiff NVARCHAR(400) = dbo.ufn_RutaRespaldo() + N'BDDataSaludTema03_DIFF.bak';
RESTORE VERIFYONLY FROM DISK = @ArchivoFull WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = @ArchivoDiff WITH CHECKSUM;
GO

-- Ver el historial de respaldos en msdb
SELECT TOP (4) bs.name AS Respaldo,
       CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFFERENTIAL'
                    WHEN 'L' THEN 'LOG' END AS Tipo,
       bs.backup_finish_date AS Fin, mf.physical_device_name AS Archivo
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf ON mf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'BDDataSaludTema01'
ORDER BY bs.backup_finish_date DESC;
GO


/* ----------------------------------------------------------------------
   [FOTO 3 PARA EL WORD]: BLOQUE 3 - RESTAURACIÓN REAL (SIMULACRO DE DESASTRE)
   Captura los mensajes de éxito de las restauraciones (NORECOVERY y RECOVERY).
   ---------------------------------------------------------------------- */
USE master;
GO

-- Limpieza de restauración anterior
IF DB_ID('BDDataSaludTema03_Restore') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX('BDDataSaludTema03_Restore', 'Status') = 'ONLINE'
    BEGIN
        ALTER DATABASE BDDataSaludTema03_Restore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END;
    DROP DATABASE BDDataSaludTema03_Restore;
END;
GO

-- Preparar variables de rutas
DECLARE @Ruta NVARCHAR(260) = BDDataSaludTema01.dbo.ufn_RutaRespaldo();
DECLARE @ArchivoFull NVARCHAR(400) = @Ruta + N'BDDataSaludTema03_FULL.bak';
DECLARE @ArchivoDiff NVARCHAR(400) = @Ruta + N'BDDataSaludTema03_DIFF.bak';
DECLARE @RutaDatos NVARCHAR(260) = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultDataPath'));
IF RIGHT(@RutaDatos, 1) NOT IN ('\', '/') SET @RutaDatos = @RutaDatos + N'\';
DECLARE @Mdf NVARCHAR(400) = @RutaDatos + N'BDDataSaludTema03_Restore.mdf';
DECLARE @Ldf NVARCHAR(400) = @RutaDatos + N'BDDataSaludTema03_Restore_log.ldf';
DECLARE @LogicoDatos SYSNAME, @LogicoLog SYSNAME;

SELECT @LogicoDatos = name FROM BDDataSaludTema01.sys.database_files WHERE type_desc = 'ROWS';
SELECT @LogicoLog = name FROM BDDataSaludTema01.sys.database_files WHERE type_desc = 'LOG';

-- Restaurar el FULL (dejando la base inaccesible con NORECOVERY)
RESTORE DATABASE BDDataSaludTema03_Restore
FROM DISK = @ArchivoFull
WITH MOVE @LogicoDatos TO @Mdf, MOVE @LogicoLog TO @Ldf, NORECOVERY, STATS = 25;

-- Restaurar el DIFF (dejando la base lista con RECOVERY)
RESTORE DATABASE BDDataSaludTema03_Restore
FROM DISK = @ArchivoDiff
WITH RECOVERY, STATS = 25;
GO


/* ----------------------------------------------------------------------
   [FOTO 4 PARA EL WORD]: BLOQUE 4 - COMPARACIÓN DE DATOS RESTAURADOS
   Captura la tabla final comparando las filas de la original vs la restaurada.
   ---------------------------------------------------------------------- */
-- La original tiene 3 filas (1, 2 y 3). La restaurada solo tendrá 2 (1 y 2).
SELECT 'Original' AS Base, EvidenciaId, Descripcion
FROM BDDataSaludTema01.dbo.EvidenciaBackupTema03
UNION ALL
SELECT 'Restaurada', EvidenciaId, Descripcion
FROM BDDataSaludTema03_Restore.dbo.EvidenciaBackupTema03
ORDER BY Base, EvidenciaId;
GO


/* ----------------------------------------------------------------------
   [FOTO 5 PARA EL WORD]: BLOQUE 5 - PROCEDIMIENTO DE RESPALDO PROGRAMADO (PASO 6)
   Captura la creación del procedimiento y los resultados de las 3 pruebas.
   ---------------------------------------------------------------------- */
USE BDDataSaludTema01;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RespaldoProgramado
    @TipoForzado VARCHAR(4) = NULL      -- 'FULL', 'DIFF' o NULL (decide segun el dia)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Tipo VARCHAR(4) = @TipoForzado, @Archivo NVARCHAR(400);

    -- Si no se fuerza, evalúa el día (Domingos = FULL, resto = DIFF)
    IF @Tipo IS NULL
    BEGIN
        SET @Tipo = CASE WHEN DATEDIFF(DAY, '19000107', SYSDATETIME()) % 7 = 0
                         THEN 'FULL' ELSE 'DIFF' END;
    END;

    -- Validación de seguridad
    IF @Tipo NOT IN ('FULL', 'DIFF')
    BEGIN
        ;THROW 58001, 'Tipo de respaldo no valido. Use FULL o DIFF.', 1;
    END;

    -- Nombre del archivo dinámico con la fecha
    SET @Archivo = dbo.ufn_RutaRespaldo() + N'BDDataSalud_' + @Tipo + N'_'
                 + CONVERT(NCHAR(8), SYSDATETIME(), 112) + N'.bak';

    -- Ejecuta el respaldo según el tipo
    IF @Tipo = 'FULL'
    BEGIN
        BACKUP DATABASE BDDataSaludTema01 TO DISK = @Archivo WITH INIT, CHECKSUM;
    END
    ELSE
    BEGIN
        BACKUP DATABASE BDDataSaludTema01 TO DISK = @Archivo WITH DIFFERENTIAL, INIT, CHECKSUM;
    END;

    SELECT @Tipo AS TipoRespaldo, @Archivo AS Archivo;
END;
GO

-- PRUEBA 1: Ejecución normal (decide según el día de hoy)
EXEC dbo.usp_RespaldoProgramado;                        

-- PRUEBA 2: Forzar un FULL
EXEC dbo.usp_RespaldoProgramado @TipoForzado = 'FULL';

-- PRUEBA 3: Forzar un tipo inválido para probar el THROW 58001
BEGIN TRY
    EXEC dbo.usp_RespaldoProgramado @TipoForzado = 'LOG';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;
GO