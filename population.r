library("RPostgreSQL")

drv <- dbDriver("PostgreSQL")

con <- dbConnect(drv, dbname=readline("Database name: "))

dbGetQuery(con, "SET search_path TO Giardino;")