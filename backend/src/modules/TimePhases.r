# Module for creating time phases data frame.
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
# list.of.packages <- c("rhdf5", "raster")
# new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
# #if(length(new.packages)) install.packages(new.packages)
# if(length(new.packages)) source("http://bioconductor.org/biocLite.R")
# biocLite("rhdf5")

## Load the packages
library(lubridate)

## Set the (4) boundaries of the (5) PPH phases only time. Days are overarching
# 1. leave Residence = 08:00 [fixed]
# 2. arival Workplace = tail(TimeVertex.C1[[i]], n=1) [individual based]
# 3. leave Workplace = 17:00 [fixed]
# 4. arrival Residence = tail(TimeVertex.C2[[i]], n=1) [individual based]


TimePhaser <- function(LeaveR, LeaveW, TimeC1, TimeC2, ...)
{
  
  stagenames = c("Leave.R", "Arrive.W", "Leave.W", "Arrive.R")
  PPH.Phases = data.frame(nr = seq_along(TimeVertex.C1), x2 = NA, x3 = NA, x4 = NA)
  colnames(PPH.Phases) = stagenames
  
  PPH.Phases[1] = format(strptime(LeaveR, format = "%H"), format="%H:%M:%S")
  PPH.Phases[3] = format(strptime(LeaveW, format = "%H"), format="%H:%M:%S")
  
  #as.POSIXct(paste0(Year,"-01-01"), tz = "GMT")
  
  for (i in seq_along(PPH.R))
  {
    PPH.Phases[i,2] = format(tail(TimeVertex.C1[[i]], n=1), format="%H:%M:%S")
    PPH.Phases[i,4] = format(tail(TimeVertex.C2[[i]], n=1), format="%H:%M:%S")
  }
  return(PPH.Phases)
}

TimePhaserList <- function(BusinesDates, PPH.Phases.DateTimes, ...)
{
  PHASES = list()
  for (y in seq_along(BusinesDates)) #
  {
    for (c in seq_along(PPH.Phases.DateTimes))
    {
      for (r in seq_along(PPH.Phases.DateTimes[,1]))
      {
        PPH.Phases.DateTimes[r,c] = BusinesDates[[y]] + hms(PPH.Phases.Times[r,c])
      }
      PPH.Phases.DateTimes[,c] = as.numeric(PPH.Phases.DateTimes[,c])
    }
    PHASES[[y]] = PPH.Phases.DateTimes
  }
  # PHASES[[2]]
  # PHASES[[2]][1,1]
  # as.POSIXct(PHASES[[200]][1,4], origin = "1970-01-01", tz = "GMT") # time format correction
  
  return(PHASES)
}

AtResidenceOrWork <- function(ResOrWor, PHASES, BusinesDates, Correct, ...)
{
  TIME.R = list()
  TIME.W = list()
  for (y in seq_along(BusinesDates))
  {
    for (i in seq_along(PHASES[[y]][,1]))
    {
      RES1 = as.POSIXct(PHASES[[y]][i,1], origin = "1970-01-01", tz = "GMT") # incl. time format correction
      
      RES2 = as.POSIXct(PHASES[[y]][i,4], origin = "1970-01-01", tz = "GMT") # incl. time format correction
      CEI.R2 = ceiling_date(RES2, unit = "hours")
      
      WOR1 = as.POSIXct(PHASES[[y]][i,2], origin = "1970-01-01", tz = "GMT") # incl. time format correction
      CEI.W = ceiling_date(WOR1, unit = "hours")
      
      WOR2 = as.POSIXct(PHASES[[y]][i,3], origin = "1970-01-01", tz = "GMT") # incl. time format correction
    }
    
    RESWS1 = seq(BusinesDates[y], to = RES1 - 1*60**2, by = 1*60**2)
    RESWS2 = seq(CEI.R2, to = (BusinesDates[y]+1*60**2*24) - 1*60**2, by = 1*60**2)
    
    WORWS = seq(CEI.W, to = WOR2, by = 1*60**2)
    
    TIME.R[[y]]= c(RESWS1,RESWS2)
    TIME.W[[y]]= c(WORWS)
    
    if (Correct==T)
    {
      # check for weird systematic +1 and +2 error and correct it (day begins at 00:00:00, not at 01:00:00)
      corr = as.numeric(format(TIME.R[[y]][1], format="%H"))
      TIME.R[[y]] = TIME.R[[y]] - corr*60**2
      
      corr = as.numeric(format(TIME.W[[y]][1], format="%H"))
      TIME.W[[y]] = TIME.W[[y]] - corr*60**2 
    }

  }
  if (ResOrWor == "Residence")
  {
    return(TIME.R)
  }
  if (ResOrWor == "Workplace")
  {
    return(TIME.W)
  }
}