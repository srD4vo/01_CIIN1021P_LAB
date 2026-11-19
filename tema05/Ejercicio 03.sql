/* ======================================================================================
   PROYECTO: DataSalud Perú (DIRESA La Libertad)
   TEMA 05 - EJERCICIO 03: ETL EN SSIS (EXTRAER, LIMPIAR Y CLASIFICAR)
   DESCRIPCIÓN: Script de verificación en SQL Server (SSMS). 
                Este script no realiza el ETL (eso se hace en Visual Studio), 
                sino que comprueba que el paquete SSIS extrajo y transformó los datos correctamente.
   ====================================================================================== */

USE BDDataSaludTema05;
GO

/* --------------------------------------------------------------------------------------
   PARTE 1: VERIFICACIÓN DEL ENTORNO
   Comprobamos la versión de SQL Server instalada para asegurar compatibilidad.
   -------------------------------------------------------------------------------------- */
PRINT '--- 1. Verificación del Entorno SQL Server ---';

SELECT 
    @@VERSION AS VersionCompleta,
    SERVERPROPERTY('ProductMajorVersion') AS VersionMayor,
    SERVERPROPERTY('ProductLevel') AS Nivel,
    SERVERPROPERTY('Edition') AS Edicion;
GO

/* --------------------------------------------------------------------------------------
   PARTE 2: VERIFICACIÓN DE LA EXTRACCIÓN (Paso 4 del E03)
   Se ejecuta después de correr la tarea DFT_E03_ExtraerAStaging en Visual Studio.
   Objetivo: Comprobar que los 8 registros (4 HIS + 4 Campania) llegaron a staging.
   -------------------------------------------------------------------------------------- */
PRINT '--- 2. Verificación de la Extracción a Staging ---';

-- 2.1. Conteo de registros por sistema de origen
SELECT Origen, COUNT(*) AS Registros
FROM stg.Atencion
GROUP BY Origen;

-- 2.2. Vista previa de los datos "sucios" originales (se deben ver los espacios, nulos, etc.)
SELECT * FROM stg.Atencion ORDER BY Origen, CodigoAtencion;
GO

/* --------------------------------------------------------------------------------------
   PARTE 3: RECONCILIACIÓN Y VERIFICACIÓN FINAL (Paso 7 del E03)
   Se ejecuta después de correr la tarea DFT_E03_TransformarClasificar en Visual Studio.
   Objetivo: Validar que la división condicional separó correctamente los datos.
   -------------------------------------------------------------------------------------- */
PRINT '--- 3. Reconciliación y Verificación Final ---';

-- 3.1. Reconciliación de conteos (Staging = Válidas + Rechazadas)
SELECT 'Staging' AS Conjunto, COUNT(*) AS Cantidad FROM stg.Atencion
UNION ALL SELECT 'Validas', COUNT(*) FROM stg.AtencionValida
UNION ALL SELECT 'Rechazadas', COUNT(*) FROM stg.AtencionRechazada;

-- 3.2. Total de minutos válidos (El resultado esperado es 53)
SELECT SUM(DuracionMinutos) AS MinutosValidos FROM stg.AtencionValida;

-- 3.3. Detalle de los válidos (Deben estar limpios: sin espacios, en mayúsculas)
SELECT Origen, CodigoAtencion, CodigoEstablecimiento, TipoAtencion, EstadoRegistro
FROM stg.AtencionValida ORDER BY Origen, CodigoAtencion;

-- 3.4. Detalle de los rechazados (Deben conservar el valor original y mostrar su motivo)
SELECT Origen, CodigoAtencion, MotivoRechazo
FROM stg.AtencionRechazada ORDER BY Origen, CodigoAtencion;
GO