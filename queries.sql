-- Operazione 4
-- Raggruppare le Piante di un certo Genere in numeri progressivi consecutivi
-- Operazione di Batch
-- non è un trigger perché non è un'operazione che si fa ad ogni inserimento
-- è un'operazione che si fa una volta ogni tanto

CREATE OR REPLACE FUNCTION aggiorna_numeri_pianta()
RETURNS void LANGUAGE plpgsql AS
$$
    DECLARE
        numero_pianta integer;
        max_id integer;
        genere_corrente varchar(50);
        genere record;
        pianta record;
    BEGIN
        numero_pianta := 1;
        max_id := 1;
        genere_corrente := NULL;

        FOR genere IN SELECT nome FROM Genere LOOP

            FOR pianta IN SELECT * FROM Pianta WHERE genere = genere_corrente LOOP
                UPDATE Pianta
                SET numero = numero_pianta
                WHERE genere = genere_corrente AND numero = pianta.numero;
                numero_pianta := numero_pianta + 1;
            END LOOP;

            max_id:= numero_pianta;
            UPDATE Genere
            SET max_id = max_id
            WHERE nome = genere_corrente;

            numero_pianta := 1;
            genere_corrente := genere.nome;

        END LOOP;
        RETURN;
    END;
$$;


-- Operazione 5
-- Data una Posizione trovare i Generi che possono stare solo lì

SELECT genere
FROM GP
    JOIN Posizione ON Posizione.codice = GP.posizione
WHERE Posizione.codice = 'VsqbR' AND NOT EXISTS (
    SELECT *
    FROM GP as GP2
        JOIN Posizione as Posizione2 ON Posizione2.codice = GP2.posizione
    WHERE Posizione2.codice <> 'VsqbR' AND GP2.genere = GP.genere
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
FROM Pianta 
    JOIN EResponsabile  ON EResponsabile.Numero_Pianta = Pianta.Numero AND EResponsabile.Genere_Pianta = Pianta.Genere
    JOIN Lavora  ON Lavora.Giardiniere = EResponsabile.Giardiniere
    WHERE Lavora.Ora_Inizio >= '08:00:00' AND Lavora.Ora_Fine <= '17:00:00';


-- Operazione 8
-- Il Clima delle Posizioni in cui si trovano almeno 10 Piante del Genere x e almeno 20 del Genere y

-- Il numero di piante del genere x in ogni posizione
CREATE or REPLACE VIEW Numero_Piante_X AS
    SELECT Posizione, COUNT(*) AS Numero_Piante
    FROM Posizione
        JOIN Pianta ON Pianta.posizione = Posizione.codice
    WHERE Genere = 'Alplily'
    GROUP BY Posizione, Genere;

-- Il numero di piante del genere y in ogni posizione
CREATE OR REPLACE VIEW Numero_Piante_Y AS
    SELECT Posizione, COUNT(*) AS Numero_Piante
    FROM Posizione
        JOIN Pianta ON Pianta.posizione = Posizione.codice
    WHERE Genere = 'False Flax'
    GROUP BY Posizione, Genere;


SELECT Clima, codice
FROM Posizione
WHERE codice IN (
    SELECT Numero_Piante_X.Posizione
    FROM Numero_Piante_X
    WHERE Numero_Piante_X.Numero_Piante >= 10
    INTERSECT
    SELECT Numero_Piante_Y.Posizione
    FROM Numero_Piante_Y
    WHERE Numero_Piante_Y.Numero_Piante >= 20
);

-- TODO: Rivedere operazione 8