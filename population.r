# Set the seed
set.seed(1234)

# Connessione al database

library("RPostgreSQL")
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname=readline("Database name: "))
dbGetQuery(con, "SET search_path TO Giardino;")

# Genereazione stringhe casuali

RandomString <- function(n=1, lenght_range=20:100)
{
    randomString <- c(1:n)
    for (i in 1:n)
    {
        if (length(lenght_range) == 1)
            lenght_range <- c(lenght_range, lenght_range)
        randomString[i] <- paste(sample(c(0:9, letters, LETTERS),
                                 sample(lenght_range, 1),
                                 replace=TRUE),
                                 collapse="")
    }
    return(randomString)
}

# Popolazione tabella Famiglia

famiglie.nome <- readLines("data/famiglie.txt")
# La descrizione è una stringa casuale di lunghezza casuale tra 20 e 100
famiglie.descrizione <- RandomString(length(famiglie.nome), sample(20:100, length(famiglie.nome), replace=T))
famiglie_df <- data.frame(nome = famiglie.nome, descrizione = famiglie.descrizione)
dbWriteTable(con, name="famiglia", value=famiglie_df, row.names=F, append=T)

# Popolazione tabella Genere

generi.nome <- readLines("data/generi.txt")
generi.famiglia <- sample(famiglie.nome, length(generi.nome), replace=T)

# partiziona randomicamente il numero di piante per genere
# x è un vettore di lunghezza pari al numero di generi i cui elementi
# se sommati danno il numero di piante
piante_len <- 25000
x <- diff(sort(c(sample(1:piante_len, length(generi.nome)-1), 0, piante_len)))

generi_df <- data.frame(nome = generi.nome,
                        famiglia = generi.famiglia,
                        max_id = x)
dbWriteTable(con, name="genere", value=generi_df, row.names=F, append=T)

# Popolazioine tabella SensibileAlClima

sensibili_len <- 10
sensibili_df <- data.frame(famiglia = sample(famiglie.nome, sensibili_len, replace=F))
dbWriteTable(con, name="sensibilealclima", value=sensibili_df, row.names=F, append=T)

# Popolazione tabella Clima

v_climi <- readLines("data/climi.txt")
climi_df <- data.frame(nome = v_climi)
dbWriteTable(con, name="clima", value=climi_df, row.names=F, append=T)

# Popolazione tabella PuoStare

puostare_len <- 40
# Sovrapopoliamo la tabella in modo tale che dopo aver eliminato i duplicati
# rimangano, in media, il numero di record desiderato
# https://en.wikipedia.org/wiki/Birthday_problem
alph_size0 <- nrow(sensibili_df) * nrow(climi_df)
puostare_len_adj <- log(1 - puostare_len / alph_size0 ) / log(1 - 1 / alph_size0)
puostare.clima <- sample(climi_df$nome, puostare_len_adj, replace=T)
puostare.sensibile <- sample(sensibili_df$famiglia, puostare_len_adj, replace=T)
puostare_df <- unique(data.frame(clima = puostare.clima,
                          sensibile_al_clima = puostare.sensibile))
dbWriteTable(con, name="puostare", value=puostare_df, row.names=F, append=T)

# Popolazione tabella Posizione

posizioni_len <- 10
posizioni.nome <- readLines("data/posizioni.txt")
posizioni.codice <- RandomString(length(posizioni.nome), 5)
posizioni.clima <- sample(v_climi, posizioni_len, replace=T)
lat <- runif(posizioni_len, min=-90, max=90)
lon <- runif(posizioni_len, min=-180, max=180)
# The format for arrays in PostgreSQL is "{x,y}"
posizioni.coordinate <- paste("{", lat, ",", lon, "}", sep="")
posizioni_df <- data.frame(nome = posizioni.nome,
                           codice = posizioni.codice,
                           clima = posizioni.clima,
                           coordinate = posizioni.coordinate)
dbWriteTable(con, name="posizione", value=posizioni_df, row.names=F, append=T)

# Popolazione tabella GP

gp <- data.frame(genere=NULL, posizione=NULL)
# Per ogni genere
for (i in 1:nrow(generi_df))
{
    if (generi_df$famiglia[i] %in% sensibili_df$famiglia)
    {
        # se il genere è sensibile al clima, seleziona tutti i climi
        # che può sopportare e quindi seleziona tutte le posizioni
        # che hanno quei climi
        clima <- puostare_df[puostare_df$sensibile == generi_df$famiglia[i],]$clima
        posizioni <- posizioni_df$codice[posizioni_df$clima %in% clima]
    } else {
        # altrimenti seleziona tutte le posizioni
        posizioni <- posizioni_df$codice
    }
    # aggiungi una riga per ogni posizione trovata
    gp <- rbind(gp, data.frame(genere=generi_df$nome[i],
                               posizione=posizioni))
}
dbWriteTable(con, name="gp", value=gp, row.names=F, append=T)

# Popolazione tabella Pianta

piante_df <- data.frame(numero=NULL, genere=NULL, posizione=NULL)
# per ogni genere
for (i in 1:length(generi.nome))
{
    # seleziona una posizione randomica per ogni pianta
    # utilizzando la tabella GP
    posizioni <- sample(gp$posizione[gp$genere == generi_df$nome[i]], x[i], replace=T)

    piante_df <- rbind(piante_df, data.frame(numero=1:x[i],
                                      genere=generi_df$nome[i],
                                      posizione=posizioni))
}
dbWriteTable(con, name="pianta", value=piante_df, row.names=F, append=T)

# Popolazione tabella Giardiniere

# TODO: consider a better CF generation
giardinieri_len <- 30
giardinieri.cf <- RandomString(giardinieri_len, 16)
giardinieri.nome <- sample(readLines("data/nomi.txt"), giardinieri_len, replace=T)
giardinieri.cognome <- sample(readLines("data/cognomi.txt"), giardinieri_len)
giardinieri_df <- data.frame(cf = giardinieri.cf,
                             nome = giardinieri.nome,
                             cognome = giardinieri.cognome)
dbWriteTable(con, name="giardiniere", value=giardinieri_df, row.names=F, append=T)

# Poplazione tabella EResponsabile

e_responsabile_len <- 35000
# Sovrapopoliamo la tabella in modo tale che dopo aver eliminato i duplicati
# rimangano, in media, il numero di record desiderato
# https://en.wikipedia.org/wiki/Birthday_problem
alph_size1 <- nrow(piante_df) * nrow(giardinieri_df)
resp_len_adj <- log(1 - e_responsabile_len / alph_size1 ) / log(1 - 1 / alph_size1)
piante_key <- piante_df[c("numero", "genere")]
e_responsabile.piante <- piante_key[sample(nrow(piante_key), resp_len_adj, replace=T), ]
e_responsabile.giardinieri <- sample(giardinieri_df$cf, resp_len_adj, replace=T)
e_responsabile_df <- data.frame(numero_pianta = e_responsabile.piante$numero,
                                genere_pianta = e_responsabile.piante$genere,
                                giardiniere = e_responsabile.giardinieri)
e_responsabile_df <- unique(e_responsabile_df)

dbWriteTable(con, name="eresponsabile", value=e_responsabile_df, row.names=F, append=T)

# Popolazione tabella Orario

# genero delle date di inizio e fine casuali
orari.inizio <- paste(sample(8:15, 6, replace=T), ":00", sep="")
orari.fine <- paste(sample(16:21, 6, replace=T), ":00", sep="")

# per ogni giorno della settimana assegno tutti gli orari creati in precedenza
orari_df <- data.frame(giorno_della_settimana=NULL, ora_inizio=NULL, ora_fine=NULL)
for (i in 1:7)
{
    orari_df <- rbind(orari_df, data.frame(giorno_della_settimana=i,
                                     ora_inizio=orari.inizio,
                                     ora_fine=orari.fine))
}

dbWriteTable(con, name="orario", value=unique(orari_df), row.names=F, append=T)

# Popolazione tabella Lavora

lavora <- data.frame(giorno_della_settimana=NULL, ora_inizio=NULL, ora_fine=NULL)
for (i in 1:nrow(giardinieri_df))
{
    # Seleziono dai 4 ai 6 giorni della settimana
    giorni <- sample(1:7, sample(4:6, 1), replace=F)

    # Per ogni giorno della settimana selezionato in precedenza prendo un singolo orario
    # e lo aggiungo alla tabella
    for (giorno in giorni)
    {
        orari_giorno <- orari_df[orari_df$giorno_della_settimana == giorno,]
        orario <- orari_giorno[sample(nrow(orari_giorno), 1),]
        lavora <- rbind(lavora, data.frame(giorno_della_settimana=giorno,
                                           ora_inizio=orario$ora_inizio,
                                           ora_fine=orario$ora_fine,
                                           giardiniere=giardinieri_df$cf[i]))
    }
}
dbWriteTable(con, name="lavora", value=lavora, row.names=F, append=T)
