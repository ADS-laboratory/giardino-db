
CREATE OR REPLACE schema Giardino;

SET search_path TO Giardino;

-- DEFINIZIONE DEI DOMINI

-- Definizione del dominio COORDINATE
CREATE OR REPLACE domain COORDINATE AS REAL[2] 
    CONSTRAINT latitudine CHECK (value[0] >= -90 and value[0] <= 90)
    CONSTRAINT longitudine CHECK (value[1] >= -180 and value[1] <= 180)
    CONSTRAINT not_null CHECK (value[0] IS NOT NULL AND value[1] IS NOT NULL);

-- DEFINIZIONE DELLE TABELLE

CREATE OR REPLACE TABLE Famiglia (
    nome varchar(50) PRIMARY KEY,
    descrizione varchar(1000)
);

CREATE OR REPLACE TABLE Genere (
    nome varchar(50) PRIMARY KEY,
    famiglia varchar(50) REFERENCES Famiglia
        ON DELETE RESTRICT
        ON UPDATE CASCADE
        NOT NULL,
    max_id integer NOT NULL
);

CREATE OR REPLACE TABLE SensibileAlClima (
    famiglia varchar(50) PRIMARY KEY REFERENCES Famiglia
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE OR REPLACE TABLE Clima (
    nome varchar(50) PRIMARY KEY
);

CREATE OR REPLACE TABLE PuoStare (
    clima varchar(50) REFERENCES Clima
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    sensibile_al_clima varchar(50) REFERENCES SensibileAlClima
        ON DELETE CASCADE -- Aggiungere trigger per controllare che ci siana almeno un elemento
        ON UPDATE CASCADE,
    PRIMARY KEY (clima, sensibile_al_clima)
);

CREATE OR REPLACE TABLE Posizione (
    codice char(5) PRIMARY KEY,
    clima varchar(50) REFERENCES Clima 
        ON DELETE RESTRICT
        ON UPDATE CASCADE
        NOT NULL,
    nome varchar(50),
    coordinate COORDINATE UNIQUE
);

CREATE OR REPLACE TABLE Pianta (
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

CREATE OR REPLACE TABLE Giardiniere (
    cf char(16) PRIMARY KEY,
    nome varchar(50) NOT NULL,
    cognome varchar(50) NOT NULL
);

CREATE OR REPLACE TABLE EResponsabile (
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

CREATE OR REPLACE TABLE Orario (
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giorno_della_settimana, ora_inizio, ora_fine)
);

CREATE OR REPLACE TABLE Lavora (
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

CREATE OR REPLACE TABLE GP (
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

-- Aggiornamento dell'attributo max_id di Genere



-- Aggiornamento della relazione GP

-- Controllo vincolo principale
