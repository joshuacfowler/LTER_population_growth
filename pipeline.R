## Authors: LTER pipeline team
## Purpose: build a general function to analyze popler data sets and generate desired outputs
## Last update: February 13, 2019

## install popler
#install.packages("devtools")
#devtools::install_github("AldoCompagnoni/popler", build_vignettes=T, force=T)
#install.packages("dplyr")
library(popler)
library(tidyverse)
library(rstan)
library(bayesplot)
library(rstanarm)

## let's use the heron data set (88) as a guinea pig
k <- 88

bigfun <- function(k){
  
  ## extract popler project data and metadata
  metadat <- pplr_browse(proj_metadata_key==as.integer(k), full_tbl = T)
  ## diagnose the data type
  type <- metadat$datatype
  ## break out of function if datatype is individual or basal cover
  if(type=="individual" | type=="basal_cover"){return("Non-desired data type")}
  
  ## get data and combine spatial rep info
  n_spat_levels <- metadat$n_spat_levs
  dat <- pplr_get_data(metadat) %>% 
    as.data.frame %>% 
    mutate(n_spat_levels = n_spat_levels) %>% 
    mutate(ran_effect = ifelse(n_spat_levels==1,spatial_replication_level_1,
                               ifelse(n_spat_levels==2,interaction(spatial_replication_level_1,spatial_replication_level_2),
                                      ifelse(n_spat_levels==3,interaction(spatial_replication_level_1,spatial_replication_level_2,spatial_replication_level_3),
                                             interaction(spatial_replication_level_1,spatial_replication_level_2,spatial_replication_level_3,spatial_replication_level_4))))) %>% 
    filter(!is.na(abundance_observation))
  ## filter out NAs and very rare species -- we made a decision to use only the data provided by PIs-- we are not
  ## assumming that NAs are zero
  
  ## if study is experimental, use only the control group
  ## check with Aldo what to specify here
  if(metadat$studytype=="exp"){}
  
  ## keep track of what year*ran_effect levels were lost by na.omit
  summ <- dat %>% 
    group_by(year,ran_effect) %>% 
    summarise(n(),sum(is.na(abundance_observation)))

  ## prep data for analysis
  newdat <- dat %>% 
    select(year,ran_effect,sppcode,abundance_observation) %>% 
    drop_na()
  datalist<-list(
    n=nrow(dat),
    nyear=length(unique(as.factor(newdat$year))),
    nrep=length(unique(as.factor(newdat$ran_effect))),
    nsp=length(unique(as.factor(newdat$sppcode))),
    year=as.numeric(as.factor(as.character(newdat$year))),
    rep=as.numeric(as.factor(as.character(newdat$ran_effect))),
    sp=as.numeric(as.factor(as.character(newdat$sppcode))),
    count=newdat$abundance_observation)
  
  ## send to the appropriate Stan model, given data type
  stan_model <- ifelse(type=="count","count_model.stan",
                       ifelse(type=="biomass","biomass_model.stan",
                              ifelse(type=="cover","cover_model.stan","density_model.stan")))
  abund_fit<-stan(file=stan_model,data=datalist,iter=5000,chains=3)
  
  ## generate diagnostic quantities
  
  ## generate derived estimate of lambda
  
  ## collect climate covariates
  latlong_DD <- c(metadat$lat_lter, metadat$long_lter)
  years <- metadat$studystartyr:metadat$studyendyr
  
  ## pull out items of interest from Stan output - could embed climate change simulation here
  
  ## package outputs into data frame or list
  output <- extract(abund_fit,"a")[[1]]
  return(output)
}

test <- bigfun(62)


## pseudo-code for Stan model
#1. Get year-specific lambdas
#2. Fit spline for climate covariate
#3. Derive expected value
#4. Calculate model diagnostics


traceplot(abund_fit)
print(abund_fit)

mcmc_areas(
  posterior, 
  pars = c("cyl", "drat", "am", "sigma"),
  prob = 0.8, # 80% intervals
  prob_outer = 0.99, # 99%
  point_est = "mean"
)



# trash

dat %>% 
  group_by(sppcode) %>% 
  select(abundance_observation) %>% 
  filter(abundance_observation > 0) %>% 
  summarise(n())

test <- dat %>% 
  group_by(sppcode) %>% 
  filter(abundance_observation > 0,
         !is.na(abundance_observation))

filter(test,sppcode=="WI")
spp <- na.omit(unique(test$sppcode))
