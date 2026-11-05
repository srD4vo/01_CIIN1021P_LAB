/* ======================================================================
   EJERCICIO 02 - BLOQUE 1: LIMPIEZA, LOGINS Y USUARIOS
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- 1. LIMPIEZA (Paso 0)
-- CONCEPTO: Primero se borran los usuarios y roles de la BD, luego los logins del servidor.
DROP USER IF EXISTS usuario_analista;
DROP USER IF EXISTS usuario_auditor;
DROP USER IF EXISTS usuario_administrador;
DROP ROLE IF EXISTS rol_lectura_general;
DROP ROLE IF EXISTS rol_analista;
DROP ROLE IF EXISTS rol_auditor;
DROP ROLE IF EXISTS rol_administrador;
GO

IF SUSER_ID('login_analista') IS NOT NULL DROP LOGIN login_analista;
IF SUSER_ID('login_auditor') IS NOT NULL DROP LOGIN login_auditor;
IF SUSER_ID('login_administrador') IS NOT NULL DROP LOGIN login_administrador;
GO

-- 2. CREAR LOGINS (Paso 1)
-- CONCEPTO: El LOGIN es a nivel de servidor (la llave para entrar a la instancia de SQL Server).
-- CHECK_POLICY = ON obliga a que la contraseña cumpla reglas de seguridad (mayúsculas, números, etc.).
CREATE LOGIN login_analista WITH PASSWORD = 'DataSalud#Analista26', CHECK_POLICY = ON;
CREATE LOGIN login_auditor WITH PASSWORD = 'DataSalud#Auditor26', CHECK_POLICY = ON;
CREATE LOGIN login_administrador WITH PASSWORD = 'DataSalud#Admin2026', CHECK_POLICY = ON;
GO

-- 3. CREAR USUARIOS (Paso 1)
-- CONCEPTO: El USER es a nivel de base de datos. Le dice a SQL Server "este login puede entrar a ESTA base de datos".
CREATE USER usuario_analista FOR LOGIN login_analista;
CREATE USER usuario_auditor FOR LOGIN login_auditor;
CREATE USER usuario_administrador FOR LOGIN login_administrador;
GO

-- Verificación
SELECT name AS LoginServidor, type_desc FROM sys.server_principals
WHERE name LIKE 'login[_]%' ORDER BY name;

SELECT name AS UsuarioBase, type_desc FROM sys.database_principals
WHERE name LIKE 'usuario[_]%' ORDER BY name;
GO

/* ======================================================================
   EJERCICIO 02 - BLOQUE 2: ROLES Y PERMISOS
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- 1. CREAR ROLES (Paso 2)
-- CONCEPTO: Un rol es un "cargo" o "perfil". En lugar de dar permisos a cada persona, se los das al rol y luego metes a la persona en el rol.
-- TODO 1 RESUELTO:
CREATE ROLE rol_analista;
CREATE ROLE rol_auditor;
CREATE ROLE rol_administrador;
GO

-- 2. ASIGNAR USUARIOS A ROLES (Paso 2)
-- CONCEPTO: ADD MEMBER mete al usuario dentro del rol, heredando sus permisos.
-- TODO 2 RESUELTO:
ALTER ROLE rol_analista ADD MEMBER usuario_analista;
ALTER ROLE rol_auditor ADD MEMBER usuario_auditor;
ALTER ROLE rol_administrador ADD MEMBER usuario_administrador;
GO

-- 3. ASIGNAR PERMISOS (Paso 3)
-- CONCEPTO: GRANT otorga el permiso. Siempre es mejor dar el permiso al ROL y no al usuario directamente.

-- Analista: solo puede leer la tabla de atenciones.
GRANT SELECT ON dbo.Atencion TO rol_analista;

-- Auditor: puede leer atenciones y la auditoría, pero NUNCA modificarlas.
GRANT SELECT ON dbo.Atencion TO rol_auditor;
-- TODO 3 RESUELTO: Permiso de lectura sobre la auditoría.
GRANT SELECT ON dbo.AuditoriaAtencion TO rol_auditor;

-- TODO 4 RESUELTO: DENY explícito. 
-- CONCEPTO: Aunque en el futuro alguien le dé permisos por error, el DENY siempre gana y bloquea el INSERT, UPDATE y DELETE.
DENY INSERT, UPDATE, DELETE ON dbo.Atencion TO rol_auditor;

-- Administrador: tiene control total sobre atenciones, lee auditoría, ve stock y puede dispensar.
-- TODO 5 RESUELTO: Los 4 permisos de mantenimiento juntos.
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Atencion TO rol_administrador;
GRANT SELECT ON dbo.AuditoriaAtencion TO rol_administrador;
GRANT SELECT ON dbo.StockVacuna TO rol_administrador;
-- CONCEPTO: EXECUTE le permite usar el procedimiento, pero NO le da permiso directo de UPDATE sobre la tabla StockVacuna.
GRANT EXECUTE ON dbo.usp_DispensarVacuna TO rol_administrador;
GO

/* ======================================================================
   EJERCICIO 02 - BLOQUE 3: PRUEBAS DE SUPLANTACIÓN (EXECUTE AS)
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- PRUEBA COMO ANALISTA
-- CONCEPTO: EXECUTE AS LOGIN nos convierte temporalmente en ese usuario sin cerrar nuestra sesión.
EXECUTE AS LOGIN = 'login_analista';
SELECT SUSER_SNAME() AS LoginActual, USER_NAME() AS UsuarioActual; -- Confirma que somos el analista

-- Debe funcionar (tiene GRANT SELECT)
SELECT TOP (3) AtencionId, TipoAtencion, DuracionMinutos FROM dbo.Atencion ORDER BY AtencionId;

-- Debe fallar (no tiene DELETE, error 229)
BEGIN TRY
    DELETE FROM dbo.Atencion WHERE AtencionId = -1;
END TRY
BEGIN CATCH
    SELECT 'analista: DELETE' AS Prueba, ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;
REVERT; -- CONCEPTO: REVERT devuelve la identidad a nuestro usuario original (dbo). ¡Siempre usarlo!
GO

-- PRUEBA COMO AUDITOR
EXECUTE AS LOGIN = 'login_auditor';
-- Debe funcionar (tiene GRANT SELECT en AuditoriaAtencion)
SELECT COUNT(*) AS FilasAuditoriaVisibles FROM dbo.AuditoriaAtencion;

-- Debe fallar (tiene DENY UPDATE, error 229)
BEGIN TRY
    UPDATE dbo.Atencion SET DuracionMinutos = 99 WHERE AtencionId = -1;
END TRY
BEGIN CATCH
    SELECT 'auditor: UPDATE' AS Prueba, ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;
REVERT;
GO

-- Verificación final: Debemos haber vuelto a ser nosotros mismos
SELECT SUSER_SNAME() AS DebeSerTuLogin;
GO

/* ======================================================================
   EJERCICIO 02 - BLOQUE 4: PRUEBA DE DENY Y REVOKE
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- 1. Creamos un rol demasiado amplio (da SELECT a TODO el esquema dbo)
CREATE ROLE rol_lectura_general;
GRANT SELECT ON SCHEMA::dbo TO rol_lectura_general;
ALTER ROLE rol_lectura_general ADD MEMBER usuario_analista; -- Metemos al analista aquí
GO

-- Comprobación: El analista ahora SÍ puede leer la auditoría gracias al rol amplio
EXECUTE AS LOGIN = 'login_analista';
SELECT COUNT(*) AS AuditoriaLeidaPorAnalista FROM dbo.AuditoriaAtencion;
REVERT;
GO

-- 2. Aplicamos un DENY explícito al rol_analista
-- CONCEPTO: El DENY es una regla de "veto". Sin importar cuántos GRANT tenga (incluso el del rol amplio), el DENY bloquea el acceso.
DENY SELECT ON dbo.AuditoriaAtencion TO rol_analista;
GO

EXECUTE AS LOGIN = 'login_analista';
BEGIN TRY
    SELECT COUNT(*) AS AuditoriaLeidaPorAnalista FROM dbo.AuditoriaAtencion;
END TRY
BEGIN CATCH
    SELECT 'con DENY' AS Prueba, ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;
REVERT;
GO

-- 3. Aplicamos REVOKE
-- CONCEPTO: REVOKE solo quita la regla que acabamos de poner (el DENY). No quita el GRANT del rol amplio. Por eso vuelve a leer.
REVOKE SELECT ON dbo.AuditoriaAtencion FROM rol_analista;
GO

EXECUTE AS LOGIN = 'login_analista';
SELECT COUNT(*) AS AuditoriaLeidaPorAnalista FROM dbo.AuditoriaAtencion;
REVERT;
GO

-- 4. CIERRE CORRECTO (Mínimo privilegio)
-- Quitamos el rol amplio (que daba demasiado permiso) y dejamos escrito el DENY para que quede la política de seguridad.
ALTER ROLE rol_lectura_general DROP MEMBER usuario_analista;
DROP ROLE rol_lectura_general;
DENY SELECT ON dbo.AuditoriaAtencion TO rol_analista;
GO

/* ======================================================================
   EJERCICIO 02 - BLOQUE 5: PROCEDIMIENTO COMO ÚNICA PUERTA
   ====================================================================== */
USE BDDataSaludTema01;
GO

EXECUTE AS LOGIN = 'login_administrador';

-- 1. Intento de UPDATE directo (Debe fallar con error 229 porque no tiene GRANT UPDATE sobre la tabla)
BEGIN TRY
    UPDATE dbo.StockVacuna SET Stock = Stock + 100 WHERE EstablecimientoId = 2;
END TRY
BEGIN CATCH
    SELECT 'UPDATE directo' AS Intento, ERROR_NUMBER() AS NumeroError, ERROR_MESSAGE() AS MensajeError;
END CATCH;

-- 2. Ejecución del procedimiento (Debe funcionar porque tiene GRANT EXECUTE)
-- CONCEPTO: El procedimiento es la "caja negra". Modifica el stock internamente, pero el administrador no puede hacer trampa cambiando el stock manualmente.
EXEC dbo.usp_DispensarVacuna @PacienteId = 2, @EstablecimientoId = 2,
     @Vacuna = 'INFLUENZA', @Dosis = 1;
REVERT;
GO

-- 3. Trazabilidad: ¿Quién hizo la dispensación?
SELECT TOP (1) DispensacionId, Dosis, UsuarioBD
FROM dbo.DispensacionVacuna ORDER BY DispensacionId DESC;

SELECT TOP (1) AuditoriaId, Operacion, UsuarioBD
FROM dbo.AuditoriaAtencion ORDER BY AuditoriaId DESC;
GO

/* ======================================================================
   EJERCICIO 02 - BLOQUE 6: EVIDENCIA DE PERMISOS
   ====================================================================== */
USE BDDataSaludTema01;
GO

-- CONCEPTO: sys.database_permissions es el diccionario interno de SQL Server donde se guarda quién tiene qué permiso.
SELECT pr.name AS Rol, pe.state_desc AS Estado, pe.permission_name AS Permiso,
       OBJECT_NAME(pe.major_id) AS Objeto, COL_NAME(pe.major_id, pe.minor_id) AS Columna
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr
    ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE 'rol[_]%'
ORDER BY Rol, Objeto, Permiso;
GO

