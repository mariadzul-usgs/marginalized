###############################################################################
#                                                                     Spring 19
#  Fitting a multi-state version of a CJS model to the RBT data 
#  Marginalized OpenBUGS version - fixed time effects
#
#  Notes:
#  * 
#
#  To do: 
#  * 
#
###############################################################################
library(R2OpenBUGS)
source(paste0(getwd(),"/Functions.R"), chdir = F)

setwd(paste0(getwd(), '/Application_1'))

data.dir = paste0(getwd(), "/Data")
CH = as.matrix(read.table(file = paste0(data.dir, "/RBT_Capture_History.txt"),
                          header = FALSE, sep = "\t"))
#-----------------------------------------------------------------------------#
# format data for model fitting
tmpCH = collapse.ch(CH)[[1]]
FR = collapse.ch(CH)[[2]]

# Create vector with occasion of marking
get.first <- function(x) min(which(x != 0))
sumf <- apply(tmpCH, 1, get.first)

#
S = tmpCH
S[S[,] == 0] = 2

NS = nrow(S)          # number of capture histories 
Nint = ncol(S) - 1    # number of sampling intervals

ones <- FR

zeta = known.state.cjs(tmpCH)

#-----------------------------------------------------------------------------#
sink("OpenBUGS_Marginalized_Time.OpenBUGS")
cat("
model{
  
  for(t in 1:Nint){ 
    phi[t] ~ dunif(0,1)
    p[t] ~ dunif(0,1)
    
    omega[1,1,t] <- phi[t]
    omega[1,2,t] <- 1 - phi[t]
    omega[2,1,t] <- 0
    omega[2,2,t] <- 1
    
    rho[1,1,t] <- p[t]
    rho[1,2,t] <- 1 - p[t]
    rho[2,1,t] <- 0
    rho[2,2,t] <- 1
  }
  
  for(i in 1:NS){
    zeta[i,sumf[i],1] <- 1
    zeta[i,sumf[i],2] <- 0
    
    for(t in sumf[i]:Nint){
      zeta[i,(t+1),1] <- inprod(zeta[i,t,], omega[,1,t]) * rho[1,S[i,(t+1)],t]
      zeta[i,(t+1),2] <- inprod(zeta[i,t,], omega[,2,t]) * rho[2,S[i,(t+1)],t]
    }
    
    lik[i] <- sum(zeta[i,(Nint+1),])
    ones[i] ~ dbin(lik[i], FR[i])
  }
}
    ", fill = TRUE)
sink() 
#-----------------------------------------------------------------------------#
OM.data <- list(NS = NS, Nint = Nint, S = S,
                sumf = sumf, FR = FR, ones = ones)
OM.par <- c('phi', 'p')

ni <- 100
nt <- 1
nb <- 50

# be explicit on the call to 'bugs', as the names are same for both R2WinBUGS and R2OpenBUGS
t1 <- proc.time()
OM.out <- R2OpenBUGS::bugs(OM.data, inits = NULL, OM.par, "OpenBUGS_Marginalized_Time.OpenBUGS",
               n.chains = 3, n.iter = ni, n.thin = nt)
t2 <- proc.time()

print(JM.out, digits = 3)

#-----------------------------------------------------------------------------#
library(foreach)
library(doParallel)

n.core = 30

cl1 = makeCluster(n.core) # number of cores you want to use
registerDoParallel(cl1)

# make sure each cluster has the packages used
cllibs <- clusterEvalQ(cl1, c(library(R2OpenBUGS)))

all.t1 = proc.time()
n.runs = 10

my.n.iter = seq(0,10000,500)[- 1]

big.fit.list = list()

# seeds <- sample(1:1e5, size = n.runs)
seeds <- rep(0, n.runs)

# let all of the clusters have whatever objects are in the workspace
clusterExport(cl = cl1, varlist = ls(), envir = environment())

start.time <- Sys.time()  # start timer

# n = 1
out = list()
#--------------------------------------
out <- foreach(j = seeds) %:%

  foreach(i = my.n.iter) %dopar% {

    seed = j
    # seed = seed + sample(1:1e5, size = 1)
    seed = seed + sample(1:14, size = 1)

    iter.in = i

    t1 <- proc.time()

    my.env = environment()

    JM.t <- R2OpenBUGS::bugs(JM.data, inits = NULL, JM.par, "OpenBUGS_Marginalized_Time.OpenBUGS",
                               n.chains = 3, n.iter = iter.in, n.thin = nt,
                             bugs.seed = seed)

    t2 <- proc.time()

    attr(JM.t, 'time') <- (t2 - t1)[3]

    JM.t

  }
#--------------------------------------

end.time = Sys.time()
time.taken = end.time - start.time
print(round(time.taken,2))

all.t2 = proc.time()
stopCluster(cl1)  # close the clusters


length(out)
length(out[[1]])

all.out = do.call('c', out)
length(all.out)

# tmp = run.times(all.out)

all.Open.m.time.1 = all.out

rm(list=setdiff(ls(), "all.Open.m.time.1"))

# save.image("U:/Desktop/Fish_Git/Marginalized/Application_1/working_Runs/Open_M_Time.RData")

#-----------------------------------------------------------------------------#