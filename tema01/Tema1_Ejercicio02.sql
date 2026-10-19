USE BBDatosSaludTema01;
GO

CREATE OR ALTER FUNCTION dbo.ufn_ClasificarDuracionAtencion(
    @Minutos INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Clasificacion VARCHAR(20);

    -- TODO 1 (concepto: entrada inválida)
    -- 1) Una UDF no puede usar THROW ni TRY...CATCH: ante una entrada inválida devuelve NULL.
    -- 2) NULL no se compara con = ni con <>; se pregunta con IS NULL.
    -- 3) Une "es NULL" y "no es positivo" de modo que baste con que una de las dos se cumpla.
    IF @Minutos IS NULL OR @Minutos <= 0
    BEGIN
        RETURN NULL;
    END;

    -- TODO 2 (concepto: rangos con límites incluidos)
    -- 1) Los rangos de la regla son 1 a 15 (CORTA) y 16 a 30 (REGULAR); lo demás es PROLONGADA.
    -- 2) Un rango con ambos extremos incluidos se expresa con BETWEEN ... AND ...
    SET @Clasificacion = 
        CASE
            WHEN @Minutos BETWEEN 1 AND 15 THEN 'CORTA'
            WHEN @Minutos BETWEEN 16 AND 30 THEN 'REGULAR'
            ELSE 'PROLONGADA'
        END;

    RETURN @Clasificacion;
END;
GO


-- Prueba unitaria: evalúa valores exactos en los límites
SELECT 
    dbo.ufn_ClasificarDuracionAtencion(10) AS Caso1,
    dbo.ufn_ClasificarDuracionAtencion(15) AS Caso2,
    dbo.ufn_ClasificarDuracionAtencion(16) AS Caso3,
    dbo.ufn_ClasificarDuracionAtencion(30) AS Caso4,
    dbo.ufn_ClasificarDuracionAtencion(31) AS Caso5,
    dbo.ufn_ClasificarDuracionAtencion(0)  AS Caso6;
GO

-- Prueba masiva: usa una tabla virtual (VALUES) y aplica la función a cada fila
SELECT 
    V.Minutos, 
    dbo.ufn_ClasificarDuracionAtencion(V.Minutos) AS Clasificacion
FROM 
(
    VALUES (5),(15),(16),(25),(30),(31),(60)
) AS V(Minutos);
GO