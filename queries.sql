
-- Operazione 5
-- Data una Posizione trovare i Generi che possono stare solo lì

SELECT genere
FROM GP as GP
    JOIN Posizione as Posizione ON Posizione.codice = GP.posizione
WHERE Posizione.codice = 'P1' AND NOT EXISTS (
    SELECT *
    FROM GP as GP2
        JOIN Posizione as Posizione2 ON Posizione2.codice = GP2.posizione
    WHERE Posizione2.codice <> 'P1' AND GP2.genere = GP.genere
    );


-- Operazione 6
-- Trovare la Posizione coperta da meno Giardinieri

CREATE VIEW V1 AS
    SELECT Posizione, COUNT(DISTINCT EResponsabile.giardiniere) AS Numero_Giardinieri
    FROM Posizione
        JOIN Pianta ON Pianta.posizione = Posizione.codice
        JOIN EResponsabile ON EResponsabile.genere_pianta = Pianta.genere AND EResponsabile.numero_pianta = Pianta.numero
    GROUP BY Posizione;

SELECT *
FROM V1
WHERE Numero_Giardinieri <= ALL(SELECT Numero_Giardinieri FROM V1)
ORDER BY Posizione;


-- Operazione 7
-- Trovare il numero di Generi di Piante il cui Giardiniere responsabile inizia a lavorare, tutti i giorni, almeno alle 8:00 e finisce almeno alle 17:00
SELECT COUNT(DISTINCT Pianta.Genere)
FROM Giardino.Pianta Pianta
    JOIN Giardino.EResponsabile EResponsabile ON EResponsabile.Numero_Pianta = Pianta.Numero AND EResponsabile.Genere_Pianta = Pianta.Genere
    JOIN Giardino.Lavora Lavora ON Lavora.Giardiniere = EResponsabile.Giardiniere
    WHERE Lavora.Ora_Inizio >= '08:00:00' AND Lavora.Ora_Fine <= '17:00:00';
