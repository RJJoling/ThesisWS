# Main script for determining Residence and Workplace from BAG data
# Copyright (C) 2016 William Schuch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Check for required packages and install them (incl dependencies) if they are not installed yet.
list.of.packages <- c("data.table","fossil", "geosphere", "sp", "rgdal")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load the packages
library(data.table)
library(sp)
library(rgdal)
library(geosphere)
library(fossil)

library(foreign)

## Clear the workspace
#rm(list = ls()) 

getwd()
setwd("C:/NLExtract/src")

zip_in = file.path("data", "bag-adressen-laatst.csv.zip")
unzip(zip_in, exdir= file.path("data"))

csv_in = file.path("data", "bagadres.csv")
csv_out = file.path("output", "bagadres_ProvincieUtrecht.csv")

Gjson_out_name = "Residence_Workplace"
Gjson_out_ext = ".geojson"
Gjson_out = file.path("output", Gjson_out_name)
Shape_out = file.path("output", "BAGadres_ProvincieUtrecht.shp")

dbf_in = file.path("data", "verblijfsobjectgebruiksdoel.dbf")

require(data.table)
BAG = fread(csv_in, sep=";", header=TRUE, integer64 = "numeric") # this will take about 5 minutes.
#file.remove(csv_in)

# Make a subset of BAG addresses
BAG_sub = subset(BAG, provincie=="Utrecht")

# Drop the useless attributes
drops = c("gemeente","provincie","object_type","lon","lat","huisnummertoevoeging","nevenadres")
SUB1 = BAG_sub[ , !(names(BAG_sub) %in% drops)]
BAG_subbed = subset(BAG_sub, select = SUB1)

#BAG_subbed$object_id_C = as.character(BAG_subbed$object_id)

# Read the database file with "Gebruiksdoelen" Goal of Use
BAG_Doel = read.dbf(dbf_in) #as.is=FALSE       # this will take about 10 minutes.

# Subset of 1st element and dbf element
BAG_Doel = BAG_Doel[1]$dbf

#drops_dbf = c("AANDUIDING","AANDUID_01","BEGINDATUM","EINDDATUMT")
keeps_dbf = c("IDENTIFICA","GEBRUIKSDO")

BAG_Doel_sub = subset(BAG_Doel, select=keeps_dbf)

colnames(BAG_Doel_sub)[1] <- "object_id"
#BAG_Doel_sub$object_id_chr = as.character(BAG_Doel_sub$object_id)

BAG_subbed_Doel = merge(BAG_Doel_sub, BAG_subbed, by="object_id", duplicateGeoms=TRUE)

BAG_subbed_Doel_copy = BAG_subbed_Doel
BAG_subbed_Doel_copy = BAG_subbed_Doel[!duplicated(BAG_subbed_Doel),]

BAG_subbed_Doel_SPDF = BAG_subbed_Doel_copy
coordinates(BAG_subbed_Doel_SPDF)<-~x+y

# Set Coordinate Reference System (CRS)
#RD_new = "+proj=sterea +lat_0=52.15616055555555 +lon_0=5.38763888888889 +k=0.9999079 +x_0=155000 +y_0=463000 +ellps=bessel +units=m +no_defs"
RD_new = "+init=epsg:28992"
BAG_subbed_Doel_SPDF@proj4string = CRS(RD_new)

#system.time(OUT =  write.csv2(WS2, file = csv_out) ) # Europe , sep
#system.time(OUT =  write.csv(WS2, file = csv_out) ) # USA/UK . sep

# Subset: only residence
Residence = subset(BAG_subbed_Doel_SPDF, BAG_subbed_Doel_SPDF@data$GEBRUIKSDO == "woonfunctie")

# Pick 50 random redidence object_id
RandObj_Re = sample(Residence@data$object_id, 50)

keeps_RS_Re = RandObj_Re
Residence_KEEPS = Residence@data$object_id %in% keeps_RS_Re
Residence_subbed = subset(Residence, Residence_KEEPS)
plot(Residence_subbed)

# Subset: only office
Workplace = subset(BAG_subbed_Doel_SPDF, BAG_subbed_Doel_SPDF@data$GEBRUIKSDO == "kantoorfunctie")

# Pick 50 random offices object_id
RandObj_Of = sample(Workplace@data$object_id, 200)

keeps_RS_Of = RandObj_Of
Workplace_KEEPS = Workplace@data$object_id %in% keeps_RS_Of
Workplace_subbed = subset(Workplace, Workplace_KEEPS)

# Visualisation & point highlighting
plot(Workplace_subbed)
points(Workplace_subbed[12,], col="red" )
points(Residence_subbed[4,], col="blue" )

# binden
#Gebonden = rbind(Residence_subbed,Workplace_subbed)

# Calculate distance by matrix

library(rgeos)
library(maptools)

#DIST_GEO = as.matrix(gDistance(Residence_subbed[1:20,],Workplace_subbed[1:20,]))

# Create distance matrix
DIST_GEO = matrix(data=NA, nrow=length(Residence_subbed), ncol=length(Workplace_subbed))
for (z in seq(1, length(Residence_subbed), by=1))
  {
    for (w in seq(1, length(Workplace_subbed), by=1))
    {
      DIST_GEO[z,w] = gDistance(Residence_subbed[z,],Workplace_subbed[w,]) #[Residence,Workplace]
    }
  }

## Select pair, based on prob distribution of commuting distance (CD)

# prob distribution of CD
prob_CD = rnorm(1000, mean=28000, sd=20000)
hist(prob_CD, probability=TRUE)
#CD = seq(min(prob_CD), max(prob_CD), length=28)
#lines(CD, dnorm(CD, mean=28000, sd=10000))

# Extract the pair numbers Residence~Workplace (ex: 1~24, 2~35) (test group can be collegues)
ResWor=0
for (z in seq(1, length(Residence_subbed), by=1))
  {
    RV = sample(prob_CD, size=1)
    ResWor[z] = which.min(abs(RV-DIST_GEO[z,]))
    
  }

# Giving the pairs to the datasets
Residence_subbed_WS = Residence_subbed
Residence_subbed_WS@data$koppeling = ResWor

# create DF and give koppeling#
Workplace_subbed_DF = Workplace_subbed@data
Workplace_subbed_DF$koppeling = seq(length(Workplace_subbed))

# sort Residence by koppeling
#Residence_subbed_sorted = Residence_subbed_WS[order(Residence_subbed_WS@data$koppeling),]

# Merge two data frames by "koppeling"
#ResWor_pairs = merge(Residence_subbed_sorted,Workplace_subbed_DF, by= "koppeling")
ResWor_pairs = merge(Residence_subbed_WS,Workplace_subbed_DF, by= "koppeling")


#Write to geojson
writeOGR(ResWor_pairs, Gjson_out , Gjson_out_name, driver='GeoJSON')
file.rename(Gjson_out, file.path("output", paste(Gjson_out_name,Gjson_out_ext,sep="")))