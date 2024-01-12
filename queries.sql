
-- Trovare il numero di Generi di Piante il cui Giardiniere responsabile inizia a lavorare, tutti i giorni, almeno alle 8:00 e finisce almeno alle 17:00
SELECT COUNT(DISTINCT Pianta.Genere)
FROM Giardino.Pianta Pianta
    JOIN Giardino.EResponsabile EResponsabile ON EResponsabile.Numero_Pianta = Pianta.Numero AND EResponsabile.Genere_Pianta = Pianta.Genere
    JOIN Giardino.Lavora Lavora ON Lavora.Giardiniere = EResponsabile.Giardiniere
    WHERE Lavora.Ora_Inizio >= '08:00:00' AND Lavora.Ora_Fine <= '17:00:00';


-- Trovare la Posizione coperta da meno Giardinieri

CREATE VIEW Giardino.Numero_Giardinieri AS V1(
    SELECT Posizione, COUNT(*) AS Numero_Giardinieri
    FROM Giardino.Posizione as Posizione
        JOIN Giardino.Pianta as Pianta ON Pianta.posizione = Posizione.codice
        JOIN Giardino.EResponsabile as EResponsabile ON EResponsabile.genere_gianta = Pianta.genere AND EResponsabile.numero_pianta = Pianta.numero
    GROUP BY Posizione
)

SELECT Posizione, Numero_Giardinieri
FROM V1
WHERE Numero_Giardinieri <= ALL(SELECT Numero_Giardinieri FROM V1)
ORDER BY Posizione;