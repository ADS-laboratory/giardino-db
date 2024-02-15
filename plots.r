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
        # get the number of hours worked in the current hour
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

# create matrix from dataframe x: ora, y: giorno della settimana, value: ore di lavoro
mat <- matrix(lavoro_settimanale$ore_lavoro, nrow=length(unique(lavoro_settimanale$giorno_della_settimana)), ncol=length(unique(lavoro_settimanale$ora)))

png(file="plots_results/heatmap1.png")
heatmap(mat, Rowv=NA, Colv=NA, labRow=unique(lavoro_settimanale$giorno_della_settimana), labCol=unique(lavoro_settimanale$ora), main="Ore di lavoro per giorno della settimana", xlab="Ora del giorno", ylab="Giorno della settimana")
dev.off()

# Strip chart, x: famiglie, y: numero giardinieri per genere

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

