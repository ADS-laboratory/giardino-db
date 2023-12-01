
CREATE schema Giardino;

CREATE domain Giardino.COORDINATE AS REAL[2] 
    CONSTRAINT latitudine CHECK (value[0] >= -90 and value[0] <= 90)
    CONSTRAINT longitudine CHECK (value[1] >= -180 and value[1] <= 180)
    CONSTRAINT not_null CHECK (value[0] IS NOT NULL AND value[1] IS NOT NULL);


CREATE TABLE Giardino.Famiglia (
    nome varchar(50) PRIMARY KEY,
    descrizione varchar(1000)
);

CREATE TABLE Giardino.Genere (
    nome varchar(50) PRIMARY KEY,
    famiglia varchar(50) REFERENCES Giardino.Famiglia NOT NULL
);

CREATE TABLE Giardino.SensibileAlClima (
    famiglia varchar(50) PRIMARY KEY REFERENCES Giardino.Famiglia
);

CREATE TABLE Giardino.Clima (
    nome varchar(50) PRIMARY KEY
);

CREATE TABLE Giardino.PuòStare (
    clima varchar(50) REFERENCES Giardino.Clima,
    sensibile_al_clima varchar(50) REFERENCES Giardino.SensibileAlClima,
    PRIMARY KEY (clima, sensibile_al_clima)
);

CREATE TABLE Giardino.Posizione (
    codice char(5) PRIMARY KEY,
    clima varchar(50) REFERENCES Giardino.Clima NOT NULL,
    nome varchar(50),
    coordinate Giardino.COORDINATE UNIQUE
);

CREATE TABLE Giardino.Pianta (
    numero integer,
    genere varchar(50) REFERENCES Giardino.Genere NOT NULL,
    posizione char(5) REFERENCES Giardino.Posizione,
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
    giardiniere char(16) REFERENCES Giardino.Giardiniere(cf),
    PRIMARY KEY (numero_pianta, genere_pianta, giardiniere),
    FOREIGN KEY (numero_pianta, genere_pianta) REFERENCES Giardino.Pianta
);  

CREATE TABLE Giardino.Orario (
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giorno_della_settimana, ora_inizio, ora_fine)
);

CREATE TABLE Giardino.Lavora (
    giardiniere char(16) REFERENCES Giardino.Giardiniere(cf),
    giorno_della_settimana smallint,
    ora_inizio time,
    ora_fine time,
    PRIMARY KEY (giardiniere, giorno_della_settimana, ora_inizio, ora_fine),
    FOREIGN KEY (giorno_della_settimana, ora_inizio, ora_fine) REFERENCES Giardino.Orario
);