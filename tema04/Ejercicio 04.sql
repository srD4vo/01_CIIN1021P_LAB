SELECT AtencionId AS atencionId,
       EstablecimientoId AS establecimientoId,
       FechaAtencion AS fecha,
       TipoAtencion AS tipo,
       DuracionMinutos AS duracionMinutos,
       'SQL_E04' AS origen
FROM dbo.Atencion
WHERE Lote = 'T04_DEMO'
  AND AtencionId BETWEEN 1101 AND 1104
  AND EstadoRegistro = 'VALIDO'
ORDER BY AtencionId
FOR JSON PATH;