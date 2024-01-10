library("RPostgreSQL")

drv <- dbDriver("PostgreSQL")

con <- dbConnect(drv, dbname="lezioni_23_24")

dbGetQuery(con, "SET search_path TO studenti;")

v_nomi <- readLines("nomi.txt")

v_cognomi <- readLines("cognomi.txt")

studenti_df <- data.frame(matricola = sample(1:1000000, 10000, replace = F), nome = sample
(v_nomi, 10000, replace = T), cognome = sample (v_cognomi, 10000, replace = T), sesso =
sample(c("m", "f"), 10000, replace = T))

dbWriteTable(con, name="studenti", value=studenti_df, append=T, row.names=F)

temp_cdl <- dbGetQuery(con, "SELECT nome FROM corsi_di_laurea;")
# trasfromo in vettore filtrando sul nome:
temp_cdl <- temp_cdl$nome
iscritto_a.cdl <- sample(temp_cdl, 10000, replace = T)
temp_matricola <- dbGetQuery(con, "SELECT matricola FROM studenti;")
iscritto_a.stud <- temp_matricola$matricola
iscritto_a.anno <- sample(1978:2023, 10000, replace = T)
iscritto_a_df <- data.frame(cdl = iscritto_a.cdl, stud = iscritto_a.stud, anno = iscritto_a.anno)
dbWriteTable(con, name="iscritto_a", value=iscritto_a_df, append=T, row.names=F)

temp_cdl <- dbGetQuery(con, "SELECT nome FROM corsi_di_laurea;")
temp_cdl <- temp_cdl$nome
iscritto_a.cdl <- sample(temp_cdl, 100, replace = T)
temp_matricola <- dbGetQuery(con, "SELECT matricola FROM studenti;")
temp_matricola <- temp_matricola$matricola
iscritto_a.stud <- sample(temp_matricola, 100, replace = T)
iscritto_a.anno <- sample(1978:2023, 100, replace = T)
iscritto_a_df <- data.frame(cdl = iscritto_a.cdl, stud = iscritto_a.stud, anno = iscritto_a.anno)
# prendo quelli già presenti
x <- dbGetQuery(con, "SELECT cdl,stud,anno FROM iscritto_a;")
# sottraggo quelli già presenti da quelli che voglio inserire per evitare violazioni di
# chiave primaria
iscritto_a_df <- data.frame(setdiff(iscritto_a_df, x))
dbWriteTable(con, name="iscritto_a", value=iscritto_a_df, append=T, row.names=F)


# ESEMPI DI PLOT
# Grafico a linea:
# - asse x anni
# - asse y numero di iscritti
df <- dbGetQuery(con, "SELECT anno, COUNT(*) FROM iscritto_a GROUP BY anno;")
plot(df$anno, df$count, type="o", xlab="Anno", ylab="Numero di iscritti", main="Numero di iscritti per anno")

# Grafico a barre:
# - asse x: 3 barre per ogni corso di laurea (uno per anno 1993, 1997, 1999)
# - asse y: numero di iscritti
df <- dbGetQuery(con, "SELECT anno, cdl, COUNT(*) FROM iscritto_a WHERE anno='1993' OR anno='1997' OR anno='1999' GROUP BY anno, cdl ORDER BY anno;")
# Matrice con una colonna per anno:
matr <- matrix(df$count, nrow=length(unique(df$cdl)))
# Aggiungo i nomi dei corsi di laurea:
rownames(matr) <- unique(df$cdl)
# Plotto il grafico a barre:
barplot(matr, beside=T,) #legend.text=unique(df$anno), args.legend=list(x="topright", bty="n"), xlab="Corso di laurea", ylab="Numero di iscritti", main="Numero di iscritti per corso di laurea e anno")

# Grafico a barre con il sesso degli iscritti:
# - asse x: corsi di laurea
# - asse y: numero di iscritti divisi per sesso
df <- dbGetQuery(con, "SELECT cdl, sesso, COUNT(*) FROM studenti JOIN iscritto_a ON matricola=stud GROUP BY cdl, sesso ORDER BY cdl,sesso;")
matr <- matrix(df$count, nrow=2)
rownames(matr) <- c("f", "m")
colnames(matr) <- unique(df$cdl)
barplot(matr)
