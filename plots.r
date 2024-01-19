# Set the seed
set.seed(1234)

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
df <- data.frame(ora = NULL, giorno_della_settimana = NULL, ore_lavoro = NULL)
for (i in 1:length(ore))
{
    for (j in 1:num_giorni_settimana)
    {
        # get the number of hours worked in the current hour
        rows <- lavora[lavora$ora_fine > ore[i] & lavora$ora_inizio <= ore[i] & lavora$giorno_della_settimana == j,]
        ore_lavoro <- sum(pmin(rows$ora_fine, ore[i] + 1) - pmax(rows$ora_inizio, ore[i]))
        df <- rbind(df, data.frame(ora = ore[i], giorno_della_settimana = j, ore_lavoro = ore_lavoro))
    }
    # Elimina le ore in cui non si lavora per nessun giorno della settimana
    if (sum(df[df$ora == ore[i],]$ore_lavoro) == 0)
        df <- df[df$ora != ore[i],]
}


# Plot
png(file="plots_results/box1.png")
boxplot(ore_lavoro ~ ora, data=df, xlab="Ora del giorno", ylab="Giardinieri", main="Ore di lavoro per giorno della settimana", range="0")
dev.off()

# create matrix from dataframe x: ora, y: giorno della settimana, value: ore di lavoro
mat <- matrix(df$ore_lavoro, nrow=length(unique(df$giorno_della_settimana)), ncol=length(unique(df$ora)))

png(file="plots_results/heatmap1.png")
heatmap(mat, Rowv=NA, Colv=NA, labRow=unique(df$giorno_della_settimana), labCol=unique(df$ora), main="Ore di lavoro per giorno della settimana", xlab="Ora del giorno", ylab="Giorno della settimana")
dev.off()

# Strip chart, x: famiglie, y: numero giardinieri per genere

