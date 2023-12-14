
CREATE schema Giardino;

-- DEFINIZIONE DEI DOMINI

-- Definizione del dominio COORDINATE
CREATE domain Giardino.COORDINATE AS REAL[2] 
    CONSTRAINT latitudine CHECK (value[0] >= -90 and value[0] <= 90)
    CONSTRAINT longitudine CHECK (value[1] >= -180 and value[1] <= 180)
    CONSTRAINT not_null CHECK (value[0] IS NOT NULL AND value[1] IS NOT NULL);

-- DEFINIZIONE DELLE TABELLE

CREATE TABLE Giardino.Famiglia (
    nome varchar(50) PRIMARY KEY,
    descrizione varchar(1000)
);

CREATE TABLE Giardino.Genere (
    nome varchar(50) PRIMARY KEY,
    famiglia varchar(50) REFERENCES Giardino.Famiglia
        NOT NULL
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE Giardino.SensibileAlClima (
    famiglia varchar(50) PRIMARY KEY REFERENCES Giardino.Famiglia
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE Giardino.Clima (
    nome varchar(50) PRIMARY KEY
);

CREATE TABLE Giardino.PuòStare (
    clima varchar(50) REFERENCES Giardino.Clima
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    sensibile_al_clima varchar(50) REFERENCES Giardino.SensibileAlClima
        ON DELETE CASCADE -- Aggiungere trigger per controllare che ci siana almeno un elemento
        ON UPDATE CASCADE,
    PRIMARY KEY (clima, sensibile_al_clima)
);

CREATE TABLE Giardino.Posizione (
    codice char(5) PRIMARY KEY,
    clima varchar(50) REFERENCES Giardino.Clima 
        NOT NULL
        ON DELETE RESTRICT,
        ON UPDATE CASCADE,
    nome varchar(50),
    coordinate Giardino.COORDINATE UNIQUE
);

CREATE TABLE Giardino.Pianta (
    numero integer,
    genere varchar(50) REFERENCES Giardino.Genere 
        NOT NULL
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    posizione char(5) REFERENCES Giardino.Posizione
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    PRIMARY KEY (numero, genere)
);

CREATE TABLE Giardino.Giardiniere (
    cf char(16) PRIMARY KEY,
    nome varchar(50) NOT NULL,
    cognome varchar(50) NOT NULL
);

CREATE TABLE Giardino.ÈResponsabile (
    numero_pianta integer,
    genere_pianta varchar(50),
    giardiniere char(16) REFERENCES Giardino.Giardiniere(cf)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    PRIMARY KEY (numero_pianta, genere_pianta, giardiniere),
    FOREIGN KEY (numero_pianta, genere_pianta) REFERENCES Giardino.Pianta
        ON DELETE CASCADE
        ON UPDATE CASCADE
);  

CREATE TABLE Giardino.Orario (
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giorno_della_settimana, ora_inizio, ora_fine)
);

CREATE TABLE Giardino.Lavora (
    giardiniere char(16) REFERENCES Giardino.Giardiniere(cf),
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giardiniere, giorno_della_settimana, ora_inizio, ora_fine),
    FOREIGN KEY (giorno_della_settimana, ora_inizio, ora_fine) REFERENCES Giardino.Orario
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- DEFINIZIONE DELLE FUNZIONI E DEI TRIGGER

-- controllo che un giardiniere abbia almeno un orario
CREATE OR REPLACE FUNCTION Giardino.check_orario_giardiniere()
RETURNS TRIGGER LENGUAGE plpgsql AS 
$$
    DECLARE
        count integer;
    BEGIN
        SELECT COUNT(*) INTO count
        FROM Giardino.Lavora
        WHERE OLD.giardiniere = giardiniere
        IF count <= 1 THEN
            RAISE EXCEPTION 'Un giardiniere deve avere almeno un orario';
        END IF;
        RETURN OLD;
    END;
$$;

-- controllo che un giardiniere abbia almeno un orario
CREATE TRIGGER check_orario_giardiniere
BEFORE DELETE ON Giardino.Lavora
FOR EACH ROW
EXECUTE PROCEDURE Giardino.check_orario_giardiniere();

-- controllo che una famiglia sensibile al clima abbia almeno un clima a cui è sensibile
CREATE OR REPLACE FUNCTION Giardino.check_sensibile_al_clima()
RETURNS TRIGGER LENGUAGE plpgsql AS
$$
    DECLARE
        count integer;
    BEGIN
        SELECT COUNT(*) INTO count
        FROM Giardino.PuòStare
        WHERE OLD.famiglia = sensibile_al_clima
        IF count <= 1 THEN
            RAISE EXCEPTION 'Una famiglia sensibile al clima deve avere almeno un clima a cui è sensibile';
        END IF;
        RETURN OLD;
    END;
$$;

-- controllo che una famiglia sensibile al clima abbia almeno un clima a cui è sensibile
CREATE TRIGGER check_sensibile_al_clima
BEFORE DELETE ON Giardino.PuòStare
FOR EACH ROW
EXECUTE PROCEDURE Giardino.check_sensibile_al_clima();
