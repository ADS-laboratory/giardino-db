library("RPostgreSQL")

drv <- dbDriver("PostgreSQL")

con <- dbConnect(drv, dbname=readline("Database name: "))

dbGetQuery(con, "SET search_path TO Giardino;")

v_famiglie <- readLines("data/famiglie.txt")

RandomString <- function(n=1, lenght=12)
{
    randomString <- c(1:n)                  # initialize vector
    for (i in 1:n)
    {
        randomString[i] <- paste(sample(c(0:9, letters, LETTERS),
                                 lenght, replace=TRUE),
                                 collapse="")
    }
    return(randomString)
}

famiglie_df <- data.frame(nome = v_famiglie , descrizione = RandomString(length(v_famiglie), sample(20:100, 1))

dbWriteTable(con, name="famiglia", value=famiglie_df, append=T, row.names=F)


