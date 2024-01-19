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
        -- Quest'operazione non è delegata ad un trigger perchè dovremmo calcolarci ogni
        -- volta il max (e non converrebbe più avere l'attributo derivato) oppure dovremmo
        -- fare solo +1 fidandoci che l'inserimento sia stato fatto con questa operazione
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
-- Trovare il Genere di Piante che può stare in meno Posizioni

CREATE OR REPLACE FUNCTION genera_meno_posizione()
RETURNS TABLE (generi varchar(50)) LANGUAGE plpgsql AS
$$
    BEGIN
        CREATE OR REPLACE VIEW Conta_Posizioni AS
        SELECT genere, COUNT(*) AS Numero_Posizioni
        FROM GP
        GROUP BY genere;

        RETURN QUERY
        SELECT genere
        FROM Conta_Posizioni
        WHERE Numero_Posizioni = (SELECT MIN(Numero_Posizioni) FROM Conta_Posizioni);
    END;
$$;


-- Operazione 6
-- Trovare la Posizione coperta da meno Giardinieri

CREATE OR REPLACE FUNCTION posizioni_con_meno_giardinieri()
RETURNS TABLE (posizione char(5)) LANGUAGE plpgsql AS
$$
    BEGIN
        -- Il numero di giardinieri per ogni posizione
        CREATE OR REPLACE VIEW Giardinieri_Per_Posizione AS
            SELECT Posizione, COUNT(DISTINCT EResponsabile.giardiniere) AS numero_Giardinieri
            FROM Posizione
                JOIN Pianta ON Pianta.posizione = Posizione.codice
                JOIN EResponsabile ON EResponsabile.genere_pianta = Pianta.genere AND EResponsabile.numero_pianta = Pianta.numero
            GROUP BY Posizione;

        RETURN QUERY
        SELECT Giardinieri_Per_Posizione.posizione
        FROM Giardinieri_Per_Posizione
        WHERE numero_Giardinieri = (SELECT MIN(numero_Giardinieri) FROM Giardinieri_Per_Posizione)
        ORDER BY Posizione;
    END;
$$;


-- Operazione 7
-- Trovare il numero di Generi di Piante il cui Giardiniere responsabile inizia a lavorare, tutti i giorni, almeno alle 8:00 e finisce almeno alle 17:00
SELECT COUNT(DISTINCT Pianta.Genere)
FROM Pianta 
    JOIN EResponsabile  ON EResponsabile.Numero_Pianta = Pianta.Numero AND EResponsabile.Genere_Pianta = Pianta.Genere
    JOIN Lavora  ON Lavora.Giardiniere = EResponsabile.Giardiniere
    WHERE Lavora.Ora_Inizio >= '08:00:00' AND Lavora.Ora_Fine <= '17:00:00';


-- Operazione 8
-- Il Clima delle Posizioni in cui si trovano almeno 10 Piante del Genere x e almeno 20 del Genere y

CREATE OR REPLACE FUNCTION piante_posizione(
    genere_ricercato varchar(50)
)
RETURNS TABLE (posizione_pianta char(5), numero_piante bigint) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY
        SELECT Posizione, COUNT(*) AS Numero_Piante
        FROM (Posizione
            JOIN Pianta ON Pianta.posizione = Posizione.codice) AS A
        WHERE A.genere = genere_ricercato
        GROUP BY Posizione, Genere;
    END;
$$;

CREATE OR REPLACE FUNCTION clima_delle_posizioni(
    genere_x varchar(50),
    genere_y varchar(50)
)
RETURNS TABLE (clima_posizione varchar(50), codice_posizione char(5)) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY

        SELECT Clima, codice
        FROM Posizione
        WHERE codice IN (
            SELECT Numero_Piante_X.posizione_pianta
            FROM piante_posizione(genere_x) AS Numero_Piante_X
            WHERE Numero_Piante_X.Numero_Piante >= 5
            INTERSECT
            SELECT Numero_Piante_Y.posizione_pianta
            FROM piante_posizione(genere_y) AS Numero_Piante_Y
            WHERE Numero_Piante_Y.Numero_Piante >= 10
        );
    END;
$$;


-- Operazione 9
-- Data una pianta trovare la posizione (o le posizioni se più di una) meno affollata in
-- cui può essere spostata.
-- TODO: funziona?
CREATE OR REPLACE FUNCTION trova_posizioni_alternative(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS TABLE (codice char(5)) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY
        -- Trovo la posizione (o le posizioni) meno affollata tra quelle trovate con la
        -- funzione di supporto trova_posizioni_candidate.
        SELECT Candidati.posizione
        FROM trova_posizioni_candidate(genere_pianta, numero_pianta) AS Candidati
        WHERE numero_piante = (
            SELECT MIN(numero_piante)
            FROM trova_posizioni_candidate(genere_pianta, numero_pianta)
        );
    END;
$$;

CREATE OR REPLACE FUNCTION trova_posizioni_candidate(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS TABLE (posizione char(5), numero_piante bigint) LANGUAGE plpgsql AS
$$
    DECLARE
        posizione_corrente char(5);
    BEGIN
        -- Trovo la posizione corrente in cui si trova la pianta.
        SELECT Pianta.posizione INTO posizione_corrente
        FROM Pianta
        WHERE genere = genere_pianta AND numero = numero_pianta;

        RETURN QUERY
        -- Trovo tutte le posizioni alternative in cui può stare la pianta.
        SELECT *
        FROM (
            -- Trovo le posizioni in cui può stare la pianta. Per ogni posizione trovo il
            -- numero di piante.
            SELECT Pianta.posizione, COUNT(*) AS numero_piante
            FROM Pianta
            WHERE Pianta.posizione IN (
                SELECT GP.posizione
                FROM GP
                WHERE genere = genere_pianta
            )
            -- Escludo la posizione corrente.
            AND Pianta.posizione <> posizione_corrente
            GROUP BY Pianta.posizione
        );
    END;
$$;
