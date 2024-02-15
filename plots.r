# Set the seed
set.seed(4321234)

# Connessione al database

library("RPostgreSQL")
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname=readline("Database name: "))
dbGetQuery(con, "SET search_path TO Giardino;")


lavora <- dbGetQuery(con, "SELECT giorno_della_settimana, ora_inizio, ora_fine FROM Lavora;")

# Orari di inizio e fine lavoro in ore
lavora$ora_inizio <- as.POSIXlt(lavora$ora_inizio, format="%H:%M:%S")
lavora$ora_inizio <- lavora$ora_inizio$hour + lavora$ora_inizio$min/60
lavora$ora_fine <- as.POSIXlt(lavora$ora_fine, format="%H:%M:%S")
lavora$ora_fine <- lavora$ora_fine$hour + lavora$ora_fine$min/60

# Per ogni ora, calcola il numero di ore complessive di lavoro
num_giorni_settimana <- length(unique(lavora$giorno_della_settimana))
ore <- c(0:23)
lavoro_settimanale <- data.frame(ora = NULL, giorno_della_settimana = NULL, ore_lavoro = NULL)
for (i in 1:length(ore))
{
    for (j in 1:num_giorni_settimana)
    {
        # trova il numero di ore lavorate nell'ora corrente
        rows <- lavora[lavora$ora_fine > ore[i] & lavora$ora_inizio <= ore[i] & lavora$giorno_della_settimana == j,]
        ore_lavoro <- sum(pmin(rows$ora_fine, ore[i] + 1) - pmax(rows$ora_inizio, ore[i]))
        lavoro_settimanale <- rbind(lavoro_settimanale, data.frame(ora = ore[i], giorno_della_settimana = j, ore_lavoro = ore_lavoro))
    }
    # Elimina le ore in cui non si lavora per nessun giorno della settimana
    if (sum(lavoro_settimanale[lavoro_settimanale$ora == ore[i],]$ore_lavoro) == 0)
        lavoro_settimanale <- lavoro_settimanale[lavoro_settimanale$ora != ore[i],]
}


# Plot
png(file="plots_results/box1.png")
stripchart(ore_lavoro ~ ora, data=lavoro_settimanale, vertical=T, method="jitter", xlab="Ora del giorno", ylab="Ore cumulative", main="Ore cumulative di lavoro per giorno della settimana")
dev.off()

# Crea la matrice dal dataframe x: ora, y: giorno della settimana, value: ore di lavoro
mat <- matrix(lavoro_settimanale$ore_lavoro, nrow=length(unique(lavoro_settimanale$giorno_della_settimana)), ncol=length(unique(lavoro_settimanale$ora)))

png(file="plots_results/heatmap1.png")
heatmap(mat, Rowv=NA, Colv=NA, labRow=unique(lavoro_settimanale$giorno_della_settimana), labCol=unique(lavoro_settimanale$ora), main="Ore di lavoro per giorno della settimana", xlab="Ora del giorno", ylab="Giorno della settimana")
dev.off()

# Strip chart, x: famiglie, y: numero giardinieri per genere

# Query, ritorna il numero di giardinieri che sono responsabili di piante con un certo genere
num_giardinieri <- dbGetQuery(con, 
"SELECT famiglia, genere, count
FROM genere JOIN
    (SELECT genere, count(distinct(giardiniere))
    FROM pianta JOIN eresponsabile ON numero_pianta = numero AND genere_pianta = genere
    GROUP BY genere)
    AS A ON nome = A.genere")
# Plot
png(file="plots_results/box2.png", width=800, height=600)
par( mar=c(10, 5, 4, 3))
boxplot(count ~ famiglia, data=num_giardinieri, xlab = "", ylab="Giardinieri per genere", main="Numerero di giardinieri per genere", las=2)
dev.off()

# Scatter plot, x: numero piante di cui è responsabile un giardiniere, y: le ore di lavore del giardiniere

# Funzione per convertire hh:mm:ss in decimali
hhmmss2dec <- function(x) {
  xlist <- unlist(strsplit(x,split=":"))
  h <- as.numeric(xlist[1])
  m <- as.numeric(xlist[2])
  s <- as.numeric(xlist[3])
  xdec <- h+(m/60)+(s/60/60)
  return(xdec)
}

# Query, ritorna i giardinieri con il numero di ore di lavoro e il numero di piante di cui sono responsabili
giardinieri1 <- dbGetQuery(con, 
"SELECT numero_ore.giardiniere, ore_totali, numero_piante 
FROM
    (SELECT giardiniere, SUM(ora_fine - ora_inizio) AS ore_totali
    FROM Lavora
    GROUP BY giardiniere) AS numero_ore JOIN
    (SELECT giardiniere, count(*) as numero_piante
    FROM EResponsabile
    GROUP BY giardiniere) AS numero_piante 
    ON numero_ore.giardiniere = numero_piante.giardiniere;")

giardinieri1$ore_totali <- lapply(giardinieri1$ore_totali, hhmmss2dec)
png(file="plots_results/scatterplot1.png", width=800, height=600)
plot(giardinieri1$numero_piante, giardinieri1$ore_totali, xlab="Numero di piante", ylab="Ore di lavoro per pianta", main="Ore di lavoro per pianta per giardiniere", las=2)
dev.off()

