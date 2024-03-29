#!/usr/bin/env Rscript
#
## BSD 3-Clause License
## 
## Copyright (c) 2023, Tommi Mäklin (tommi `at' maklin.fi)
## All rights reserved.
## 
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
## 
## 1. Redistributions of source code must retain the above copyright notice, this
##    list of conditions and the following disclaimer.
## 
## 2. Redistributions in binary form must reproduce the above copyright notice,
##    this list of conditions and the following disclaimer in the documentation
##    and/or other materials provided with the distribution.
## 
## 3. Neither the name of the copyright holder nor the names of its
##    contributors may be used to endorse or promote products derived from
##    this software without specific prior written permission.
## 
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
## DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
## FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
## DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
## SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
## CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
## OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Predicting Finnish 2023 parliamentary election results from past 4
## years of gallups using a Gaussian process.

library("rstan")

source("src/read_data.R")

## Sample max. 4 chains in parallel
options(mc.cores = 4)

## Read in the data
gallups <- ReadGallups("data/polling_data_2019-2023.tsv", "14.4.2019")

## Process the gallup data into the Stan model format
## Process the gallup data into the Stan model format
time.scaling.factor <- 1
dates_to_predict <- c("9.4.2023")
date_format <- "%d.%m.%Y"
time.unit <- "days"
dates_to_predict <- as.numeric(difftime(time1=as.POSIXlt(dates_to_predict, format=date_format), time2=gallups$Date[1], units=time.unit))
stan.data <- list("N_obs" = nrow(gallups),
                  "P_obs" = length(4:ncol(gallups)) - 1,
                  "time_from_start_obs" = as.numeric(gallups$days_since_election/time.scaling.factor),
                  "party_support" = gallups[, 4:(ncol(gallups) - 1)],
                  "N_pollsters" = length(unique(gallups$Pollster)),
                  "pollsters" = as.numeric(factor(gallups$Pollster)),
                  "N_pred" = length(dates_to_predict) + 1, ## Predict 1 week further than requested
                  "time_from_start_pred" = c(dates_to_predict, dates_to_predict[length(dates_to_predict)] + 7)/time.scaling.factor)

## Compile Stan model
stan.model <- stan_model("src/gp_poll_aggregator.stan")

## Fit model
system.time(
    samples <- sampling(stan.model, chains=4, iter=3250, warmup=2000,
                        data = stan.data)
)
save(samples, file="polling_data_2019-2023_stan_fit.Rda")
