
-- Trovare il numero di Generi di Piante il cui Giardiniere responsabile inizia a lavorare, tutti i giorni, almeno alle 8:00 e finisce almeno alle 17:00
SELECT COUNT(DISTINCT Pianta.Genere)
FROM Giardino.Pianta Pianta
    JOIN Giardino.EResponsabile EResponsabile ON EResponsabile.Numero_Pianta = Pianta.Numero AND EResponsabile.Genere_Pianta = Pianta.Genere
    JOIN Giardino.Lavora Lavora ON Lavora.Giardiniere = EResponsabile.Giardiniere
    WHERE Lavora.Ora_Inizio >= '08:00:00' AND Lavora.Ora_Fine <= '17:00:00';
