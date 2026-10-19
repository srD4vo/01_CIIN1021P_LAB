USE BBDatosSaludTema01;
GO

-- ==========================================
-- PASO 1: CREAR LA FUNCIÓN (Si no existe, la crea)
-- ==========================================
CREATE OR ALTER FUNCTION dbo.ufn_RegistrosAptosCarga(
    @LoteCarga VARCHAR(20)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        S.RegistroId,
        P.PacienteId,
        E.EstablecimientoId,
        S.CodigoPaciente,
        S.CodigoEstablecimiento,
        S.TipoAtencion,
        S.DuracionMinutos,
        dbo.ufn_ClasificarDuracionAtencion(S.DuracionMinutos) AS ClasificacionDuracion,
        S.FechaAtencion
    FROM dbo.AtencionStaging AS S
    INNER JOIN dbo.Paciente AS P
        ON P.CodigoPaciente = S.CodigoPaciente
       AND P.Estado = 'A'
    INNER JOIN dbo.EstablecimientoSalud AS E
        ON E.CodigoEstablecimiento = S.CodigoEstablecimiento
       AND E.Estado = 'A'
    WHERE S.LoteCarga = @LoteCarga
      AND S.TipoAtencion IN ('CONSULTA', 'CONTROL', 'VACUNACION')
      AND S.DuracionMinutos BETWEEN 1 AND 180
      AND S.FechaAtencion IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 
          FROM dbo.AtencionStaging AS B
          WHERE B.LoteCarga = S.LoteCarga
            AND B.RegistroId < S.RegistroId
            AND B.CodigoPaciente = S.CodigoPaciente
            AND B.CodigoEstablecimiento = S.CodigoEstablecimiento
            AND B.TipoAtencion = S.TipoAtencion
            AND B.DuracionMinutos = S.DuracionMinutos
            AND B.FechaAtencion = S.FechaAtencion
      )
);
GO

-- ==========================================
-- PASO 2: PRUEBAS
-- ==========================================

-- Prueba 1: LOTE-001
SELECT * 
FROM dbo.ufn_RegistrosAptosCarga('LOTE-001');
GO

-- Prueba 2: LOTE-002 (Ya insertaste los datos en el intento anterior)
SELECT * 
FROM dbo.ufn_RegistrosAptosCarga('LOTE-002')
ORDER BY RegistroId;
GO