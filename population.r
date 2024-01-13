# Connessione al database

library("RPostgreSQL")
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname=readline("Database name: "))
dbGetQuery(con, "SET search_path TO Giardino;")

# Genereazione stringhe casuali

RandomString <- function(n=1, lenght_range=20:100)
{
    randomString <- c(1:n)                  # initialize vector
    for (i in 1:n)
    {
        randomString[i] <- paste(sample(c(0:9, letters, LETTERS),
                                 sample(lenght_range, 1),
                                 replace=TRUE),
                                 collapse="")
    }
    return(randomString)
}

# Popolazione tabella Famiglia

famiglie.nome <- readLines("data/famiglie.txt")
famiglie.descrizione <- RandomString(length(famiglie.nome), sample(20:100, length(famiglie.nome), replace=T))
famiglie_df <- data.frame(nome = famiglie.nome, descrizione = famiglie.descrizione)
dbWriteTable(con, name="famiglia", value=famiglie_df, row.names=F)

# Popolazione tabella Genere

generi.nome <- readLines("data/generi.txt")
generi.famiglia <- sample(famiglie.nome, length(generi.nome), replace=T)
generi_df <- data.frame(nome = generi.nome,
                        famiglia = generi.famiglia,
                        max_id = 0)
dbWriteTable(con, name="genere", value=generi_df, row.names=F)

# Popolazioine tabella SensibileAlClima

sensibili_df <- data.frame(famiglia = sample(famiglie.nome, 10, replace=F))
dbWriteTable(con, name="SensibileAlClima", value=sensibili_df, row.names=F)

# Popolazione tabella Clima

v_climi <- readLines("data/climi.txt")
climi_df <- data.frame(nome = v_climi)
dbWriteTable(con, name="Clima", value=climi_df, row.names=F)

# Popolazione tabella PuoStare

# La tabella viene sovrapopolata, vengono eliminati i duplicati
# e quindi vengono selezionati solo 40 record
# TODO: find a better way to do this
puostare.clima <- sample(v_climi, 100, replace=T)
puostare.sensibile <- sample(sensibili_df$famiglia, 100, replace=T)
puostare_df <- unique(data.frame(clima = puostare.clima,
                          sensibile = puostare.sensibile))
puostare_df <- head(puostare_df, 40)
dbWriteTable(con, name="PuoStare", value=puostare_df, row.names=F)

# Popolazione tabella Posizione

posizioni.nome <- readLines("data/posizioni.txt")
posizioni.codice <- RandomString(length(posizioni.nome), 5)
posizioni.clima <- sample(v_climi, 10, replace=T)
posizioni.coordinate <- #TODO
dbWriteTable(con, name="Posizione", value=posizioni, row.names=F)

# Popolazione tabella Pianta

# Popolazione tabella Giardiniere

# Poplazione tabella EResponsabile

# Popolazione tabella Orario

# Popolazione tabella Lavora

# Popolazione tabella GP
