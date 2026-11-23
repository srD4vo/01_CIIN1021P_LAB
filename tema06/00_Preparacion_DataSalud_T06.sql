-- CIIN1021P | TEMA 06 | PREPARACION (ESTUDIANTE Y DOCENTE)
-- Ejecutar completo en SSMS (F5), conectado al Motor de base de datos.
-- SQL Server 2016 SP1 o posterior. Crea BDDataSaludTema06 con el estado final
-- del Tema 05 (estrella de atenciones y de vacunacion, log y staging) y agrega:
--   * tres establecimientos de otras provincias (Ascope, Viru, Pacasmayo);
--   * un lote historico de 2000 atenciones y 600 dosis generadas con formulas;
--   * dw.MetaCobertura: poblacion objetivo y meta anual por provincia.
-- Las 12 atenciones y 7 dosis del Tema 05 se conservan como datos de control.
-- Datos sinteticos: no hay pacientes, documentos ni establecimientos reales.
-- No duplica la carga si se ejecuta otra vez.

USE master;
GO
-- Borrar la base de datos si ya existe para crearla limpia con las correcciones
IF DB_ID(N'BDDataSaludTema06') IS NOT NULL
BEGIN
    ALTER DATABASE BDDataSaludTema06 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BDDataSaludTema06;
END
GO
CREATE DATABASE BDDataSaludTema06;
GO
USE BDDataSaludTema06;
GO
SET NOCOUNT ON;
IF SCHEMA_ID(N'ope') IS NULL EXEC(N'CREATE SCHEMA ope');
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dw')  IS NULL EXEC(N'CREATE SCHEMA dw');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
GO

/* ---------- 1. Maestro operacional de establecimientos (8) ---------- */
CREATE TABLE ope.Establecimiento (
    EstablecimientoId     INT         NOT NULL CONSTRAINT PK_ope_Establecimiento PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(10) NOT NULL CONSTRAINT UQ_ope_Establecimiento_Codigo UNIQUE,
    Nombre                VARCHAR(60) NOT NULL,
    Categoria             VARCHAR(5)  NOT NULL,
    Ubigeo                CHAR(6)     NOT NULL,
    Provincia             VARCHAR(40) NOT NULL,
    Distrito              VARCHAR(40) NOT NULL
);
INSERT ope.Establecimiento
SELECT s.* FROM (VALUES
 (1,'EST-001','Centro simulado Trujillo',         'I-3','130101','TRUJILLO','TRUJILLO'),
 (2,'EST-002','Centro simulado Chepen',           'I-4','130401','CHEPEN','CHEPEN'),
 (3,'EST-003','Puesto simulado Huamachuco',       'I-2','130901','SANCHEZ CARRION','HUAMACHUCO'),
 (4,'EST-004','Centro simulado La Esperanza',     'I-3','130105','TRUJILLO','LA ESPERANZA'),
 (5,'EST-005','Puesto simulado El Porvenir',      'I-1','130102','TRUJILLO','EL PORVENIR'),
 (6,'EST-006','Puesto simulado Ascope',           'I-2','130201','ASCOPE','ASCOPE'),
 (7,'EST-007','Centro simulado Viru',             'I-3','131201','VIRU','VIRU'),
 (8,'EST-008','Puesto simulado San Pedro de Lloc','I-1','130701','PACASMAYO','SAN PEDRO DE LLOC')
) AS s(Id,Codigo,Nombre,Categoria,Ubigeo,Provincia,Distrito);
GO

/* ---------- 2. Dimensiones (estado final del Tema 05) ---------- */
CREATE TABLE dw.DimFecha (
    FechaKey INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
    Fecha DATE NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
    Anio SMALLINT NOT NULL, Semestre TINYINT NOT NULL, Trimestre TINYINT NOT NULL,
    Mes TINYINT NOT NULL, NombreMes VARCHAR(10) NOT NULL, Dia TINYINT NOT NULL
);
CREATE TABLE dw.DimEstablecimiento (
    EstablecimientoKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEstablecimiento PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(10) NOT NULL CONSTRAINT UQ_DimEstablecimiento_Codigo UNIQUE,
    Nombre VARCHAR(60) NOT NULL, Categoria VARCHAR(5) NOT NULL, Ubigeo CHAR(6) NOT NULL,
    Provincia VARCHAR(40) NOT NULL, Distrito VARCHAR(40) NOT NULL
);
CREATE TABLE dw.DimTipoAtencion (
    TipoAtencionKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimTipoAtencion PRIMARY KEY,
    TipoAtencion VARCHAR(20) NOT NULL CONSTRAINT UQ_DimTipoAtencion_Tipo UNIQUE
);
-- CORRECCIÓN: EdadMin de NINO empieza en 1 para evitar clave duplicada con NO REGISTRADO (NULL)
CREATE TABLE dw.DimGrupoEtario (
    GrupoEtarioKey INT NOT NULL CONSTRAINT PK_DimGrupoEtario PRIMARY KEY,
    EtapaVida VARCHAR(20) NOT NULL CONSTRAINT UQ_DimGrupoEtario_Etapa UNIQUE,
    EdadMin TINYINT NULL, EdadMax TINYINT NULL
);
CREATE TABLE dw.DimVacuna (
    VacunaKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimVacuna PRIMARY KEY,
    Vacuna VARCHAR(20) NOT NULL CONSTRAINT UQ_DimVacuna_Vacuna UNIQUE
);
GO
WITH Digito AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)),
Numero AS (SELECT a.n * 100 + b.n * 10 + c.n AS n FROM Digito a CROSS JOIN Digito b CROSS JOIN Digito c),
Calendario AS (SELECT DATEADD(DAY, n, CONVERT(DATE, '20260101')) AS Fecha FROM Numero WHERE n < 365)
INSERT INTO dw.DimFecha
SELECT YEAR(Fecha) * 10000 + MONTH(Fecha) * 100 + DAY(Fecha), Fecha, YEAR(Fecha),
       CASE WHEN MONTH(Fecha) <= 6 THEN 1 ELSE 2 END, DATEPART(QUARTER, Fecha), MONTH(Fecha),
       CHOOSE(MONTH(Fecha), 'ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO',
              'JULIO','AGOSTO','SETIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'), DAY(Fecha)
FROM Calendario c;

INSERT INTO dw.DimEstablecimiento (CodigoEstablecimiento, Nombre, Categoria, Ubigeo, Provincia, Distrito)
SELECT e.CodigoEstablecimiento, e.Nombre, e.Categoria, e.Ubigeo, e.Provincia, e.Distrito
FROM ope.Establecimiento e ORDER BY e.EstablecimientoId;

INSERT INTO dw.DimTipoAtencion (TipoAtencion)
SELECT s.Tipo FROM (VALUES ('CONSULTA'),('CONTROL'),('VACUNACION'),('LABORATORIO')) AS s(Tipo);

-- CORRECCIÓN: NINO empieza en 1 en lugar de 0
INSERT INTO dw.DimGrupoEtario
SELECT s.* FROM (VALUES (0,'NO REGISTRADO',NULL,NULL),(1,'NINO',1,11),(2,'ADOLESCENTE',12,17),
                        (3,'JOVEN',18,29),(4,'ADULTO',30,59),(5,'ADULTO MAYOR',60,150)) AS s(K,E,Mi,Ma);

INSERT INTO dw.DimVacuna (Vacuna) SELECT 'SIM-V';
GO

/* ---------- 3. Log de ejecuciones (Tema 05) y lote historico ---------- */
CREATE TABLE etl.EjecucionCarga (
    EjecucionId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EjecucionCarga PRIMARY KEY,
    Proceso VARCHAR(40) NOT NULL,
    Inicio DATETIME2(0) NOT NULL CONSTRAINT DF_EjecucionCarga_Inicio DEFAULT (SYSDATETIME()),
    Fin DATETIME2(0) NULL, Estado VARCHAR(10) NOT NULL,
    FilasStaging INT NULL, FilasValidas INT NULL, FilasRechazadas INT NULL, FilasInsertadas INT NULL,
    Mensaje NVARCHAR(4000) NULL
);
SET IDENTITY_INSERT etl.EjecucionCarga ON;
INSERT etl.EjecucionCarga (EjecucionId, Proceso, Inicio, Fin, Estado, FilasStaging, FilasValidas, FilasRechazadas, FilasInsertadas, Mensaje)
VALUES (1,'CARGA_DW_ATENCION','20261105 09:00','20261105 09:00','OK',8,4,4,4,NULL),
       (2,'CARGA_DW_ATENCION','20261105 09:05','20261105 09:05','OK',8,4,4,0,NULL),
       (3,'CARGA_DW_ATENCION','20261105 09:20','20261105 09:20','OK',8,4,4,0,NULL),
       (4,'CARGA_DW_ATENCION','20261105 09:40','20261105 09:40','OK',10,6,4,2,NULL),
       (5,'CARGA_HISTORICA_T06','20261110 08:00','20261110 08:02','OK',NULL,NULL,NULL,2000,
          N'Lote historico enero-noviembre 2026, recibido ya anonimizado (con grupo etario).');
SET IDENTITY_INSERT etl.EjecucionCarga OFF;
GO

/* ---------- 4. Hechos ---------- */
CREATE TABLE dw.FactAtencion (
    Origen VARCHAR(10) NOT NULL,
    CodigoAtencion VARCHAR(10) NOT NULL,
    FechaKey INT NOT NULL CONSTRAINT FK_FactAtencion_Fecha REFERENCES dw.DimFecha (FechaKey),
    EstablecimientoKey INT NOT NULL CONSTRAINT FK_FactAtencion_Establecimiento REFERENCES dw.DimEstablecimiento (EstablecimientoKey),
    TipoAtencionKey INT NOT NULL CONSTRAINT FK_FactAtencion_Tipo REFERENCES dw.DimTipoAtencion (TipoAtencionKey),
    DuracionMinutos INT NOT NULL CONSTRAINT CK_FactAtencion_Duracion CHECK (DuracionMinutos > 0),
    EjecucionId INT NULL CONSTRAINT FK_FactAtencion_Ejecucion REFERENCES etl.EjecucionCarga (EjecucionId),
    GrupoEtarioKey INT NOT NULL CONSTRAINT DF_FactAtencion_GrupoEtario DEFAULT (0)
                   CONSTRAINT FK_FactAtencion_GrupoEtario REFERENCES dw.DimGrupoEtario (GrupoEtarioKey),
    CONSTRAINT PK_FactAtencion PRIMARY KEY (Origen, CodigoAtencion)
);
CREATE TABLE dw.FactVacunacion (
    CodigoDosis VARCHAR(10) NOT NULL CONSTRAINT PK_FactVacunacion PRIMARY KEY,
    FechaKey INT NOT NULL CONSTRAINT FK_FactVacunacion_Fecha REFERENCES dw.DimFecha (FechaKey),
    EstablecimientoKey INT NOT NULL CONSTRAINT FK_FactVacunacion_Establecimiento REFERENCES dw.DimEstablecimiento (EstablecimientoKey),
    GrupoEtarioKey INT NOT NULL CONSTRAINT FK_FactVacunacion_GrupoEtario REFERENCES dw.DimGrupoEtario (GrupoEtarioKey),
    VacunaKey INT NOT NULL CONSTRAINT FK_FactVacunacion_Vacuna REFERENCES dw.DimVacuna (VacunaKey),
    NumeroDosis TINYINT NOT NULL
);
GO

-- 4.1 Las 12 atenciones de control del Tema 05
INSERT INTO dw.FactAtencion
    (Origen, CodigoAtencion, FechaKey, EstablecimientoKey, TipoAtencionKey, DuracionMinutos, EjecucionId, GrupoEtarioKey)
SELECT s.Origen, s.Codigo, f.FechaKey, e.EstablecimientoKey, t.TipoAtencionKey, s.Minutos, s.Ejecucion, s.Grupo
FROM (VALUES
 ('NUCLEO','1101','20261001','EST-001','CONSULTA',20,NULL,4), ('NUCLEO','1102','20261002','EST-002','CONTROL',15,NULL,5),
 ('NUCLEO','1103','20261003','EST-001','VACUNACION',10,NULL,1), ('NUCLEO','1105','20261005','EST-002','CONSULTA',25,NULL,3),
 ('NUCLEO','1106','20261006','EST-003','CONTROL',18,NULL,2), ('NUCLEO','1107','20261007','EST-001','VACUNACION',12,NULL,1),
 ('HIS','HIS-001','20260615','EST-001','CONSULTA',22,1,4), ('HIS','HIS-002','20260916','EST-002','VACUNACION',9,1,1),
 ('CAMPANIA','CAM-001','20260920','EST-001','VACUNACION',8,1,1), ('CAMPANIA','CAM-002','20260920','EST-002','CONTROL',14,1,0),
 ('HIS','HIS-005','20261102','EST-004','LABORATORIO',30,4,4), ('CAMPANIA','CAM-005','20261103','EST-005','VACUNACION',7,4,1)
) AS s(Origen,Codigo,Fecha,Est,Tipo,Minutos,Ejecucion,Grupo)
INNER JOIN dw.DimFecha f ON f.Fecha = s.Fecha
INNER JOIN dw.DimEstablecimiento e ON e.CodigoEstablecimiento = s.Est
INNER JOIN dw.DimTipoAtencion t ON t.TipoAtencion = s.Tipo;

-- 4.2 Lote historico: 2000 atenciones
WITH Digito AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)),
Numero AS (
    SELECT TOP (2000) CONVERT(INT, ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) AS n
    FROM Digito a CROSS JOIN Digito b CROSS JOIN Digito c CROSS JOIN Digito d
),
Base AS (
    SELECT n,
           CHOOSE(n % 13 + 1, 1,1,1,4,4,5,2,2,3,6,7,8,1)     AS Est,
           n % 7                                              AS Ti,
           CHOOSE((n * 5) % 11 + 1, 1,1,2,3,3,4,4,4,5,5,0)    AS Grupo
    FROM Numero
)
INSERT INTO dw.FactAtencion
    (Origen, CodigoAtencion, FechaKey, EstablecimientoKey, TipoAtencionKey, DuracionMinutos, EjecucionId, GrupoEtarioKey)
SELECT 'HIS', 'H26-' + RIGHT('00000' + CAST(b.n AS VARCHAR(5)), 5), f.FechaKey, e.EstablecimientoKey, t.TipoAtencionKey,
       10 + (b.n * 13) % 23 + (b.Est * 3) % 7
          + CHOOSE(b.Ti + 1, 4, 4, 0, -6, 4, 8, 0)
          + CHOOSE(b.Grupo + 1, 0, -2, 0, 0, 2, 5),
       5, b.Grupo
FROM Base b
-- CORRECCIÓN: Se cambió % 334 por % 364 para no salirse del calendario
INNER JOIN dw.DimFecha f ON f.Fecha = DATEADD(DAY, (b.n * 37) % 364, CONVERT(DATE, '20260101'))
INNER JOIN dw.DimEstablecimiento e ON e.CodigoEstablecimiento = 'EST-' + RIGHT('000' + CAST(b.Est AS VARCHAR(3)), 3)
INNER JOIN dw.DimTipoAtencion t
        ON t.TipoAtencion = CHOOSE(b.Ti + 1, 'CONSULTA','CONSULTA','CONTROL','VACUNACION','CONSULTA','LABORATORIO','CONTROL');

-- 4.3 Dosis: 7 de control (Tema 05) + 600 historicas
INSERT INTO dw.FactVacunacion (CodigoDosis, FechaKey, EstablecimientoKey, GrupoEtarioKey, VacunaKey, NumeroDosis)
SELECT s.Codigo, f.FechaKey, e.EstablecimientoKey, 1, v.VacunaKey, s.Dosis
FROM (VALUES ('VAC-001','20260902','EST-001',1),('VAC-002','20260903','EST-004',1),('VAC-003','20260903','EST-005',1),
             ('VAC-004','20260910','EST-002',1),('VAC-005','20261001','EST-002',2),('VAC-006','20261005','EST-003',1),
             ('VAC-007','20261008','EST-001',2)) AS s(Codigo,Fecha,Est,Dosis)
INNER JOIN dw.DimFecha f ON f.Fecha = s.Fecha
INNER JOIN dw.DimEstablecimiento e ON e.CodigoEstablecimiento = s.Est
INNER JOIN dw.DimVacuna v ON v.Vacuna = 'SIM-V';

WITH Digito AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)),
Numero AS (
    SELECT TOP (600) CONVERT(INT, ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) AS n
    FROM Digito a CROSS JOIN Digito b CROSS JOIN Digito c
)
INSERT INTO dw.FactVacunacion (CodigoDosis, FechaKey, EstablecimientoKey, GrupoEtarioKey, VacunaKey, NumeroDosis)
SELECT 'V26-' + RIGHT('00000' + CAST(x.n AS VARCHAR(5)), 5), f.FechaKey, e.EstablecimientoKey, 1, v.VacunaKey,
       CASE WHEN x.n % 3 = 0 THEN 2 ELSE 1 END
FROM Numero x
INNER JOIN dw.DimFecha f ON f.Fecha = DATEADD(DAY, (x.n * 11) % 334, CONVERT(DATE, '20260101'))
INNER JOIN dw.DimEstablecimiento e
        ON e.CodigoEstablecimiento = 'EST-' + RIGHT('000' + CAST(CHOOSE(x.n % 19 + 1, 1,4,5,1,2,2,3,6,7,8,1,4,5,2,7,6,8,3,1) AS VARCHAR(3)), 3)
INNER JOIN dw.DimVacuna v ON v.Vacuna = 'SIM-V';
GO

/* ---------- 5. Metas de cobertura (supuesto didactico declarado) ---------- */
CREATE TABLE dw.MetaCobertura (
    Provincia         VARCHAR(40)  NOT NULL,
    Anio              SMALLINT     NOT NULL,
    Vacuna            VARCHAR(20)  NOT NULL,
    PoblacionObjetivo INT          NOT NULL CONSTRAINT CK_MetaCobertura_Poblacion CHECK (PoblacionObjetivo > 0),
    MetaPorcentaje    DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_MetaCobertura PRIMARY KEY (Provincia, Anio, Vacuna)
);
INSERT INTO dw.MetaCobertura
SELECT s.* FROM (VALUES ('TRUJILLO',2026,'SIM-V',190,80.00), ('CHEPEN',2026,'SIM-V',78,80.00),
                        ('SANCHEZ CARRION',2026,'SIM-V',60,80.00), ('ASCOPE',2026,'SIM-V',50,80.00),
                        ('VIRU',2026,'SIM-V',56,80.00), ('PACASMAYO',2026,'SIM-V',48,80.00)) AS s(P,A,V,Pob,Meta);
GO

/* ---------- 6. Staging del ultimo lote del Tema 05 (para medir calidad en el E04) ---------- */
CREATE TABLE stg.Atencion (
    Origen VARCHAR(10) NOT NULL, CodigoAtencion VARCHAR(10) NOT NULL, FechaAtencion DATE NULL,
    CodigoEstablecimiento VARCHAR(10) NULL, TipoAtencion VARCHAR(20) NULL, DuracionMinutos INT NULL,
    EstadoRegistro VARCHAR(15) NULL, CodigoPaciente VARCHAR(10) NULL,
    CONSTRAINT PK_stg_Atencion PRIMARY KEY (Origen, CodigoAtencion)
);
CREATE TABLE stg.AtencionValida (
    Origen VARCHAR(10) NOT NULL, CodigoAtencion VARCHAR(10) NOT NULL, FechaAtencion DATE NOT NULL,
    CodigoEstablecimiento NVARCHAR(10) NOT NULL, TipoAtencion NVARCHAR(20) NOT NULL, DuracionMinutos INT NOT NULL,
    EstadoRegistro NVARCHAR(15) NOT NULL, CodigoPaciente VARCHAR(10) NULL,
    CONSTRAINT PK_stg_AtencionValida PRIMARY KEY (Origen, CodigoAtencion)
);
CREATE TABLE stg.AtencionRechazada (
    Origen VARCHAR(10) NOT NULL, CodigoAtencion VARCHAR(10) NOT NULL, FechaAtencion DATE NULL,
    CodigoEstablecimiento VARCHAR(10) NULL, TipoAtencion VARCHAR(20) NULL, DuracionMinutos INT NULL,
    EstadoRegistro VARCHAR(15) NULL, CodigoPaciente VARCHAR(10) NULL, MotivoRechazo NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_stg_AtencionRechazada PRIMARY KEY (Origen, CodigoAtencion)
);

INSERT stg.Atencion VALUES
 ('HIS','HIS-001','20260615','EST-001','CONSULTA',22,'VALIDO','PAC-0004'),
 ('HIS','HIS-002','20260916','EST-002','vacuna',9,'V','PAC-0006'),
 ('HIS','HIS-003','20260917','EST-003','CONTROL',-5,'VALIDO','PAC-0002'),
 ('HIS','HIS-004','20260618',NULL,'CONSULTA',15,'VALIDO','PAC-0003'),
 ('HIS','HIS-005','20261102','EST-004','LABORATORIO',30,'VALIDO','PAC-0004'),
 ('CAMPANIA','CAM-001','20260920',' est-001 ','Vacunacion',8,'VALIDO','PAC-0001'),
 ('CAMPANIA','CAM-002','20260920','EST-002',' CTRL ',14,' valido ',NULL),
 ('CAMPANIA','CAM-003',NULL,'EST-003','CONSULTA',20,'VALIDO','PAC-0003'),
 ('CAMPANIA','CAM-004','20260921','EST-001','VACUNACION',10,'PRUEBA','PAC-0001'),
 ('CAMPANIA','CAM-005','20261103','est-005','vacuna',7,'V','PAC-0006');

INSERT stg.AtencionValida VALUES
 ('HIS','HIS-001','20260615','EST-001','CONSULTA',22,'VALIDO','PAC-0004'),
 ('HIS','HIS-002','20260916','EST-002','VACUNACION',9,'VALIDO','PAC-0006'),
 ('HIS','HIS-005','20261102','EST-004','LABORATORIO',30,'VALIDO','PAC-0004'),
 ('CAMPANIA','CAM-001','20260920','EST-001','VACUNACION',8,'VALIDO','PAC-0001'),
 ('CAMPANIA','CAM-002','20260920','EST-002','CONTROL',14,'VALIDO',NULL),
 ('CAMPANIA','CAM-005','20261103','EST-005','VACUNACION',7,'VALIDO','PAC-0006');

INSERT stg.AtencionRechazada VALUES
 ('HIS','HIS-003','20260917','EST-003','CONTROL',-5,'VALIDO','PAC-0002','DURACION_NO_POSITIVA'),
 ('HIS','HIS-004','20260618',NULL,'CONSULTA',15,'VALIDO','PAC-0003','ESTABLECIMIENTO_AUSENTE'),
 ('CAMPANIA','CAM-003',NULL,'EST-003','CONSULTA',20,'VALIDO','PAC-0003','FECHA_AUSENTE'),
 ('CAMPANIA','CAM-004','20260921','EST-001','VACUNACION',10,'PRUEBA','PAC-0001','ESTADO_NO_VALIDO');
GO

/* ---------- 7. Vista del indicador (Tema 05) ---------- */
CREATE OR ALTER VIEW dw.vw_KpiAtencionProvinciaMes
AS
SELECT e.Provincia, f.Anio, f.Mes,
       COUNT(*) AS Atenciones, SUM(h.DuracionMinutos) AS MinutosTotales,
       CAST(SUM(h.DuracionMinutos) * 1.0 / COUNT(*) AS DECIMAL(6,2)) AS PromedioMinutos
FROM dw.FactAtencion h
INNER JOIN dw.DimFecha f ON f.FechaKey = h.FechaKey
INNER JOIN dw.DimEstablecimiento e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY e.Provincia, f.Anio, f.Mes;
GO

/* ---------- 8. Verificacion ---------- */
SELECT DB_NAME() AS BaseActiva,
       (SELECT COUNT(*) FROM dw.DimEstablecimiento)     AS Establecimientos,
       (SELECT COUNT(*) FROM dw.FactAtencion)           AS Atenciones,
       (SELECT SUM(DuracionMinutos) FROM dw.FactAtencion) AS Minutos,
       (SELECT COUNT(*) FROM dw.FactVacunacion)         AS Dosis,
       (SELECT SUM(PoblacionObjetivo) FROM dw.MetaCobertura) AS PoblacionObjetivo,
       (SELECT COUNT(*) FROM etl.EjecucionCarga)        AS Ejecuciones;
-- Esperado: BDDataSaludTema06 | 8 | 2012 | 55155 | 607 | 482 | 5
GO