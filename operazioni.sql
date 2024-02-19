SET search_path TO Giardino;

-- OPERAZIONE 1
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
        INSERT INTO Pianta VALUES (numero_pianta, genere_pianta, posizione_pianta);

        -- Aggiornamento del numero progressivo del genere
        -- Quest'operazione non è delegata ad un trigger perché dovremmo calcolare ogni
        -- volta il max (ciò renderebbe inefficiente il sistema)
        UPDATE Genere
        SET max_id = numero_pianta
        WHERE nome = genere_pianta;
        RETURN;
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 2
-- Rimozione di una PIANTA
CREATE OR REPLACE FUNCTION rimuovi_pianta(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS void LANGUAGE plpgsql AS
$$
    BEGIN
        DELETE FROM Pianta
        WHERE genere = genere_pianta AND numero = numero_pianta;
        RETURN;
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 3
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
        -- L'aggiornamento della relazione GP è gestito dal trigger aggiorna_gp
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 4
-- Raggruppa le Piante di un certo Genere in numeri progressivi consecutivi
-- e aggiorna il numero progressivo massimo del Genere
-- Operazione eseguita saltuariamente per mantenere l'ordine dei numeri progressivi

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

        -- Per ogni genere
        FOR genere_corrente IN SELECT * FROM Genere LOOP
            -- Per ogni pianta di quel genere
            FOR pianta_corrente IN SELECT * FROM Pianta WHERE genere = genere_corrente.nome ORDER BY numero LOOP
                -- Aggiorno il numero progressivo della pianta

                -- La query precedente è ordinata in base al numero progressivo precedente in quanto
                -- diversamente potrebbero esserci chiavi duplicate.
                numero_pianta := numero_pianta + 1;
                UPDATE Pianta
                SET numero = numero_pianta
                WHERE genere = genere_corrente.nome AND numero = pianta_corrente.numero;
            END LOOP;

            max_id_corrente:= numero_pianta;
            -- Aggiorno il numero progressivo massimo del genere
            UPDATE Genere
            SET max_id = max_id_corrente
            WHERE nome = genere_corrente.nome;

            -- Resetto il numero progressivo
            numero_pianta := 0;

        END LOOP;
        RETURN;
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 5
-- Trovare il Genere di Piante che può stare in meno Posizioni

CREATE OR REPLACE FUNCTION genere_puo_stare_in_meno_posizioni()
RETURNS TABLE (generi varchar(50)) LANGUAGE plpgsql AS
$$
    BEGIN
        -- Il numero di posizioni possibili per ogni genere
        CREATE OR REPLACE VIEW Conta_Posizioni AS
        SELECT genere, COUNT(*) AS Numero_Posizioni
        FROM GP
        GROUP BY genere;

        -- Viene selezionato il genere cnon il minor numero di posizioni associabili
        RETURN QUERY
        SELECT genere
        FROM Conta_Posizioni
        WHERE Numero_Posizioni = (SELECT MIN(Numero_Posizioni) FROM Conta_Posizioni);
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 6
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

        -- Viene selezionata la posizione con il minor numero di giardinieri
        RETURN QUERY
        SELECT Giardinieri_Per_Posizione.posizione
        FROM Giardinieri_Per_Posizione
        WHERE numero_Giardinieri = (SELECT MIN(numero_Giardinieri) FROM Giardinieri_Per_Posizione)
        ORDER BY Posizione;
    END;
$$;


------------------------------------------------------------------------------------------
-- OPERAZIONE 7
-- Trovare il numero di Generi per cui esiste almeno una Pianta il cui Giardiniere
-- responsabile lavora almeno dalle 10:00 alle 16:00 tutti i giorni in cui lavora.
CREATE OR REPLACE FUNCTION numero_generi_giardiniere()
RETURNS TABLE (numero_generi bigint) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY
        SELECT Count(DISTINCT Genere_Pianta)
        FROM EResponsabile AS ER1
        -- Per ogni pianta controlla se il giardiniere responsabile lavora dalle 10:00 alle 16:00
        -- tutti i giorni in cui lavora
        -- Se così considero il genere della pianta nell'operazione count
        WHERE (Genere_Pianta, Numero_Pianta) NOT IN (
            SELECT DISTINCT ER2.Genere_Pianta, ER2.Numero_Pianta
            FROM EResponsabile AS ER2 JOIN Lavora ON Lavora.Giardiniere = ER2.Giardiniere
            WHERE Lavora.Ora_inizio > '10:00:00' OR Lavora.Ora_fine < '16:00:00'
        );
    END;
$$;

------------------------------------------------------------------------------------------
-- OPERAZIONE 8
-- Il Clima delle Posizioni in cui si trovano almeno 10 Piante del Genere x e almeno 15 del Genere y

-- Funzione di supporto che, dato un genere, restituisce una tabella con due colonne:
-- posizione e numero di piante in quella posizione
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

-- Funzione che implementa l'operazione richiesta
-- Restituisce la coppia (clima, codice_posizione) per ogni posizione in cui si trovano almeno 10 piante
-- del genere x e almeno 15 del genere y
CREATE OR REPLACE FUNCTION clima_delle_posizioni(
    genere_x varchar(50),
    genere_y varchar(50)
)
RETURNS TABLE (clima_posizione varchar(50), codice_posizione char(5)) LANGUAGE plpgsql AS
$$
    BEGIN
        -- Il risultato è l'intersezione tra le posizioni in cui si trovano almeno 10 piante del 
        -- genere x e almeno 15 del genere y
        RETURN QUERY
        SELECT Clima, codice
        FROM Posizione
        WHERE codice IN (
            SELECT Numero_Piante_X.posizione_pianta
            FROM piante_posizione(genere_x) AS Numero_Piante_X
            WHERE Numero_Piante_X.Numero_Piante >= 10
            INTERSECT
            SELECT Numero_Piante_Y.posizione_pianta
            FROM piante_posizione(genere_y) AS Numero_Piante_Y
            WHERE Numero_Piante_Y.Numero_Piante >= 15
        );
    END;
$$;

------------------------------------------------------------------------------------------
-- OPERAZIONE 9
-- Data una pianta trovare la posizione (o le posizioni se più di una) meno affollata in
-- cui può essere spostata.


-- Funzione di supporto che per ogni posizione in cui può stare una pianta restituisce una tabella con due colonne:
-- codice della posizione e numero di piante in quella posizione

CREATE OR REPLACE FUNCTION trova_posizioni_candidate(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS TABLE (posizione char(5), numero_piante bigint) LANGUAGE plpgsql AS
$$
    DECLARE
        posizione_corrente char(5);
    BEGIN
        -- La posizione corrente in cui si trova la pianta.
        SELECT Pianta.posizione INTO posizione_corrente
        FROM Pianta
        WHERE genere = genere_pianta AND numero = numero_pianta;

        RETURN QUERY
        -- Le posizioni in cui può stare la pianta. Per ogni posizione il
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
        GROUP BY Pianta.posizione;
    END;
$$;


-- Funzione che implementa l'operazione richiesta
-- Restituisce la posizione (o le posizioni) meno affollata tra quelle trovate con la funzione
-- di supporto trova_posizioni_candidate.
CREATE OR REPLACE FUNCTION trova_posizioni_alternative(
    genere_pianta varchar(50),
    numero_pianta integer
)
RETURNS TABLE (codice char(5)) LANGUAGE plpgsql AS
$$
    BEGIN
        RETURN QUERY
        SELECT Candidati.Posizione
        FROM trova_posizioni_candidate(genere_pianta, numero_pianta) AS Candidati
        WHERE numero_piante = (
            SELECT MIN(numero_piante)
            FROM trova_posizioni_candidate(genere_pianta, numero_pianta)
        );
    END;
$$;
