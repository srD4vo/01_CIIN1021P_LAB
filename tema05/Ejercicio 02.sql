USE BDDataSaludTema05;
GO

-- Dimensión Fecha
IF OBJECT_ID(N'dw.DimFecha', N'U') IS NULL
CREATE TABLE dw.DimFecha (
    FechaKey   INT         NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
    Fecha      DATE        NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
    Anio       SMALLINT    NOT NULL,
    Semestre   TINYINT     NOT NULL,
    Trimestre  TINYINT     NOT NULL,
    Mes        TINYINT     NOT NULL,
    NombreMes  VARCHAR(10) NOT NULL,
    Dia        TINYINT     NOT NULL
);

-- Dimensión Establecimiento
IF OBJECT_ID(N'dw.DimEstablecimiento', N'U') IS NULL
CREATE TABLE dw.DimEstablecimiento (
    EstablecimientoKey    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEstablecimiento PRIMARY KEY,
    CodigoEstablecimiento VARCHAR(10) NOT NULL CONSTRAINT UQ_DimEstablecimiento_Codigo UNIQUE,
    Nombre                VARCHAR(60) NOT NULL,
    Categoria             VARCHAR(5)  NOT NULL,
    Ubigeo                CHAR(6)     NOT NULL,
    Provincia             VARCHAR(40) NOT NULL,
    Distrito              VARCHAR(40) NOT NULL
);
GO

------------------------

-- TODO E02-1 resuelto:
IF OBJECT_ID(N'dw.DimTipoAtencion', N'U') IS NULL
CREATE TABLE dw.DimTipoAtencion (
    TipoAtencionKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimTipoAtencion PRIMARY KEY,
    TipoAtencion VARCHAR(20) NOT NULL CONSTRAINT UQ_DimTipoAtencion_Tipo UNIQUE
);
GO

----------------------------

-- Paso 2. Calendario 2026
WITH Digito AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)),
Numero AS (
    SELECT a.n * 100 + b.n * 10 + c.n AS n
    FROM Digito AS a CROSS JOIN Digito AS b CROSS JOIN Digito AS c
),
Calendario AS (
    SELECT DATEADD(DAY, n, CONVERT(DATE, '20260101')) AS Fecha
    FROM Numero
    WHERE n < 365
)
INSERT INTO dw.DimFecha (FechaKey, Fecha, Anio, Semestre, Trimestre, Mes, NombreMes, Dia)
SELECT YEAR(c.Fecha) * 10000 + MONTH(c.Fecha) * 100 + DAY(c.Fecha),
       c.Fecha, YEAR(c.Fecha),
       CASE WHEN MONTH(c.Fecha) <= 6 THEN 1 ELSE 2 END,
       DATEPART(QUARTER, c.Fecha), MONTH(c.Fecha),
       CHOOSE(MONTH(c.Fecha), 'ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO',
              'JULIO','AGOSTO','SETIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'),
       DAY(c.Fecha)
FROM Calendario AS c
WHERE NOT EXISTS (SELECT 1 FROM dw.DimFecha AS d WHERE d.Fecha = c.Fecha);

-- Paso 3. Establecimientos
INSERT INTO dw.DimEstablecimiento
    (CodigoEstablecimiento, Nombre, Categoria, Ubigeo, Provincia, Distrito)
SELECT e.CodigoEstablecimiento, e.Nombre, e.Categoria, e.Ubigeo, e.Provincia, e.Distrito
FROM ope.Establecimiento AS e
WHERE NOT EXISTS (SELECT 1 FROM dw.DimEstablecimiento AS d
                  WHERE d.CodigoEstablecimiento = e.CodigoEstablecimiento);
GO
-------------------

-- TODO E02-2 resuelto:
INSERT INTO dw.DimTipoAtencion (TipoAtencion)
SELECT DISTINCT a.TipoAtencion
FROM ope.Atencion AS a
WHERE a.EstadoRegistro = 'VALIDO'
  AND NOT EXISTS (SELECT 1 FROM dw.DimTipoAtencion AS d
                  WHERE d.TipoAtencion = a.TipoAtencion);

-- Comprobar miembros dimensionales
SELECT 'DimFecha' AS Dimension, COUNT(*) AS Miembros FROM dw.DimFecha
UNION ALL SELECT 'DimEstablecimiento', COUNT(*) FROM dw.DimEstablecimiento
UNION ALL SELECT 'DimTipoAtencion', COUNT(*) FROM dw.DimTipoAtencion;
GO
---------------------
-- Paso 4. Tabla de hechos.
IF OBJECT_ID(N'dw.FactAtencion', N'U') IS NULL
CREATE TABLE dw.FactAtencion (
    Origen             VARCHAR(10) NOT NULL,
    CodigoAtencion     VARCHAR(10) NOT NULL,
    FechaKey           INT NOT NULL CONSTRAINT FK_FactAtencion_Fecha
                       REFERENCES dw.DimFecha (FechaKey),
    EstablecimientoKey INT NOT NULL CONSTRAINT FK_FactAtencion_Establecimiento
                       REFERENCES dw.DimEstablecimiento (EstablecimientoKey),
    TipoAtencionKey    INT NOT NULL CONSTRAINT FK_FactAtencion_Tipo
                       REFERENCES dw.DimTipoAtencion (TipoAtencionKey),
    DuracionMinutos    INT NOT NULL CONSTRAINT CK_FactAtencion_Duracion CHECK (DuracionMinutos > 0),
    EjecucionId        INT NULL,
    CONSTRAINT PK_FactAtencion PRIMARY KEY (Origen, CodigoAtencion)
);
GO

--------------------------------------

-- TODO E02-3 resuelto:
INSERT INTO dw.FactAtencion
    (Origen, CodigoAtencion, FechaKey, EstablecimientoKey, TipoAtencionKey, DuracionMinutos)
SELECT 'NUCLEO',
       CAST(a.AtencionId AS VARCHAR(10)),
       f.FechaKey, de.EstablecimientoKey, t.TipoAtencionKey,
       a.DuracionMinutos
FROM ope.Atencion AS a
INNER JOIN ope.Establecimiento    AS e  ON e.EstablecimientoId = a.EstablecimientoId
INNER JOIN dw.DimFecha            AS f  ON f.Fecha = a.FechaAtencion
INNER JOIN dw.DimEstablecimiento  AS de ON de.CodigoEstablecimiento = e.CodigoEstablecimiento
INNER JOIN dw.DimTipoAtencion     AS t  ON t.TipoAtencion = a.TipoAtencion
WHERE a.EstadoRegistro = 'VALIDO'
  AND NOT EXISTS (SELECT 1 FROM dw.FactAtencion AS h
                  WHERE h.Origen = 'NUCLEO'
                    AND h.CodigoAtencion = CAST(a.AtencionId AS VARCHAR(10)));

-- Verificación
SELECT COUNT(*) AS Hechos, SUM(DuracionMinutos) AS MinutosTotales FROM dw.FactAtencion;
GO
----------------------


-- TODO E02-4 resuelto:
SELECT h.Origen, h.CodigoAtencion,
       f.Fecha                  AS Fecha,
       e.Provincia              AS Provincia,
       t.TipoAtencion           AS TipoAtencion,
       h.DuracionMinutos
FROM dw.FactAtencion AS h
INNER JOIN dw.DimFecha           AS f ON f.FechaKey = h.FechaKey
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
INNER JOIN dw.DimTipoAtencion    AS t ON t.TipoAtencionKey = h.TipoAtencionKey
ORDER BY h.Origen, h.CodigoAtencion;
GO
------------

-- TODO E02-5 resuelto:
SELECT e.Provincia, 
       f.Anio, 
       f.Mes,
       COUNT(*) AS Atenciones,
       SUM(h.DuracionMinutos) AS MinutosTotales,
       CAST(AVG(CAST(h.DuracionMinutos AS DECIMAL(6,2))) AS DECIMAL(6,2)) AS PromedioMinutos
FROM dw.FactAtencion AS h
INNER JOIN dw.DimFecha AS f ON f.FechaKey = h.FechaKey
INNER JOIN dw.DimEstablecimiento AS e ON e.EstablecimientoKey = h.EstablecimientoKey
GROUP BY e.Provincia, f.Anio, f.Mes
ORDER BY e.Provincia;
GO