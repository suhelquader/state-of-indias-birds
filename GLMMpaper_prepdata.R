## prep data

###################                       PART 1                     ###################################


## initialize and create spatialpolygon and spatialgrid databases from shapefiles
## has to be run only once unless any of these change
## requires R packages tidyverse, rgdal, sp
## district, state and country shapefiles (2011 currently) MUST BE in the working directory
## creates grids at 25, 50, 100, 200 resolutions and lists of 4 and 8 nearest neighbours
## writes 'maps.RData' and 'neighbours.RData' to the home folder (called in other functions)

source('~/GitHub/state-of-indias-birds/SoIB functions.R')
createmaps()

### Sequence of steps to clean data starting from .txt file

## clean the eBird EBD, add some important columns, select only few
## has to be run after every new EBD download
## requires R packages lubridate and tidyverse
## txt data file MUST BE in the working directory
## writes 'indiaspecieslist.csv' (common and scientific names of all species)
## writes 'data.RData' to the home folder

source('~/GitHub/state-of-indias-birds/SoIB functions.R')
readcleanrawdata("ebd_IN_relMay-2019.txt","Sensitive_India_may 2019.csv") 

## add map and grid variables to the dataset (dataframe)
## has to be run after the previous step
## requires R packages tidyverse, data.table, sp and rgeos
## data.RData and maps.RData files MUST BE in the working directory
## writes 'data.RData' to the home folder

source('~/GitHub/state-of-indias-birds/SoIB functions.R')
addmapvars()

## clean up and filter data for analyses
## has to be run after previous step
## requires tidyverse, lubridate
## "indiaspecieslist.csv", "Activity - Activity.csv", "Migratory Status - Migratory Status.csv",
## "Endemicity - Endemicity.csv", "Select Species from List - Select Species from List.csv"
## and data.RData files MUST BE in the home folder
## writes 'dataforanalyses.RData' to the home folder, workspace contains info about
## amount of data in each temporal bin, full species list (with all attribute columns) 
## and selected species list, data

source('~/GitHub/state-of-indias-birds/SoIB functions.R')
dataspeciesfilter(locationlimit = 15,gridlimit = 4)



#########################################################



################################################

rm(list = ls(all.names = TRUE))
library(tidyverse)
source('~/GitHub/state-of-indias-birds/SoIB functions.R')
load("dataforanalyses.RData")

species = specieslist$COMMON.NAME[!is.na(specieslist$ht)]

data = data %>% select(-CATEGORY,-LOCALITY.ID,-ST_NM,-DISTRICT,-REVIEWED,-APPROVED,
                       -LATITUDE,-LONGITUDE,-TIME.OBSERVATIONS.STARTED,-PROTOCOL.TYPE,
                       -day,-cyear)

require(tidyverse)
require(lme4)
require(VGAM)
require(parallel)

data$gridg1 = as.factor(data$gridg1)
data$gridg2 = as.factor(data$gridg2)
data$gridg3 = as.factor(data$gridg3)
data$gridg4 = as.factor(data$gridg4)
data$region = as.factor(data$region)

data = data %>%
  filter(ALL.SPECIES.REPORTED == 1)

data$month = as.factor(data$month)

#data$timegroups = as.factor(data$timegroups)
#data$gridg = data$gridg3

comp = data.frame(type = rep(c("lla","dur","dis"),length(species)),
                  species = rep(species,each = 3))

comp$p = comp$se = comp$est = 0

c = 0

for (i in 1:length(species))
{
  temp = data %>%
    filter(COMMON.NAME == species[i]) %>%
    distinct(gridg3,month)
  data1 = temp %>% left_join(data)
  
  #datay = data1 %>%
  #  group_by(gridg3,gridg1,group.id) %>% slice(1) %>% ungroup %>%
  #  group_by(gridg3,gridg1) %>% summarize(medianlla = median(no.sp)) %>%
  #  group_by(gridg3) %>% summarize(medianlla = mean(medianlla)) %>%
  #  summarize(medianlla = round(mean(medianlla)))
  
  #medianlla = datay$medianlla
  
  ## expand dataframe to include absences as well
  
  ed = expandbyspecies(data1,species[i])
  #tm = unique(data1$timegroups)
  
  ed = ed %>%
    filter(DURATION.MINUTES != 0 & EFFORT.DISTANCE.KM != 0 & !is.na(DURATION.MINUTES) &
             !is.na(EFFORT.DISTANCE.KM))
  
  m1 = glmer(OBSERVATION.COUNT ~ month + log(no.sp) + log(DURATION.MINUTES) + log(EFFORT.DISTANCE.KM) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'cloglog'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a = summary(m1)
  b = a$coefficients
  l = length(a$coefficients[,1])
  
  c = c + 1
  comp$est[c] = b[l-2,1]
  comp$se[c] = b[l-2,2]
  comp$p[c] = b[l-2,4]
  
  c = c + 1
  comp$est[c] = b[l-1,1]
  comp$se[c] = b[l-1,2]
  comp$p[c] = b[l-1,4]
  
  c = c + 1
  comp$est[c] = b[l,1]
  comp$se[c] = b[l,2]
  comp$p[c] = b[l,4]
}

## save model comparison dataframe

## this dataframe 'comp' is saved in an modelcomparison_fulldata.RData file which can then be loaded




############

## prepare Kerala Atlas data

## KL atlas comparison

rm(list = ls(all.names = TRUE))
klpath = "Atlas.csv"
source('~/GitHub/state-of-indias-birds/SoIB functions.R')

require(lubridate)
require(tidyverse)

# select only necessary columns
preimp = c("CATEGORY","COMMON.NAME","SCIENTIFIC.NAME","OBSERVATION.COUNT","STATE",
           "LOCALITY.ID","LOCALITY.TYPE","REVIEWED","APPROVED",
           "LATITUDE","LONGITUDE","OBSERVATION.DATE","TIME.OBSERVATIONS.STARTED","OBSERVER.ID",
           "PROTOCOL.TYPE","DURATION.MINUTES","EFFORT.DISTANCE.KM",
           "NUMBER.OBSERVERS","ALL.SPECIES.REPORTED","GROUP.IDENTIFIER","SAMPLING.EVENT.IDENTIFIER")


rawpath = "ebd_IN_relMay-2019.txt"
sensitivepath = "Sensitive_India_may 2019.csv"

nms = read.delim(rawpath, nrows = 1, sep = "\t", header = T, quote = "", stringsAsFactors = F, 
                 na.strings = c(""," ",NA))
nms = names(nms)
nms[!(nms %in% preimp)] = "NULL"
nms[nms %in% preimp] = NA

# read data from certain columns only
data = read.delim(rawpath, colClasses = nms, sep = "\t", header = T, quote = "", 
                  stringsAsFactors = F, na.strings = c(""," ",NA))

# read sensitive species data
nms = nms[-47]
sesp = read.csv(sensitivepath, colClasses = nms)
stdformat = data.frame(date = as.character(sesp$OBSERVATION.DATE))
stdformat = stdformat %>%
  separate(date, c("month","day","year"), "/")
stdformat$year = as.numeric(stdformat$year)
sesp$OBSERVATION.DATE = paste(stdformat$year,"-",stdformat$month,"-",stdformat$day, sep = "")

# merge both data frames
data = rbind(data,sesp)

data = data %>%
  filter(!COMMON.NAME %in% c("Western Orphean Warbler"))

data = data %>%
  filter(STATE == "Kerala")


imp = c("CATEGORY","COMMON.NAME","OBSERVATION.COUNT",
        "LOCALITY.ID", "REVIEWED","APPROVED","SAMPLING.EVENT.IDENTIFIER",
        #"LOCALITY.TYPE",
        "LATITUDE","LONGITUDE","OBSERVATION.DATE","TIME.OBSERVATIONS.STARTED","OBSERVER.ID",
        "PROTOCOL.TYPE",
        "DURATION.MINUTES","EFFORT.DISTANCE.KM",
        "ALL.SPECIES.REPORTED","group.id")


# no of days in every month, and cumulative number
days = c(31,28,31,30,31,30,31,31,30,31,30,31)
cdays = c(0,31,59,90,120,151,181,212,243,273,304,334)

# create a column "group.id" which can help remove duplicate checklists
data = data %>%
  mutate(group.id = ifelse(is.na(GROUP.IDENTIFIER), SAMPLING.EVENT.IDENTIFIER, GROUP.IDENTIFIER))

data = data %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Green Warbler", "Greenish Warbler")) %>%
  mutate(CATEGORY = replace(CATEGORY, COMMON.NAME == "Green/Greenish Warbler",
                            "species")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Green/Greenish Warbler",
                               "Greenish Warbler")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Hume's Whitethroat", 
                               "Lesser Whitethroat")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Desert Whitethroat", 
                               "Lesser Whitethroat")) %>%
  mutate(CATEGORY = replace(CATEGORY, COMMON.NAME == "Sylvia sp.",
                            "species")) %>%
  mutate(CATEGORY = replace(CATEGORY, COMMON.NAME == "Hume's/Lesser Whitethroat",
                            "species")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Sylvia sp.",
                               "Lesser Whitethroat")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Hume's/Lesser Whitethroat",
                               "Lesser Whitethroat")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Sykes's Short-toed Lark", 
                               "Greater Short-toed Lark")) %>%
  mutate(CATEGORY = replace(CATEGORY, COMMON.NAME == "Greater/Sykes's Short-toed Lark",
                            "species")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Greater/Sykes's Short-toed Lark", 
                               "Greater Short-toed Lark")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Taiga Flycatcher", 
                               "Red-breasted Fycatcher")) %>%
  mutate(CATEGORY = replace(CATEGORY, COMMON.NAME == "Taiga/Red-breasted Flycatcher",
                            "species")) %>%
  mutate(COMMON.NAME = replace(COMMON.NAME, COMMON.NAME == "Taiga/Red-breasted Flycatcher", 
                               "Red-breasted Fycatcher"))

kllists = read.csv(klpath, col.names = F)
kllists[,1] = as.character(kllists[,1])
kllists = do.call(rbind, str_split(kllists[,1], ' '))
kllists = kllists[,3]

dataatlas = data %>% 
  filter(SAMPLING.EVENT.IDENTIFIER %in% kllists)

dataebird = data %>%
  filter(!group.id %in% unique(dataatlas$group.id))

dataatlas = dataatlas %>%
  dplyr::select(imp) %>%
  group_by(group.id,COMMON.NAME) %>% slice(1) %>% ungroup %>%
  mutate(OBSERVATION.DATE = as.Date(OBSERVATION.DATE), 
         month = month(OBSERVATION.DATE),
         day = day(OBSERVATION.DATE) + cdays[month], 
         #week = week(OBSERVATION.DATE),
         #fort = ceiling(day/14),
         cyear = year(OBSERVATION.DATE)) %>%
  dplyr::select(-c("OBSERVATION.DATE")) %>%
  mutate(year = ifelse(day <= 151, cyear-1, cyear)) %>%
  group_by(group.id) %>% mutate(no.sp = n_distinct(COMMON.NAME)) %>%
  ungroup

dataebird = dataebird %>%
  dplyr::select(imp) %>%
  group_by(group.id,COMMON.NAME) %>% slice(1) %>% ungroup %>%
  mutate(OBSERVATION.DATE = as.Date(OBSERVATION.DATE), 
         month = month(OBSERVATION.DATE),
         day = day(OBSERVATION.DATE) + cdays[month], 
         #week = week(OBSERVATION.DATE),
         #fort = ceiling(day/14),
         cyear = year(OBSERVATION.DATE)) %>%
  dplyr::select(-c("OBSERVATION.DATE")) %>%
  mutate(year = ifelse(day <= 151, cyear-1, cyear)) %>%
  group_by(group.id) %>% mutate(no.sp = n_distinct(COMMON.NAME)) %>%
  ungroup

mappath = "maps.RData"

require(data.table)
require(sp)
require(rgeos)


## add map details to eBird data

load(mappath)

# add columns with DISTRICT and ST_NM to main data 

temp = data %>% group_by(group.id) %>% slice(1) # same group ID, same grid/district/state 

rownames(temp) = temp$group.id # only to setup adding the group.id column for the future left_join
coordinates(temp) = ~LONGITUDE + LATITUDE # convert to SPDF?
#proj4string(temp) = "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"
temp = over(temp,districtmap) # returns only ATTRIBUTES of districtmap (DISTRICT and ST_NM)
temp = data.frame(temp) # convert into data frame for left_join
temp$group.id = rownames(temp) # add column to join with the main data
data = left_join(temp,data)


# add columns with GRID ATTRIBUTES to main data

temp = dataebird %>% group_by(group.id) %>% slice(1)

rownames(temp) = temp$group.id
coordinates(temp) = ~LONGITUDE + LATITUDE
temp = over(temp,gridmapg1)
temp = data.frame(temp)
temp$group.id = rownames(temp)
dataebird = left_join(temp,dataebird)
names(dataebird)[1] = "gridg1"

temp = dataebird %>% group_by(group.id) %>% slice(1)

rownames(temp) = temp$group.id
coordinates(temp) = ~LONGITUDE + LATITUDE
temp = over(temp,gridmapg2)
temp = data.frame(temp)
temp$group.id = rownames(temp)
dataebird = left_join(temp,dataebird)
names(dataebird)[1] = "gridg2"

temp = dataebird %>% group_by(group.id) %>% slice(1)

rownames(temp) = temp$group.id
coordinates(temp) = ~LONGITUDE + LATITUDE
temp = over(temp,gridmapg3)
temp = data.frame(temp)
temp$group.id = rownames(temp)
dataebird = left_join(temp,dataebird)
names(dataebird)[1] = "gridg3"

temp = dataebird %>% group_by(group.id) %>% slice(1)

rownames(temp) = temp$group.id
coordinates(temp) = ~LONGITUDE + LATITUDE
temp = over(temp,gridmapg4)
temp = data.frame(temp)
temp$group.id = rownames(temp)
dataebird = left_join(temp,dataebird)
names(dataebird)[1] = "gridg4"



dataebird$gridg1 = as.character(dataebird$gridg1)
dataebird$gridg2 = as.character(dataebird$gridg2)
dataebird$gridg3 = as.character(dataebird$gridg3)
dataebird$gridg4 = as.character(dataebird$gridg4)

## exclude pelagic lists
dataebird = dataebird %>%
  filter(!gridg1 %in% setdiff(data$gridg1, intersect(areag1$id,unique(data$gridg1))) &
           !gridg2 %in% setdiff(data$gridg2, intersect(areag2$id,unique(data$gridg2))) &
           !gridg3 %in% setdiff(data$gridg3, intersect(areag3$id,unique(data$gridg3))) &
           !gridg4 %in% setdiff(data$gridg4, intersect(areag4$id,unique(data$gridg4))) &
           !is.na(gridg1) & !is.na(gridg2) & !is.na(gridg3) & !is.na(gridg4))

dataebird = dataebird %>%
  filter(is.na(EFFORT.DISTANCE.KM) | EFFORT.DISTANCE.KM <= 50) %>%
  filter(REVIEWED == 0 | APPROVED == 1) %>%
  filter(year != 2019)

dataebird = dataebird %>%
  mutate(timegroups = as.character(year)) %>%
  mutate(timegroups = ifelse(year <= 1999, "before 2000", timegroups)) %>%
  #mutate(timegroups = ifelse(year >= 1990 & year <= 1999, "1990-1999", timegroups)) %>%
  mutate(timegroups = ifelse(year > 1999 & year <= 2006, "2000-2006", timegroups)) %>%
  mutate(timegroups = ifelse(year > 2006 & year <= 2010, "2007-2010", timegroups)) %>%
  mutate(timegroups = ifelse(year > 2010 & year <= 2012, "2011-2012", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2013, "2013", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2014, "2014", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2015, "2015", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2016, "2016", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2017, "2017", timegroups)) %>%
  mutate(timegroups = ifelse(year == 2018, "2018", timegroups))

dataebird = removevagrants(dataebird)
dataebird = completelistcheck(dataebird)

dataebird = dataebird %>%
  filter(year > 2014, month %in% 1:3)

dataatlas = dataatlas %>%
  filter(month %in% 1:3)

rm(list=setdiff(ls(envir = .GlobalEnv), c("dataatlas","dataebird")), pos = ".GlobalEnv")

## save in keralaatlasvsebird.RData

############################ KL Atlas

require(tidyverse)
source('~/GitHub/state-of-indias-birds/SoIB functions.R')

load("keralaatlasvsebird.RData")

load("maps.RData")
require(data.table)
require(sp)
require(rgeos)

temp = dataatlas %>% group_by(group.id) %>% slice(1)

rownames(temp) = temp$group.id
coordinates(temp) = ~LONGITUDE + LATITUDE
temp = over(temp,gridmapg3)
temp = data.frame(temp)
temp$group.id = rownames(temp)
dataatlas = left_join(temp,dataatlas)
names(dataatlas)[1] = "gridg3"


specieslist = dataebird %>%
  filter(CATEGORY == "species" | CATEGORY == "issf") %>%
  distinct(COMMON.NAME)

specieslist = specieslist$COMMON.NAME

specieslist = intersect(specieslist,dataatlas$COMMON.NAME)


# Compare parameter estimates


data = dataebird

data = data %>% select(-CATEGORY,-LOCALITY.ID,-REVIEWED,-APPROVED,
                       -LATITUDE,-LONGITUDE,-TIME.OBSERVATIONS.STARTED,-PROTOCOL.TYPE,
                       -day,-cyear)

require(tidyverse)
require(lme4)
require(VGAM)



data$gridg1 = as.factor(data$gridg1)
data$gridg2 = as.factor(data$gridg2)
data$gridg3 = as.factor(data$gridg3)
data$gridg4 = as.factor(data$gridg4)

dataatlas$gridg3 = as.factor(dataatlas$gridg3)

#data = data %>%
#  filter(ALL.SPECIES.REPORTED == 1)

comp = data.frame(type = rep(c("lla","dur","dis","onlyrandom","logitlla","logitdur","logitdis",
                               "onlyfixedlla","onlyfixeddur","onlyfixeddis",
                               "trivial","grid"),length(specieslist)),
                  species = rep(specieslist,each = 12))

comp$freq = 0
comp$atlas = 0

#comp[(length(comp[comp$freq != 0,]$freq)+2):(length(comp[comp$freq != 0,]$freq)+13),]$freq = NA
c = length(comp[comp$freq != 0,]$freq)+1

## run each analysis for each each species

for (i in (round(length(comp[comp$freq != 0,]$freq)/12)+1):length(specieslist))
{
  temp = data %>%
    filter(COMMON.NAME == specieslist[i]) %>%
    distinct(gridg3)
  data1 = temp %>% left_join(data)
  data1$region = NA
  
  datay = data1 %>%
    group_by(gridg3,gridg1,group.id) %>% slice(1) %>% ungroup %>%
    group_by(gridg3,gridg1) %>% summarize(medianlla = median(no.sp)) %>%
    group_by(gridg3) %>% summarize(medianlla = mean(medianlla)) %>%
    summarize(medianlla = round(mean(medianlla)))
  
  medianllag = datay$medianlla
  
  datay = data1 %>%
    group_by(gridg3,gridg1,group.id) %>% slice(1) %>% ungroup %>%
    group_by(gridg3,gridg1) %>% summarize(mediandur = median(na.omit(DURATION.MINUTES))) %>%
    group_by(gridg3) %>% summarize(mediandur = mean(mediandur)) %>%
    summarize(mediandur = round(mean(mediandur)))
  
  mediandurg = datay$mediandur
  
  datay = data1 %>%
    group_by(gridg3,gridg1,group.id) %>% slice(1) %>% ungroup %>%
    group_by(gridg3,gridg1) %>% summarize(mediandis = median(na.omit(EFFORT.DISTANCE.KM))) %>%
    group_by(gridg3) %>% summarize(mediandis = mean(mediandis)) %>%
    summarize(mediandis = round(mean(mediandis),1))
  
  mediandisg = datay$mediandis
  
  datay = data1 %>%
    summarize(medianlla = median(no.sp))
  
  medianlla = datay$medianlla
  
  datay = data1 %>%
    summarize(mediandur = median(na.omit(DURATION.MINUTES)))
  
  mediandur = datay$mediandur
  
  datay = data1 %>%
    summarize(mediandis = median(na.omit(EFFORT.DISTANCE.KM)))
  
  mediandis = datay$mediandis
  
  
  
  ## expand dataframe to include absences as well
  
  ed = expandbyspecies(data1,specieslist[i])
  
  ed = ed %>%
    filter(DURATION.MINUTES != 0 &
             #!is.na(DURATION.MINUTES) &
             #!is.na(EFFORT.DISTANCE.KM) &
             EFFORT.DISTANCE.KM != 0
    )
  
  m1 = glmer(OBSERVATION.COUNT ~ log(no.sp) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'cloglog'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a1 = predict(m1, data.frame(no.sp = medianllag), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m2 = glmer(OBSERVATION.COUNT ~ log(DURATION.MINUTES) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'cloglog'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a2 = predict(m2, data.frame(DURATION.MINUTES = mediandurg), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m3 = glmer(OBSERVATION.COUNT ~ log(EFFORT.DISTANCE.KM) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'cloglog'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a3 = predict(m3, data.frame(EFFORT.DISTANCE.KM = mediandisg), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m4 = glmer(OBSERVATION.COUNT ~ 1 +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'cloglog'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a4 = predict(m4, data.frame(no.sp = 0), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m5 = glmer(OBSERVATION.COUNT ~ log(no.sp) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'logit'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a5 = predict(m5, data.frame(no.sp = medianllag), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m6 = glmer(OBSERVATION.COUNT ~ log(DURATION.MINUTES) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'logit'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a6 = predict(m6, data.frame(DURATION.MINUTES = mediandurg), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m7 = glmer(OBSERVATION.COUNT ~ log(EFFORT.DISTANCE.KM) +
               (1|gridg3/gridg1), data = ed, 
             family=binomial(link = 'logit'), nAGQ = 0, control = glmerControl(optimizer = "bobyqa"))
  
  a7 = predict(m7, data.frame(EFFORT.DISTANCE.KM = mediandisg), re.form = NA, allow.new.levels=TRUE, 
               type = "response")
  
  m8 = glm(OBSERVATION.COUNT ~ log(no.sp), data = ed, 
           family=binomial(link = 'cloglog'))
  
  a8 = as.numeric(predict(m8, data.frame(no.sp = medianlla), allow.new.levels=TRUE, 
                          type = "response"))
  
  m9 = glm(OBSERVATION.COUNT ~ log(DURATION.MINUTES), data = ed, 
           family=binomial(link = 'cloglog'))
  
  a9 = as.numeric(predict(m9, data.frame(DURATION.MINUTES = mediandur), allow.new.levels=TRUE, 
                          type = "response"))
  
  m10 = glm(OBSERVATION.COUNT ~ log(EFFORT.DISTANCE.KM), data = ed, 
            family=binomial(link = 'cloglog'))
  
  a10 = as.numeric(predict(m10, data.frame(EFFORT.DISTANCE.KM = mediandis), allow.new.levels=TRUE, 
                           type = "response"))
  
  m11 = ed %>% 
    summarize(freq = sum(OBSERVATION.COUNT)/n())
  
  a11 = m11$freq[1]
  
  m12 = ed %>%
    group_by(gridg3,gridg1) %>% summarize(freq = sum(OBSERVATION.COUNT)/n()) %>%
    group_by(gridg3) %>% summarize(freq = mean(freq)) %>%
    summarize(freq = median(freq))
  
  a12 = m12$freq[1]
  
  dat = dataatlas
  atl = data %>%
    filter(COMMON.NAME == specieslist[i]) %>%
    distinct(gridg3)
  
  dat = left_join(atl,dat)
  
  m13 = dat %>%
    mutate(lists = n_distinct(group.id)) %>%
    group_by(COMMON.NAME) %>% summarize(freq = n()/max(lists)) %>%
    filter(COMMON.NAME == specieslist[i])
  
  a13 = m13$freq[1]
  
  comp$freq[(c+1):(c+12)] = c(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12)
  comp$atlas[(c+1):(c+12)] = a13
  c = c + 12
}

rm(list=setdiff(ls(envir = .GlobalEnv), c("comp")), pos = ".GlobalEnv")

## save in keralaatlasvsebird.RData