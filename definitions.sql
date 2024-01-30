
CREATE schema Giardino;

SET search_path TO Giardino;

-- DEFINIZIONE DEI DOMINI

-- Definizione del dominio COORDINATE
CREATE domain COORDINATE AS REAL[2] 
    CONSTRAINT latitudine CHECK (value[1] >= -90 and value[1] <= 90)
    CONSTRAINT longitudine CHECK (value[2] >= -180 and value[2] <= 180)
    CONSTRAINT not_null CHECK (value[1] IS NOT NULL AND value[2] IS NOT NULL);

-- DEFINIZIONE DELLE TABELLE

CREATE TABLE Famiglia (
    nome varchar(50) PRIMARY KEY,
    descrizione varchar(1000)
);

CREATE TABLE Genere (
    nome varchar(50) PRIMARY KEY,
    famiglia varchar(50) REFERENCES Famiglia
        ON DELETE RESTRICT
        ON UPDATE CASCADE
        NOT NULL,
    max_id integer NOT NULL
);

CREATE TABLE SensibileAlClima (
    famiglia varchar(50) PRIMARY KEY REFERENCES Famiglia
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE Clima (
    nome varchar(50) PRIMARY KEY
);

CREATE TABLE PuoStare (
    clima varchar(50) REFERENCES Clima
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    sensibile_al_clima varchar(50) REFERENCES SensibileAlClima
        ON DELETE CASCADE -- Aggiungere trigger per controllare che ci siana almeno un elemento
        ON UPDATE CASCADE,
    PRIMARY KEY (clima, sensibile_al_clima)
);

CREATE TABLE Posizione (
    codice char(5) PRIMARY KEY,
    clima varchar(50) REFERENCES Clima 
        ON DELETE RESTRICT
        ON UPDATE CASCADE
        NOT NULL,
    nome varchar(50),
    coordinate COORDINATE UNIQUE
);

CREATE TABLE Pianta (
    numero integer,
    genere varchar(50) REFERENCES Genere 
        ON DELETE RESTRICT
        ON UPDATE CASCADE
        NOT NULL,
    posizione char(5) REFERENCES Posizione
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    PRIMARY KEY (numero, genere)
);

CREATE TABLE Giardiniere (
    cf char(16) PRIMARY KEY,
    nome varchar(50) NOT NULL,
    cognome varchar(50) NOT NULL
);

CREATE TABLE EResponsabile (
    numero_pianta integer,
    genere_pianta varchar(50),
    giardiniere char(16) REFERENCES Giardiniere(cf)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    PRIMARY KEY (numero_pianta, genere_pianta, giardiniere),
    FOREIGN KEY (numero_pianta, genere_pianta) REFERENCES Pianta
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE Orario (
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giorno_della_settimana, ora_inizio, ora_fine)
);

CREATE TABLE Lavora (
    giardiniere char(16) REFERENCES Giardiniere(cf)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giardiniere, giorno_della_settimana, ora_inizio, ora_fine),
    FOREIGN KEY (giorno_della_settimana, ora_inizio, ora_fine) REFERENCES Orario
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- check for non overlapping time intervals

CREATE TABLE GP (
    genere varchar(50) REFERENCES Genere
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    posizione char(5) REFERENCES Posizione
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    PRIMARY KEY (genere, posizione)
);

-- DEFINIZIONE DELLE FUNZIONI E DEI TRIGGER

-- Controllo che un giardiniere abbia almeno un orario
CREATE OR REPLACE FUNCTION check_orario_giardiniere()
RETURNS TRIGGER LANGUAGE plpgsql AS 
$$
    DECLARE
        count integer;
    BEGIN
        SELECT COUNT(*) INTO count
        FROM Lavora
        WHERE OLD.giardiniere = giardiniere;
        IF count <= 1 THEN
            RAISE NOTICE 'Un giardiniere deve avere almeno un orario';
            RETURN NULL; -- annulla operazione
        END IF;
        RETURN OLD;
    END;
$$;

-- Controllo che un giardiniere abbia almeno un orario
CREATE OR REPLACE TRIGGER check_orario_giardiniere
BEFORE DELETE ON Lavora
FOR EACH ROW
EXECUTE PROCEDURE check_orario_giardiniere();

-- Controllo che una famiglia sensibile al clima abbia almeno un clima a cui è sensibile
CREATE OR REPLACE FUNCTION check_sensibile_al_clima()
RETURNS TRIGGER LANGUAGE plpgsql AS
$$
    DECLARE
        count integer;
    BEGIN
        SELECT COUNT(*) INTO count
        FROM PuoStare
        WHERE OLD.sensibile_al_clima = sensibile_al_clima;
        IF count <= 1 THEN
            RAISE NOTICE 'Una famiglia sensibile al clima deve avere almeno un clima a cui è sensibile';
            RETURN NULL; -- annulla operazione
        END IF;
        RETURN OLD;
    END;
$$;

-- Controllo che una famiglia sensibile al clima abbia almeno un clima a cui è sensibile
CREATE OR REPLACE TRIGGER check_sensibile_al_clima
BEFORE DELETE ON PuoStare
FOR EACH ROW
EXECUTE PROCEDURE check_sensibile_al_clima();

-- Aggiornamento dell'attributo max_id di Genere, 
-- controllato nell'operazione di aggiunta, spiegare perché nel file

---- verificare funzionamento

-- Sensibile al clima only append
-- PuoStare  only append

------------------------------------------------------------------------------------------
-- CHECK PIANTE POSIZIONE
-- Prima dell'operazione di MODIFICA DEL CLIMA, verifica che non ci siano piante che non
-- possono stare nel nuovo clima.
CREATE OR REPLACE FUNCTION check_piante_posizione()
RETURNS TRIGGER LANGUAGE plpgsql AS
$$
    DECLARE
        famiglia varchar(50);
    BEGIN
        FOR famiglia IN SELECT DISTINCT Genere.famiglia
            -- Selezione di tutte le famiglie delle piante che sono nella posizione che
            -- sto modificando.
            FROM Pianta JOIN Genere ON Pianta.genere = Genere.nome
            WHERE Pianta.posizione = OLD.codice
        LOOP
            -- Per ognuna di queste famiglie controllo che possa stare nel clima.
            IF famiglia IN (SELECT * FROM SensibileAlClima) THEN
                -- Se la famiglia è sensibile al clima controllo che possa stare nel clima.
                IF NOT EXISTS (SELECT *
                    FROM PuoStare
                    WHERE sensibile_al_clima = famiglia AND clima = NEW.clima) THEN
                    -- Se la famiglia è sensibile al clima ma non è in relazione con i
                    -- nuovo clima ritorno un errore e annullo l'operazione.
                    RAISE NOTICE 'La famiglia % non può stare nel clima %', famiglia, NEW.clima;
                    RETURN NULL;
                END IF;
            END IF;
        END LOOP;
        RETURN NEW;
    END;
$$;

CREATE OR REPLACE TRIGGER check_piante_posizione
BEFORE UPDATE ON Posizione
FOR EACH ROW
EXECUTE PROCEDURE check_piante_posizione();

-- TEST 1
UPDATE Posizione
SET clima = 'tropical'
WHERE codice = 'VsqbR';
-- Expected output:
-- NOTICE:  La famiglia Cuscutaceae non può stare nel clima tropical
-- Check correctness:
-- SELECT * FROM PuoStare WHERE sensibile_al_clima = 'Cuscutaceae';
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- AGGIORNA GP
-- Dopo l'operazione di MODIFICA DEL CLIMA aggiorna la relazione GP di conseguenza.
CREATE OR REPLACE FUNCTION aggiorna_gp()
RETURNS TRIGGER LANGUAGE plpgsql AS
$$
    BEGIN
        -- Rimuovo tutte le tuple di GP in cui la posizione è quella che sto modificando.
        DELETE FROM GP
        WHERE OLD.codice = posizione;

        -- Reiewnserisco i dati eliminati calcolandoli tenendo conto del nuovo clima.
        INSERT INTO GP
        SELECT nome, NEW.codice
        FROM Genere
        WHERE famiglia IN (SELECT sensibile_al_clima FROM PuoStare WHERE clima = NEW.clima)
            OR famiglia NOT IN (SELECT * FROM SensibileAlClima);
        RETURN NULL;
    END;
$$;

CREATE OR REPLACE TRIGGER aggiorna_gp
AFTER UPDATE ON Posizione
FOR EACH ROW
EXECUTE PROCEDURE aggiorna_gp();

-- TEST 1
UPDATE Posizione
SET clima = 'tropical'
WHERE codice = 'LXqz5';
-- Rimane uguale.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- CHECK INSERIMENTO PIANTA
-- Prima dell'AGGIUNTA / MODIFICA DI UNA PIANTA controlla che possa essere inserita nella
-- posizione desiderata.
CREATE OR REPLACE FUNCTION check_inserimento_pianta()
RETURNS TRIGGER LANGUAGE plpgsql AS
$$
    BEGIN
        IF NOT EXISTS (
            SELECT *
            FROM GP
            WHERE genere = NEW.genere AND posizione = NEW.posizione
        ) THEN
        RAISE NOTICE 'La pianta di genere % non può stare nella posizione %.', NEW.genere, NEW.posizione;
        RETURN NULL;
        END IF;

        RETURN NEW;
    END;
$$;

CREATE OR REPLACE TRIGGER check_inserimento_pianta
BEFORE INSERT OR UPDATE ON Pianta
FOR EACH ROW
EXECUTE PROCEDURE check_inserimento_pianta();

-- TEST 1
SELECT aggiungi_pianta('Pacific Bristlystalked Sedge', 'VsqbR');
-- Expected output:
-- NOTICE:  La pianta di genere Pacific Bristlystalked Sedge non può stare nella posizione
-- VsqbR.
-- TEST 2
SELECT aggiungi_pianta('Pacific Bristlystalked Sedge', 'XV4kn');
-- Expected output:
-- Pianta aggiunta.
------------------------------------------------------------------------------------------
