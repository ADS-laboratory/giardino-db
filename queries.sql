-- Operazione 1
-- Aggiunta di una nuova PIANTA di un certo GENERE
CREATE OR REPLACE FUNCTION aggiungi_pianta(
    genere_pianta varchar(50),
    posizione_pianta char(5)
)
RETURNS void LANGUAGE plpgsql AS
$$
    DECLARE
        numero_pianta integer;
    BEGIN
        -- Calcolo numero progressivo della pianta
        SELECT max_id INTO numero_pianta FROM Genere WHERE nome = genere_pianta;
        IF numero_pianta IS NULL THEN
            RAISE NOTICE 'Il genere % non esiste', genere_pianta;
            RETURN;
        END IF;
        numero_pianta := numero_pianta + 1;

        -- Inserimento della pianta
        -- Se non esiste la posizione_pianta l'eccezione non è gestita
        INSERT INTO Pianta VALUES (numero_pianta, genere_pianta, posizione_pianta);

        -- Aggiornamento del numero progressivo del genere
        UPDATE Genere
        SET max_id = numero_pianta
        WHERE nome = genere_pianta;
        RETURN;
    END;
$$;

-- Operazione 2
-- Rimozione di una PIANTA
CREATE OR REPLACE FUNCTION rimuovi_pianta(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS void LANGUAGE plpgsql AS
$$
    BEGIN
        -- Rimozione della pianta
        DELETE FROM Pianta
        WHERE genere = genere_pianta AND numero = numero_pianta;
        RETURN;
    END;
$$;


-- Operazione 3
-- Modifica del Clima di una certa Posizione

CREATE OR REPLACE FUNCTION modifica_clima(
    codice_posizione char(5),
    nuovo_clima varchar(50)
)
RETURNS void LANGUAGE plpgsql AS
$$
    BEGIN
        -- Modifica del clima
        UPDATE Posizione
        SET clima = nuovo_clima
        WHERE codice = codice_posizione;
        RETURN;
    END;
$$;

-- Trigger o metto qui il controllo?


-- Operazione 4
-- Raggruppare le Piante di un certo Genere in numeri progressivi consecutivi
-- Operazione di Batch
-- non è un trigger perché non è un'operazione che si fa ad ogni inserimento
-- è un'operazione che si fa una volta ogni tanto

CREATE OR REPLACE FUNCTION aggiorna_numeri_piante()
RETURNS void LANGUAGE plpgsql AS
$$
    DECLARE
        numero_pianta integer;
        max_id_corrente integer;
        genere_corrente record;
        pianta_corrente record;
    BEGIN
        numero_pianta := 0;

        FOR genere_corrente IN SELECT * FROM Genere LOOP

            FOR pianta_corrente IN SELECT * FROM Pianta WHERE genere = genere_corrente.nome ORDER BY numero LOOP
                numero_pianta := numero_pianta + 1;
                UPDATE Pianta
                SET numero = numero_pianta
                WHERE genere = genere_corrente.nome AND numero = pianta_corrente.numero;
            END LOOP;

            max_id_corrente:= numero_pianta;
            UPDATE Genere
            SET max_id = max_id_corrente
            WHERE nome = genere_corrente.nome;

            numero_pianta := 0;

        END LOOP;
        RETURN;
    END;
$$;


-- Operazione 5
-- Data una Posizione trovare i Generi che possono stare solo lì

CREATE OR REPLACE FUNCTION genera_meno_posizione(
)
RETURNS TABLE (generi varchar(50)) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY
        CREATE VIEW Conta_Posizioni AS
        SELECT genere, COUNT(*) AS Numero_Posizioni
        FROM GP
        GROUP BY genere;

        SELECT genere
        FROM Conta_Posizioni
        WHERE Numero_Posizioni = (SELECT MIN(Numero_Posizioni) FROM Conta_Posizioni);
    END;
$$;


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