-- CIIN1021P | TEMA 05 | PREPARACION (ESTUDIANTE Y DOCENTE)
-- Ejecutar completo en SSMS (F5), conectado al Motor de base de datos.
-- SQL Server 2016 SP1 o posterior. No requiere las bases de temas previos:
-- retoma las nueve atenciones del Tema 04 y agrega lo necesario para BI.
-- Datos sinteticos: no hay personas, documentos ni establecimientos reales.
-- Crea objetos faltantes e inserta claves faltantes; no duplica la carga.
USE master;
GO
IF DB_ID(N'BDDataSaludTema05') IS NULL
    EXEC(N'CREATE DATABASE BDDataSaludTema05');
GO
USE BDDataSaludTema05;
GO
SET NOCOUNT ON;
-- Un esquema por capa de la arquitectura BI:
-- ope = operacional (OLTP), src = fuentes de entrada del ETL,
-- stg = staging, dw = Data Warehouse (se crea en E02), etl = control del ETL (E04).
IF SCHEMA_ID(N'ope') IS NULL EXEC(N'CREATE SCHEMA ope');
IF SCHEMA_ID(N'src') IS NULL EXEC(N'CREATE SCHEMA src');
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dw')  IS NULL EXEC(N'CREATE SCHEMA dw');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
GO

/* ---------- 1. Nucleo operacional (continua el Tema 04) ---------- */
IF OBJECT_ID(N'ope.Establecimiento', N'U') IS NULL
CREATE TABLE ope.Establecimiento (
    EstablecimientoId     INT          NOT NULL CONSTRAINT PK_ope_Establecimiento PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(10)  NOT NULL CONSTRAINT UQ_ope_Establecimiento_Codigo UNIQUE,
    Nombre                VARCHAR(60)  NOT NULL,
    Categoria             VARCHAR(5)   NOT NULL,
    Ubigeo                CHAR(6)      NOT NULL,
    Provincia             VARCHAR(40)  NOT NULL,
    Distrito              VARCHAR(40)  NOT NULL
);
INSERT ope.Establecimiento
SELECT s.* FROM (VALUES
 (1,'EST-001','Centro simulado Trujillo',    'I-3','130101','TRUJILLO','TRUJILLO'),
 (2,'EST-002','Centro simulado Chepen',      'I-4','130401','CHEPEN','CHEPEN'),
 (3,'EST-003','Puesto simulado Huamachuco',  'I-2','130901','SANCHEZ CARRION','HUAMACHUCO'),
 (4,'EST-004','Centro simulado La Esperanza','I-3','130105','TRUJILLO','LA ESPERANZA'),
 (5,'EST-005','Puesto simulado El Porvenir', 'I-1','130102','TRUJILLO','EL PORVENIR')
) AS s(Id,Codigo,Nombre,Categoria,Ubigeo,Provincia,Distrito)
WHERE NOT EXISTS (SELECT 1 FROM ope.Establecimiento e WHERE e.EstablecimientoId = s.Id);

-- Pacientes simulados. NombreSimulado y DocumentoSimulado representan
-- datos personales: existen en el origen, pero NO deben llegar al DW.
IF OBJECT_ID(N'ope.Paciente', N'U') IS NULL
CREATE TABLE ope.Paciente (
    PacienteId        INT          NOT NULL CONSTRAINT PK_ope_Paciente PRIMARY KEY,
    CodigoPaciente    VARCHAR(10)  NOT NULL CONSTRAINT UQ_ope_Paciente_Codigo UNIQUE,
    NombreSimulado    VARCHAR(40)  NOT NULL,
    DocumentoSimulado VARCHAR(12)  NOT NULL,
    Sexo              CHAR(1)      NOT NULL CONSTRAINT CK_ope_Paciente_Sexo CHECK (Sexo IN ('F','M')),
    FechaNacimiento   DATE         NULL
);
INSERT ope.Paciente
SELECT s.* FROM (VALUES
 (1, 'PAC-0001','PACIENTE SIMULADO 0001','SIM00000001','F','20190510'),
 (2, 'PAC-0002','PACIENTE SIMULADO 0002','SIM00000002','M','20081120'),
 (3, 'PAC-0003','PACIENTE SIMULADO 0003','SIM00000003','F','20010820'),
 (4, 'PAC-0004','PACIENTE SIMULADO 0004','SIM00000004','M','19851130'),
 (5, 'PAC-0005','PACIENTE SIMULADO 0005','SIM00000005','F','19580214'),
 (6, 'PAC-0006','PACIENTE SIMULADO 0006','SIM00000006','M','20251201'),
 (7, 'PAC-0007','PACIENTE SIMULADO 0007','SIM00000007','F','20260304'),
 (8, 'PAC-0008','PACIENTE SIMULADO 0008','SIM00000008','M','20260211'),
 (9, 'PAC-0009','PACIENTE SIMULADO 0009','SIM00000009','F','20260122'),
 (10,'PAC-0010','PACIENTE SIMULADO 0010','SIM00000010','M','20260409')
) AS s(Id,Codigo,Nombre,Documento,Sexo,Nacimiento)
WHERE NOT EXISTS (SELECT 1 FROM ope.Paciente p WHERE p.PacienteId = s.Id);

IF OBJECT_ID(N'ope.Atencion', N'U') IS NULL
CREATE TABLE ope.Atencion (
    AtencionId        INT          NOT NULL CONSTRAINT PK_ope_Atencion PRIMARY KEY CLUSTERED,
    EstablecimientoId INT          NOT NULL CONSTRAINT FK_ope_Atencion_Establecimiento
                                   REFERENCES ope.Establecimiento (EstablecimientoId),
    PacienteId        INT          NOT NULL CONSTRAINT FK_ope_Atencion_Paciente
                                   REFERENCES ope.Paciente (PacienteId),
    FechaAtencion     DATE         NOT NULL,
    TipoAtencion      VARCHAR(20)  NOT NULL,
    DuracionMinutos   INT          NOT NULL CONSTRAINT CK_ope_Atencion_Duracion CHECK (DuracionMinutos > 0),
    EstadoRegistro    VARCHAR(10)  NOT NULL CONSTRAINT CK_ope_Atencion_Estado
                                   CHECK (EstadoRegistro IN ('VALIDO','OBSERVADO','PRUEBA'))
);
-- Las nueve atenciones del Tema 04 (mismos identificadores, tipos, duraciones y estados).
INSERT ope.Atencion
SELECT s.* FROM (VALUES
 (1101,1,4,'20261001','CONSULTA',   20,'VALIDO'),
 (1102,2,5,'20261002','CONTROL',    15,'VALIDO'),
 (1103,1,6,'20261003','VACUNACION', 10,'VALIDO'),
 (1104,3,3,'20261004','LABORATORIO',30,'OBSERVADO'),
 (1105,2,3,'20261005','CONSULTA',   25,'VALIDO'),
 (1106,3,2,'20261006','CONTROL',    18,'VALIDO'),
 (1107,1,1,'20261007','VACUNACION', 12,'VALIDO'),
 (1108,2,4,'20261008','LABORATORIO',35,'OBSERVADO'),
 (1199,1,1,'20261009','CONSULTA',    5,'PRUEBA')
) AS s(Id,Est,Pac,Fecha,Tipo,Minutos,Estado)
WHERE NOT EXISTS (SELECT 1 FROM ope.Atencion a WHERE a.AtencionId = s.Id);

-- Poblacion objetivo (supuesto didactico) para el indicador de cobertura del E06.
IF OBJECT_ID(N'ope.PoblacionObjetivo', N'U') IS NULL
CREATE TABLE ope.PoblacionObjetivo (
    Provincia  VARCHAR(40) NOT NULL,
    Anio       SMALLINT    NOT NULL,
    Vacuna     VARCHAR(20) NOT NULL,
    Poblacion  INT         NOT NULL CONSTRAINT CK_ope_Poblacion CHECK (Poblacion > 0),
    CONSTRAINT PK_ope_PoblacionObjetivo PRIMARY KEY (Provincia, Anio, Vacuna)
);
INSERT ope.PoblacionObjetivo
SELECT s.* FROM (VALUES
 ('TRUJILLO',2026,'SIM-V',6), ('CHEPEN',2026,'SIM-V',2), ('SANCHEZ CARRION',2026,'SIM-V',4)
) AS s(Provincia,Anio,Vacuna,Poblacion)
WHERE NOT EXISTS (SELECT 1 FROM ope.PoblacionObjetivo p
                  WHERE p.Provincia = s.Provincia AND p.Anio = s.Anio AND p.Vacuna = s.Vacuna);
GO

/* ---------- 2. Fuentes de entrada del ETL (E03): sin reglas de calidad ---------- */
-- Simulan dos sistemas: el registro del establecimiento (HIS) y una hoja de campania.
-- Admiten nulos, espacios y variantes de texto para estudiar la limpieza.
IF OBJECT_ID(N'src.AtencionHIS', N'U') IS NULL
CREATE TABLE src.AtencionHIS (
    CodigoAtencion        VARCHAR(10) NOT NULL CONSTRAINT PK_src_AtencionHIS PRIMARY KEY,
    FechaAtencion         DATE        NULL,
    CodigoEstablecimiento VARCHAR(10) NULL,
    TipoAtencion          VARCHAR(20) NULL,
    DuracionMinutos       INT         NULL,
    EstadoRegistro        VARCHAR(15) NULL,
    CodigoPaciente        VARCHAR(10) NULL
);
IF OBJECT_ID(N'src.AtencionCampania', N'U') IS NULL
CREATE TABLE src.AtencionCampania (
    CodigoAtencion        VARCHAR(10) NOT NULL CONSTRAINT PK_src_AtencionCampania PRIMARY KEY,
    FechaAtencion         DATE        NULL,
    CodigoEstablecimiento VARCHAR(10) NULL,
    TipoAtencion          VARCHAR(20) NULL,
    DuracionMinutos       INT         NULL,
    EstadoRegistro        VARCHAR(15) NULL,
    CodigoPaciente        VARCHAR(10) NULL
);
INSERT src.AtencionHIS
SELECT s.* FROM (VALUES
 ('HIS-001','20260615','EST-001','CONSULTA',  22,'VALIDO','PAC-0004'),
 ('HIS-002','20260916','EST-002','vacuna',     9,'V',     'PAC-0006'),
 ('HIS-003','20260917','EST-003','CONTROL',   -5,'VALIDO','PAC-0002'),
 ('HIS-004','20260618', NULL,    'CONSULTA',  15,'VALIDO','PAC-0003')
) AS s(Codigo,Fecha,Est,Tipo,Minutos,Estado,Paciente)
WHERE NOT EXISTS (SELECT 1 FROM src.AtencionHIS h WHERE h.CodigoAtencion = s.Codigo);
INSERT src.AtencionCampania
SELECT s.* FROM (VALUES
 ('CAM-001','20260920',' est-001 ','Vacunacion', 8,'VALIDO',   'PAC-0001'),
 ('CAM-002','20260920','EST-002',  ' CTRL ',    14,' valido ',  NULL),
 ('CAM-003', NULL,     'EST-003',  'CONSULTA',  20,'VALIDO',   'PAC-0003'),
 ('CAM-004','20260921','EST-001',  'VACUNACION',10,'PRUEBA',   'PAC-0001')
) AS s(Codigo,Fecha,Est,Tipo,Minutos,Estado,Paciente)
WHERE NOT EXISTS (SELECT 1 FROM src.AtencionCampania c WHERE c.CodigoAtencion = s.Codigo);

-- Dosis aplicadas (E06). Sin clave primaria a proposito: VAC-004 llega repetida.
IF OBJECT_ID(N'src.VacunaAplicada', N'U') IS NULL
CREATE TABLE src.VacunaAplicada (
    CodigoDosis           VARCHAR(10) NOT NULL,
    FechaAplicacion       DATE        NOT NULL,
    CodigoEstablecimiento VARCHAR(10) NOT NULL,
    Vacuna                VARCHAR(20) NOT NULL,
    NumeroDosis           TINYINT     NOT NULL,
    CodigoPaciente        VARCHAR(10) NOT NULL
);
IF NOT EXISTS (SELECT 1 FROM src.VacunaAplicada)
INSERT src.VacunaAplicada VALUES
 ('VAC-001','20260902','EST-001','SIM-V',1,'PAC-0006'),
 ('VAC-002','20260903','EST-004','SIM-V',1,'PAC-0007'),
 ('VAC-003','20260903','EST-005','SIM-V',1,'PAC-0008'),
 ('VAC-004','20260910','EST-002','SIM-V',1,'PAC-0009'),
 ('VAC-004','20260910','EST-002','SIM-V',1,'PAC-0009'),
 ('VAC-005','20261001','EST-002','SIM-V',2,'PAC-0009'),
 ('VAC-006','20261005','EST-003','SIM-V',1,'PAC-0010'),
 ('VAC-007','20261008','EST-001','SIM-V',2,'PAC-0006');
GO

/* ---------- 3. Staging (E03): conserva lo recibido y separa validas y rechazadas ---------- */
IF OBJECT_ID(N'stg.Atencion', N'U') IS NULL
CREATE TABLE stg.Atencion (
    Origen                VARCHAR(10) NOT NULL,
    CodigoAtencion        VARCHAR(10) NOT NULL,
    FechaAtencion         DATE        NULL,
    CodigoEstablecimiento VARCHAR(10) NULL,
    TipoAtencion          VARCHAR(20) NULL,
    DuracionMinutos       INT         NULL,
    EstadoRegistro        VARCHAR(15) NULL,
    CodigoPaciente        VARCHAR(10) NULL,
    CONSTRAINT PK_stg_Atencion PRIMARY KEY (Origen, CodigoAtencion)
);
-- Las columnas limpias son NVARCHAR porque las expresiones de SSIS devuelven texto Unicode.
IF OBJECT_ID(N'stg.AtencionValida', N'U') IS NULL
CREATE TABLE stg.AtencionValida (
    Origen                VARCHAR(10)  NOT NULL,
    CodigoAtencion        VARCHAR(10)  NOT NULL,
    FechaAtencion         DATE         NOT NULL,
    CodigoEstablecimiento NVARCHAR(10) NOT NULL,
    TipoAtencion          NVARCHAR(20) NOT NULL,
    DuracionMinutos       INT          NOT NULL,
    EstadoRegistro        NVARCHAR(15) NOT NULL,
    CodigoPaciente        VARCHAR(10)  NULL,
    CONSTRAINT PK_stg_AtencionValida PRIMARY KEY (Origen, CodigoAtencion)
);
IF OBJECT_ID(N'stg.AtencionRechazada', N'U') IS NULL
CREATE TABLE stg.AtencionRechazada (
    Origen                VARCHAR(10)  NOT NULL,
    CodigoAtencion        VARCHAR(10)  NOT NULL,
    FechaAtencion         DATE         NULL,
    CodigoEstablecimiento VARCHAR(10)  NULL,
    TipoAtencion          VARCHAR(20)  NULL,
    DuracionMinutos       INT          NULL,
    EstadoRegistro        VARCHAR(15)  NULL,
    CodigoPaciente        VARCHAR(10)  NULL,
    MotivoRechazo         NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_stg_AtencionRechazada PRIMARY KEY (Origen, CodigoAtencion)
);
GO

/* ---------- 4. Verificacion ---------- */
SELECT DB_NAME() AS BaseActiva,
       (SELECT COUNT(*) FROM ope.Establecimiento)  AS Establecimientos,
       (SELECT COUNT(*) FROM ope.Paciente)         AS Pacientes,
       (SELECT COUNT(*) FROM ope.Atencion)         AS Atenciones,
       (SELECT COUNT(*) FROM src.AtencionHIS)      AS FuenteHIS,
       (SELECT COUNT(*) FROM src.AtencionCampania) AS FuenteCampania,
       (SELECT COUNT(*) FROM src.VacunaAplicada)   AS Dosis;
-- Esperado: BDDataSaludTema05 | 5 | 10 | 9 | 4 | 4 | 8
-- (si ya se ejecuto el Paso 5 del E04, las fuentes muestran 5 y 5).
GO
