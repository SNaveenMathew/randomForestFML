# randomForestFML

This is based on the randomForest package 4.6-14 from the following website:
https://cran.r-project.org/web/packages/randomForest/

I couldn't find the repo for the most current version of randomForest, so I had to gracely steal the codes from the above link.

The option of using sequential bootstrap (see: Advances in Financial Machine Learning, Marcos Lopez de Prado, 2018),
instead of the ordinary bootstrap for random forests / bagging has been added.

Currently, sequential bootstrap relies on an index vector (SB) that is generated by some R codes (see below), but could be very time consuming; C codes should be able to
dramatically increase the speed of generating SB.

## How to use

In R:

```{r}
devtools::install_github("larryleihua/randomForestFML")
library(randomForestFML)
ntree <- 10 # use a small number for experiment, otherwise very slow!!
seedvec <- seq(1,nTree)
iRun <- function(i)
{
  set.seed(seedvec[i])
  cat(i, "\n")
  return(seqBoot(trainSet$tFea, trainSet$tLabel))
}
iRun <- Vectorize(iRun, "i")
    
library(parallel)
cc <- makeCluster(detectCores()-1)
clusterExport(cc, c("trainSet", "seedvec", "seqBoot"))
i_sB <- tryCatch(parLapply(cc, 1:nTree, iRun), error=function(e) NA, warning=function(w) NA)
clusterEvalQ(cc, {gc()})
stopCluster(cc)
    
sBmat <- NULL
for(i in 1:nTree)
{
   sBmat <- cbind(sBmat, i_sB[[i]])
}

SB <- as.vector(as.matrix(sBmat)) 
bag <- randomForestFML(Y ~ C+V, data = trainSet, mtry = 2, importance = TRUE, ntree = ntree, SB=SB)

```

## To do
__The most urgent todo is to implement a function for generating SB for the C functions (rf.c and regrf.c in src/)__


## R codes

The following are the R codes that are used to create SB, and the while loop in seqBoot() is extremely slow, which should be implemented in C instead.

```{r}
#' @param t1_Fea: a vector for time index (in terms of tick/volume/dollar/etc. bars) for the end of each features bars
#' @param t1: a vector for time index (in terms of tick/volume/dollar/etc. bars) that corresponds to the event (eg, hitting some barrier)
#' @examples
#' t1_Fea <- c(2,5,11)
#' t1 <- c(9,11,15)
#' getIndMat(t1_Fea, t1)
getIndMat <- function(t1_Fea, t1)
{
  I <- length(t1_Fea) # number of features bars
  if(I!=length(t1)){stop("Error! The number of features bars should be the same as the number of t1")}
  t1_max <- max(t1) # this should be the same as the total number of bars
  indMat <- matrix(0, t1_max, I)# indicator matrix 1_{t,i}
  for(i in 1:I)
  {
    indMat[(t1_Fea[i]+1):t1[i],i] <- 1
  }
  return(indMat)
}

#' @param indMat: indicator matrix 1_{t,i}
#' @param sampled: sampled index, default is 1:ncol(indMat)
#' t1_Fea <- c(2,5,11)
#' t1 <- c(9,11,15)
#' iMat <- getIndMat(t1_Fea, t1)
#' getAvgUniq(iMat)
#' getAvgUniq(iMat, c(1,3,3))
getAvgUniq <- function(indMat, sampled=NULL)
{
  if(is.null(sampled)){sampled <- 1:ncol(indMat)}
  indMat_ <- indMat[,sampled]
  c_t <- apply(indMat_, 1, sum)
  u_ti <- indMat_ / c_t
  u_ti[c_t==0,] <- 0 # some c_t is 0, and need to change NaN to 0
  ubar_i <- apply(u_ti,2,sum) / apply(indMat_,2,sum)
  return(ubar_i)
}

#' @param t1_Fea: a vector for time index (in terms of tick/volume/dollar/etc. bars) for the end of each features bars
#' @param t1: a vector for time index (in terms of tick/volume/dollar/etc. bars) that corresponds to the event (eg, hitting some barrier)
#' @param sLen: how many draws, the default is the maximum draws, i.e., length(t1_Fea)
#' @examples
#' t1_Fea <- c(2,5,11)
#' t1 <- c(9,11,15)
#' seqBoot(t1_Fea, t1)
seqBoot <- function(t1_Fea, t1, sLen=NULL)
{
  ## construct indicator matrix 1_{t,i}: indMat
  I <- length(t1_Fea) # number of features bars
  if(I!=length(t1)){stop("Error! The number of features bars should be the same as the number of t1")}
  t1_max <- max(t1) # this should be the same as the total number of bars
  indMat <- matrix(0, t1_max, I)# indicator matrix 1_{t,i}
  for(i in 1:I)
  {
    indMat[(t1_Fea[i]+1):t1[i],i] <- 1
  }
 
  ## sequential bootstrap
  if(is.null(sLen)){sLen <- length(t1_Fea)}
  phi <- sample(1:sLen, 1) # phi: the vector used to store the sampled features bars index
 
  while(length(phi)<sLen) # the loop for sequential bootstrap
  {
    # update average uniqueness based on phi
    c_t <- apply(as.matrix(indMat[,phi],nrow=t1_max), 1, sum)
    u_ti <- indMat / (c_t+1)
    ubar_i <- apply(u_ti,2,sum) / apply(indMat,2,sum)
   
    # sample the next one based on updated average uniqueness
    phi <- c(phi, sample(1:sLen, 1, prob = ubar_i / sum(ubar_i)))
  }
  return(phi)
}
```
