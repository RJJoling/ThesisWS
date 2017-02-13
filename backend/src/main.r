# Main script for determining Primary (residence), Secondary (workplace) and
# Transport routes from BAG data to combine these with air quality data NO2 and
# PM2.5.
# Copyright (C) 2017 William Schuch
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

## TESTED ON WINDOWS 7 (64-bit), 4GB RAM, R v3.3.2, Timezone CET

## TODO:  - ...
##        - ...
##        - Improve SummaryStatistics for profile and phase type comparison.
##        - ?More residential profiles than "Office worker", "Home Office" and "School Pupil".
##        - Simplify "full" OSRM method, based on duration.
##        - ?Introduce "spacetime" package and test is.
##        - Download input data from cloud server (Google Drive or Dropbox).
##        - Documentation

## Note 1: This script only brings different modules in modules/ together.
## No code belonging to one of the modules should go here.

## Note 2: It is expected that the working directory is set to backend/src/

## TERMS:
## PPH: Personal Place History
## CT: Conversion Table, which is used for closest measuring point (Location IDs).

#### Import modules ####

#source("modules/input.r")
source("modules/SaveAsFile.r")
source("modules/DetermineRoutes.r")
source("modules/ConversionTable.r")
source("modules/PersonalLocationToLocationID.r")
source("modules/LinkPointsToTime.r")
source("modules/HourOfTheYear.r")
source("modules/ReadIDF5files.r")
source("modules/TimePhases.r")
source("modules/IncludeWeekends.r")
source("modules/SecondaryRelation.r")
source("modules/DBFreader.r")
source("modules/SummaryStatistics.r")

#source("modules/WeightCR.r")
#source("modules/RGBtoSingleBand.r")
#source("modules/TimeDifferenceCalculation.r")
#source("modules/CumulativeExposure.r")

rm(list.of.packages, new.packages)

## Download data from cloud service (Dropbox)

install.packages('rdrop2')
library(rdrop2)
drop_auth()

Dropbox.dir = file.path("..", "data", "Dropbox")
if (!dir.exists(Dropbox.dir))
{
  dir.create(Dropbox.dir)
}

CRAB_Adressenlijst_in = "CRAB_Adressenlijst_DropboxTest.zip"

if (!file.exists(Dropbox.dir) & !file.exists(shp_in))
{
  stop(paste("CRAB addresses not found (.shp)"))
}
if (!file.exists(shp_in))
{
  unzip(zip_in, exdir= file.path("..", "data", "BE_FL"))
}

drop_get("ThesisWS/data/CRAB_Adressenlijst.zip", file.path(Dropbox.dir, CRAB_Adressenlijst))

https://dl.dropboxusercontent.com/u/56774223/ThesisWS/data/CRAB_Adressenlijst.zip

## Google Drive

https://drive.google.com/open?id=0B5dbtjRcWbwiMFNLTUZRNGhWbWs

#### FLANDERS ####

### General ###
# Use the official address database of Flanders and add the correct attribute 'Goal of use'

Subset.Gemeente = c("Gent","Antwerpen") # empty = "" = no subset = all municipalities | c("Gent","Antwerpen")
Names = paste(Subset.Gemeente, collapse="_")
Name = paste("CRAB_Doel", Names, sep = "_")

if (file.exists(file.path("..", "output", paste0("CRAB_Doel_",Names,".shp"))))
{
  CRAB_Doel = readOGR(file.path("..", "output", paste0(Name,".shp")), layer = Name) # Bug in .geojson, read .shp
} else
{
  if (Subset.Gemeente == "")
  {
    CRAB_Doel = DetermineAddressGoals_FL(2)
  } else
  {
    CRAB_Doel = DetermineAddressGoals_FL(Subset.Gemeente,2)
  }
  SaveAsFile(CRAB_Doel, Name, "Shapefile", TRUE) #"GeoJSON"
}

## 

# Residential-Behavourial types
FL01_OfficeWorker = "01.OW"
FL02_HomeOffice = "02.HO"
FL03_SchoolPupil = "03.SP"
FL04_XXXX = "04.XX"
FL05_XXXX = "05.XX"

Active.Type = FL03_SchoolPupil

OSRM.Level = "simplified" # "simplified" or "full" version of vectors in routes (OSRM package)

dir.P = file.path("..", "output", paste0(Active.Type,"_Primary_",Names,".geojson"))

if (Active.Type != "02.HO")
{
  dir.T1s = file.path("..", "output", paste0(Active.Type,"_TransportOutwards_",Names,"_s", ".geojson"))
  dir.T2s = file.path("..", "output", paste0(Active.Type,"_TransportInwards_",Names,"_s", ".geojson"))
  
  dir.T1f = file.path("..", "output", paste0(Active.Type,"_TransportOutwards_",Names,"_f", ".geojson"))
  dir.T2f = file.path("..", "output", paste0(Active.Type,"_TransportInwards_",Names,"_f", ".geojson"))
  
  dir.S = file.path("..", "output", paste0(Active.Type,"_Secondary_",Names,".geojson"))
}

if (OSRM.Level != "full" & OSRM.Level != "simplified")
{
  stop(paste("OSRM.Level should be 'full' or 'simplified'."))
}

if (Active.Type == "02.HO")
{
  if (!file.exists(dir.P))
  {
    DeterminePPH_FL(CRAB_Doel, Names, 100, 1000, OSRM.Level, Active.Type)
  }
}else{
  # Check if data already exists. If so, it will not run.
  if (!file.exists(dir.P)&!file.exists(dir.S)&(!file.exists(dir.T1s)|!file.exists(dir.T1f))&(!file.exists(dir.T2s)|!file.exists(dir.T2f)))
  {
    DeterminePPH_FL(CRAB_Doel, Names, 100, 1000, OSRM.Level, Active.Type)
  }
}

data_in = file.path("..", "data", "BE", "ATMOSYS", "atmosys-timeseries_2.data")
#data_in = file.path("H:", "ATMOSYS", "atmosys-timeseries_2.data")

Name = "CT"
if (file.exists(file.path("..", "output", paste0(Name,".shp"))))
{
  CT.SP = readOGR(file.path("..", "output", paste0(Name,".shp")), layer = Name) # Bug in .geojson, read .shp
} else
{
  CT = CreateConversionTable(data_in)
  CT.SP = MakeCTSpatial(CT)
  SaveAsFile(CT.SP, Name, "Shapefile", TRUE) #"GeoJSON"
}

# Set year of pollutant dataset, determine dates and date types (Workdays~Weekends)
year.active = 2009
YearDates = YearDates1(year.active)
BusinesDates = DateType(YearDates,"Workdays")
WeekendDates = DateType(YearDates,"Weekends")

# Read PPH and determine the Location ID corresponding to the pollutant dataset (Spatial ConversionTable = CT.SP)
PPH.P = readOGR(dir.P, layer = 'OGRGeoJSON')
LocationIDs.P = PersonalLocationToLocationID(PPH.P, CT.SP, 1)

if (Active.Type == "01.OW" | Active.Type == "03.SP")
{
  PPH.S = readOGR(dir.S, layer = 'OGRGeoJSON')
  
  if (OSRM.Level == "simplified")
  {
    PPH.T1 = readOGR(dir.T1s, layer = 'OGRGeoJSON')
    PPH.T2 = readOGR(dir.T2s, layer = 'OGRGeoJSON')
  }
  if (OSRM.Level == "full")
  {
    PPH.T1 = readOGR(dir.T1f, layer = 'OGRGeoJSON')
    PPH.T2 = readOGR(dir.T2f, layer = 'OGRGeoJSON')
  }
  
  LocationIDs.S = PersonalLocationToLocationID(PPH.S, CT.SP, 1)
  LocationIDs.T1 = PersonalLocationToLocationID(PPH.T1, CT.SP, 1)
  LocationIDs.T2 = PersonalLocationToLocationID(PPH.T2, CT.SP, 1)
  
  PPH.T1@data$duration = PPH.T1@data$duration * 1.2 # duration correction
  PPH.T2@data$duration = PPH.T2@data$duration * 1.2 # duration correction
  
  Leave.P = 8
  Leave.S = 17
  
  TimeVertex.T1 = LinkPointsToTime.Commuting(PPH.T1, LocationIDs.T1, 2009, Leave.P) # Time of the Transport route vertices Outwards
  TimeVertex.T2 = LinkPointsToTime.Commuting(PPH.T2, LocationIDs.T2, 2009, Leave.S) # Time of the Transport route vertices Inwards
  
  PPH.Phases.Times = TimePhaser(PPH.P,Leave.P, Leave.S, TimeVertex.T1, TimeVertex.T2)
  PPH.Phases.DateTimes = PPH.Phases.Times
  
  PHASES = TimePhaserList(BusinesDates, PPH.Phases.DateTimes)
  as.POSIXct(PHASES[[60]][15,2], origin = "1970-01-01", tz = "CET")
  as.POSIXct(PHASES[[70]][15,1], origin = "1970-01-01", tz = "CET")
  as.POSIXct(PHASES[[70]][15,2], origin = "1970-01-01", tz = "CET")
  
  #PHASES[[200]][1,1] #[[businesday#]][individual,]
  
  Correct = T
  if (Correct == T) # Summertime correction correction (CET vs. CEST | The S can be ignored after this correction)
  {
    PHASES = TimePhaserListC(PHASES, Leave.P, PPH.Phases.Times)
  }
  as.POSIXct(PHASES[[60]][15,2], origin = "1970-01-01", tz = "CET")
  as.POSIXct(PHASES[[70]][15,1], origin = "1970-01-01", tz = "CET")
  as.POSIXct(PHASES[[70]][15,2], origin = "1970-01-01", tz = "CET")
  
  TIME.P = AtPrimaryOrSecondary2("Primary", PHASES, BusinesDates, "Workdays")
  TIME.S = AtPrimaryOrSecondary2("Secondary", PHASES, BusinesDates)
  
  TIMEVertex.T1 = LinkPointsToTime.Commuting2("Outwards", PPH.T1, LocationIDs.T1, PHASES) # Time of the Transport routes vertices Outwards
  TIMEVertex.T2 = LinkPointsToTime.Commuting2("Inwards", PPH.T2, LocationIDs.T2, PHASES) # Time of the Transport routes vertices Inwards
  
  # Weekends
  Include.Weekends = TRUE
  if (Include.Weekends == TRUE)
  {
    TIME.P = IncludeWeekends("Primary", TIME.P, YearDates, BusinesDates, WeekendDates)
    TIME.S = IncludeWeekends("Secondary", TIME.S, YearDates, BusinesDates, WeekendDates)
    TIMEVertex.T1 = IncludeWeekends("T1", TIMEVertex.T1, YearDates, BusinesDates, WeekendDates)
    TIMEVertex.T2 = IncludeWeekends("T2", TIMEVertex.T2, YearDates, BusinesDates, WeekendDates)
  }
  
  # Hours of the year
  HOURS.P = HourOfTheYear4(2009, TIME.P, 0)
  HOURS.S = HourOfTheYear4(2009, TIME.S, 0)
  HOURS.T1 = HourOfTheYear4(2009, TIMEVertex.T1, 0)
  HOURS.T2 = HourOfTheYear4(2009, TIMEVertex.T2, 0)
  HOURS.T1_3d = HourOfTheYear4(2009, TIMEVertex.T1, 3)
  HOURS.T2_3d = HourOfTheYear4(2009, TIMEVertex.T2, 3)
}

if (Active.Type == "02.HO")
{
  #   TIME.P = seq(YearDates[1], tail((YearDates), 1)+1*60**2*24, by = 1*60**2)
  #   length(TIME.P_test)
  #   tail((TIME.P), 2)
  
  Time.P = NULL
  for (d in seq(2, length(YearDates), 1))
  {
    Time.P[[1]] = seq(YearDates[1], YearDates[1]+1*60**2*24, by = 1*60**2)
    Time.P[[d]] = seq(YearDates[d]+1*60**2, YearDates[d]+1*60**2*24, by = 1*60**2)
  }
  
  TIME.P = list()
  for (i in seq_along(PPH.P))
  {
    TIME.P[[i]] = Time.P
  }
  
  Hours.P = HourOfTheYear5(2009, Time.P, 0)
  HOURS.P = HourOfTheYear5(2009, TIME.P, 0)
}

# Write TIME to disk
WriteToDisk = TRUE
if (WriteToDisk == TRUE)
{
  SaveAsDBF(TIME.P, "TIME_P", Active.Type)
  SaveAsDBF(TIME.S, "TIME_S", Active.Type)
  SaveAsDBF(TIMEVertex.T1, "TIME_T1", Active.Type)
  SaveAsDBF(TIMEVertex.T2, "TIME_T2", Active.Type)
}

rm(dir.P, dir.S, dir.T1f, dir.T1s, dir.T2f, dir.T2s)

pol = "no2"
polFile = paste0(pol, "-gzip.hdf5")
h5f_dir = file.path("..", "data", "BE", "ATMOSYS", polFile)
#h5f_dir = file.path("I:", "ATMOSYS", polFile)

## Where the magic happens
ExposureValue.All = ExtractExposureValue.Integral(h5f_dir, LocationIDs.P, LocationIDs.S, LocationIDs.T1, LocationIDs.T2,
                                                  HOURS.P, HOURS.S, HOURS.T1, HOURS.T2)
if (Active.Type == "01.OW")
{
  ExposureValue.P = ExposureValue.All[[1]]
  ExposureValue.S = ExposureValue.All[[2]]
  ExposureValue.T1 = ExposureValue.All[[3]]
  ExposureValue.T2 = ExposureValue.All[[4]]
}

ExposureValue.P[[5]][[200]]
ExposureValue.T1[[1]][[200]]
ExposureValue.T2[[100]][[250]]
ExposureValue.S[[100]][[200]]

# # TOEVOEGEN: Koppeling W aan R, zodat lenght(W)=lenght(R) | When there is a many:1 relation
ExposureValue.S = SecondaryRelation(PPH.P, PPH.S, ExposureValue.S)
ExposureValue.S[[80]][[203]]

## num [1:v] NA -> num NA or logi NA for Transport (T1&T2)
ExposureValue.T1 = NAWeekends(ExposureValue.T1, YearDates, BusinesDates, WeekendDates)
ExposureValue.T2 = NAWeekends(ExposureValue.T2, YearDates, BusinesDates, WeekendDates)

# Write Exposurevalues to disk
SaveAsDBF(ExposureValue.P, "ExposureValue_P", Active.Type)
SaveAsDBF(ExposureValue.S, "ExposureValue_S", Active.Type)
SaveAsDBF(ExposureValue.T1, "ExposureValue_T1", Active.Type)
SaveAsDBF(ExposureValue.T2, "ExposureValue_T2", Active.Type)

ExposureValue.P_backup = ExposureValue.P
rm(ExposureValue.P)

TIME.P.backup = TIME.P
rm(TIME.P)

TIME.S.backup = TIME.S
rm(TIME.S)

#test
test = unlist(unlist(TIME.P)) == unlist(unlist(TIME.P.backup))
FALSE %in% test

#Read DBF file with TIME 
TIME.P = DBFreader("Time", "Primary", PPH.P, YearDates, Active.Type)
TIME.S = DBFreader("Time", "Secondary", PPH.P, YearDates, Active.Type)
TIMEVertex.T1 = DBFreader("Time", "T1", PPH.P, YearDates, Active.Type)
TIMEVertex.T2 = DBFreader("Time", "T2", PPH.P, YearDates, Active.Type)

ExposureValue.P = DBFreader("Exposure", "Primary", PPH.P, YearDates, Active.Type)
ExposureValue.S = DBFreader("Exposure", "Secondary", PPH.P, YearDates, Active.Type)
ExposureValue.T1 = DBFreader("Exposure", "T1", PPH.P, YearDates, Active.Type)
ExposureValue.T2 = DBFreader("Exposure", "T2", PPH.P, YearDates, Active.Type)

#test
test = unlist(unlist(ExposureValue.P)) == unlist(unlist(ExposureValue.P_backup))
test = unlist(unlist(TIME.P)) == unlist(unlist(TIME.P_backup))
FALSE %in% test

# Plotting results
Ind = 86
Plot.PersonalExposureGraph(Ind, 5, 5) # (Individual, Start(working)Day, Amount of days)
Plot.PersonalExposureGraph.P(38, 6, 6)

# Saving plots on hard rive
Plot_dir = file.path("..", "output", "plots")
if (!dir.exists(Plot_dir)) 
{
  dir.create(Plot_dir)
}

png(filename = file.path(Plot_dir, paste(Active.Type, "ExposureValues", "Individual", paste0(Ind, ".png"), sep = "_")),
    width = 1208, height = 720, units = "px", pointsize = 12)

#Remove all, exept...
rm(list=setdiff(ls(), "ExposureValue.All, TIME.P, TIME.S, TIMEVertex.T1, TIMEVertex.T2,
                HOURS.P, HOURS.S, HOURS.T1, HOURS.T2"))




## Summary calculations

# Place weights on Transport vertices
WEIGHTS.T1 = WeightCommutingRouteVertices(HOURS.T1_3d, HOURS.P, Leave.P)
WEIGHTS.T2 = WeightCommutingRouteVertices(HOURS.T2_3d, HOURS.S, Leave.S)

WEIGHTS.T1[[1]]
sum(WEIGHTS.T1[[1]])
tail(HOURS.T1_3d[[1]][[1]], n=1) - HOURS.T1_3d[[1]][[1]][1]



# Mean per day
HO.02.mean. = Weighted.Static(ExposureValue.P, "WeightedMean.Day")

# Mean per year (per individual)
HO.02_1 = mean(HO.02[[1]])
HO.02_2 = mean(HO.02[[2]])


# Mean for all 100 individuals
ExposureValue.P[[1]][[1]] + ExposureValue.P[[2]][[1]]

HourBasedExposure = ExposureValue.P # use same structure
for (d in seq_along(ExposureValue.P[[1]]))
{
  for (i in seq_along(ExposureValue.P))
  {
    for (h in (seq_along(ExposureValue.P[[i]][[d]])))
    {
      HourBasedExposure[[d]][[h]][i] = ExposureValue.P[[i]][[d]][h]
    }
  }
}



#transpose: [[individual]][[day]][hour] -> [[day]][[individual]][hour]
n <- length(ExposureValue.P[[1]]) # assuming all lists in before have the same length
ExposureValue.P.tr = lapply(1:n, function(i) lapply(ExposureValue.P, "[[", i))

#transpose2: [[day]][[individual]][hour] -> [[day]][[hour]][individual]
ExposureValue.P.tr2 = list(list())
for (d in seq_along(ExposureValue.P.tr))
{
  ExposureValue.P.tr2[[d]] = transpose(ExposureValue.P.tr[[d]])
}

# Mean
# ExposureValue.P100 = data.frame()
# for (d in seq_along(ExposureValue.P.tr2))
# {
#   for (h in seq_along(ExposureValue.P.tr2[[d]]))
#   {
#     ExposureValue.P100[d,h] = mean(ExposureValue.P.tr2[[d]][[h]])
#   }
# }

ExposureValue.P100 = ExposureValue.P.tr2
for (d in seq_along(ExposureValue.P.tr2))
{
  for (h in seq_along(ExposureValue.P.tr2[[d]]))
  {
    ExposureValue.P100[[d]][h] = mean(ExposureValue.P.tr2[[d]][[h]])
    #ExposureValue.P100[[d]] = unlist(ExposureValue.P100[[d]])
  }
  ExposureValue.P100[[d]] = unlist(ExposureValue.P100[[d]])
}

TIME.P100 = TIME.P

#Plotting Summary statistics results
Plot.PersonalExposureGraph.P.summary(1, length(ExposureValue.P100)) # whole year
Plot.PersonalExposureGraph.P.summary(1, 7) # first week


Plot.PersonalExposureGraph.P(76,1,7)


# Mean per day
ExposureValue.P100.DailyMean = NA
for (d in seq_along(ExposureValue.P100))
{
  ExposureValue.P100.DailyMean[d] = mean(ExposureValue.P100[[d]])
}

# Mean over the year
ExposureValue.P100.YearlyMean = mean(ExposureValue.P100.DailyMean)

#! Combine the 4 types in OW.01 and calculate mean

#! Include weekends for OW.01 (and SP.03)

## WOON-WERKVERPLAATSING 46.21 km (http://www.mobiliteitsmanagement.be/ndl/woonwerkverkeer/)


## CHECK the ExposureValues. Should give 8761 values? Are these values in the right time?
head(TIME.P[[1]], 2)
head(HOURS.P[[1]], 2)
tail(HOURS.P[[1]], 2)

unlist(TIME.P[[1]]) %in% as.POSIXct("2009-03-29 02:00:00", origin = "1970-01-01", tz = "CET") | 
  unlist(TIME.P[[1]]) %in% as.POSIXct("2009-10-25 02:00:00", origin = "1970-01-01", tz = "CET")

length(unlist(TIME.P[[1]]))
length(unlist(HOURS.P[[1]]))
length(unlist(ExposureValue.P[[1]]))

tail(ExposureValue.P[[1]],1)
head(ExposureValue.P[[1]],2)

tail(ExposureValue.P_01.OW[[1]],1)

H5.active = h5read(h5f_dir, as.character(1))
H5.active$data[HOURS.P[[1]][[365]][25], 7701]
H5.active$data[HOURS.P[[1]][[365]][24], 7701]
H5.active$data[8760, 7701]
DF = data.frame(H5.active)
H5close()

tail(H5.active@data,20)

ExposureValue.P.WM = Weighted.Static(ExposureValue.P, "WeightedMean")
ExposureValue.S.WM = Weighted.Static(ExposureValue.S, "WeightedMean")
ExposureValue.T1.WM = Weighted.Dynamic(ExposureValue.T1, WEIGHTS.T1, "WeightedMean")
ExposureValue.T2.WM = Weighted.Dynamic(ExposureValue.T2, WEIGHTS.T2, "WeightedMean")

for (i in seq_along(ExposureValue.P.WM))
{
  print(paste("Individual", i, ":", mean(ExposureValue.P.WM[[i]]), mean(ExposureValue.S.WM[[i]]), mean(ExposureValue.T1.WM[[i]]), mean(ExposureValue.T2.WM[[i]])))
}

mean(ExposureValue.P.WM[[1]])
mean(ExposureValue.S.WM[[1]])
mean(ExposureValue.T1.WM[[1]])
mean(ExposureValue.T2.WM[[1]])

hist(ExposureValue.P.WM[[99]], breaks = 50)

rm(ExposureValue.T12,ExposureValue.T1.WM, ExposureValue.T2.WM, ExposureValue.P.WM, ExposureValue.S.WM, WEIGHTS.T1, WEIGHTS.T2)


EXP.P.mean = list()
EXP.P.sum = list()
for (i in seq_along(ExposureValue.T1)) # per individual
{
  for (d in seq_along(BusinesDates)) # per day
  {
    #Exp.P.mean = mean(ExposureValue.P[[i]][[d]])
    #Exp.S.mean = mean(ExposureValue.S[[i]][[d]])  
    
    Exp.P.sum[[d]] = sum(ExposureValue.P[[i]][[d]])
    
  }
  
  
  
  #EXP.P.mean[[i]] = Exp.P.mean
  EXP.P.sum[[i]] = Exp.P.sum[[d]]
  
  #   EXP.S[[i]] = 
  #   EXP.C[[i]] = 
  
}
sum(Exp.P.sum)


sum(ExposureValue.T1[[1]][[1]] * WEIGHTS.T1[[1]], na.rm = TRUE)


TEST = TimeDifference(HourOfTheYear4(2009, TIMEVertex.T1, 3))

ExposureValue.T2 = ExtractExposureValue2("no2", LocationIDs.T2, HOURS.T2)



h5f.active_WS = h5read(h5f_dir, as.character(16))
h5f.active_WS$data[HOURS.T1[[5]][[1]][1]+1, 5187]


smoothingSpline = smooth.spline(x=HOURS.T1_3d[[99]][[70]], ExposureValue.T1[[99]][[70]], spar=0.035)
plot(x=HOURS.T1_3d[[99]][[70]], y=ExposureValue.T1[[99]][[70]], ylim=c(0, 100))
lines(smoothingSpline)

plot(x=c(TIMEVertex.T1[[99]][[70]]), y=ExposureValue.T1[[99]][[70]], ylim=c(0, 100))

plot(x=c(TIME.P[[99]][[70]],TIME.S[[99]][[70]],TIMEVertex.T1[[99]][[70]],TIMEVertex.T2[[99]][[70]]),
     y=c(ExposureValue.P[[99]][[70]],ExposureValue.S[[99]][[70]],ExposureValue.T1[[99]][[70]],ExposureValue.T2[[99]][[70]]),
     ylim=c(0, 100))



library(ggplot2)
qplot(HOURS.T1_3d[[2]][[70]],ExposureValue.T1[[2]][[70]], geom='smooth', span =0.5, ylim=c(0, 100))

start.time = Sys.time()

length(HOURS.T1[[15]][[1]])

end.time = Sys.time()
time.taken = end.time - start.time
paste("The script has finished running in", time.taken, "seconds.")

length(ExposureValue.T1[[12]][[1]])


SaveAsFile(CT2, "CT2", "GeoJSON", TRUE)
RESO.BE = CalculateResolution(CT)


#! Use parallel processing

install.packages("rmarkdown")

library(parallel)

mclapply(1:30, rnorm)
# use the same random numbers for all values
set.seed(12345)
mclapply(1:30, rnorm, mc.preschedule=FALSE, mc.set.seed=FALSE)
# something a bit bigger - albeit still useless :P
unlist(mclapply(1:32, function(x) sum(rnorm(1e7))))





#### The Netherlands ####

## Convert RGB images to single band GeoTIFF

#RGBtoSingleBand("20161108_vandaag_no2_03.tiff")
RGB.list = list.files(file.path("..", "data", "RIVM"), pattern = ".tiff" )
for (i in RGB.list)
{
  RGBtoSingleBand(i)
}

## Determine routes
DetermineRoutesNL(c("Utrecht", "Gelderland"), 100, 1000)


# H5close()
# start.time = Sys.time()                    
# ExposureValue.P_ = ExtractExposureValue.Static(h5f_dir, LocationIDs.P, HOURS.P) # LocationIDs.P[1:5]
# end.time = Sys.time()
# time.taken = end.time - start.time
# time.taken # 6.7 min (5,100) # 43.8 min (100) # 47.5 min (100)

# uses a quicker method with hard drive
ExposureValue.P = ExtractExposureValue.Static2(h5f_dir, LocationIDs.P, HOURS.P) # LocationIDs.P[1:5]

start.time = Sys.time()
ExposureValue.S = ExtractExposureValue.Static(h5f_dir, LocationIDs.S, HOURS.S)
end.time = Sys.time()
time.taken = end.time - start.time
time.taken # 11.5 min (5,100)

# Kan sneller wannneer (R,W,) C1 en C2 tegelijk worden berekend:
start.time = Sys.time()
ExposureValue.T12 = ExtractExposureValue.Dynamic3(h5f_dir, LocationIDs.T1, LocationIDs.T2, HOURS.T1, HOURS.T2) # LocationIDs.P[1:5]
end.time = Sys.time()
time.taken = end.time - start.time
time.taken # 25 minutes (15) ,33 minutes (30), 7 hours (100), 1.5 hours (1,100, f), 3.7 hours (5,100,f)

ExposureValue.T1 = ExposureValue.T12[[1]]
ExposureValue.T2 = ExposureValue.T12[[2]]






## Check for required packages and install them (incl dependencies) if they are not installed yet.
list.of.packages = c("data.table","sp","rgdal","foreign","rgeos","osrm", "futile.options", "lambda.r", "sensorweb4R")
new.packages = list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
if(length(new.packages)) devtools::install_github("52North/sensorweb4R") # The sensorweb4R package is not on CRAN yet.


## Load the packages
library(data.table)
library(sp)
library(rgdal)
library(foreign)
library(rgeos)
library(osrm)

library(sensorweb4R)

## Clear the workspace
#rm(list = ls()) 

#getwd()