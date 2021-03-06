
###
# compute sensitivity of modularities of the citation network to attacks

library(igraph)
#library(dplyr)
library(Matrix)

setwd(paste0(Sys.getenv('CS_HOME'),'/Cybergeo/Models/cybergeo20/HyperNetwork/Models/Analysis'))

citnwfile=paste0(Sys.getenv('CS_HOME'),'/Cybergeo/Models/cybergeo20/HyperNetwork/Data/nw/citationNetwork.RData')
load(citnwfile)

set.seed(0)

core = induced_subgraph(gcitation,which(components(gcitation)$membership==1))
while(min(degree(core))<=1){core = induced_subgraph(core,which(degree(core)>1))}

A = as_adjacency_matrix(core,sparse = T)
M = A+Matrix::t(A)
undirected_rawcore = graph_from_adjacency_matrix(M,mode="undirected")

source('corrs.R')

set.seed(0)
com = cluster_louvain(undirected_rawcore)


# sensitivity function
modSensitivity <- function(A,core,membs,affected,target,type){
  #show(affected)
  if(target == "node"){
    if(type == "removal"){
      nodesid = sample.int(nrow(A),size = floor((1 - affected)*nrow(A)),replace = F)
      return(directedmodularity(membs[nodesid],A[nodesid,nodesid]))
    }
    if(type == "rewiring"){
      nodesid = sample.int(ncol(A),size=floor((1 - affected)*ncol(A)),replace = F)
      cols = 1:ncol(A);cols[nodesid]=sample(cols[nodesid],size = length(nodesid),replace=F)
      return(directedmodularity(membs,A[,cols]))
    }
  }
  if(target == "edge"){
    if(type == "removal"){
      gdel=subgraph.edges(core,sample.int(length(E(core)),size=floor((1-affected)*length(E(core))),replace=F),delete.vertices = F)
      Adel = as_adjacency_matrix(gdel,sparse = T)
      return(directedmodularity(membs,Adel))
    }
    if(type == "rewiring"){
      linksid = sample.int(length(E(core)),size=floor((1-affected)*length(E(core))),replace=F)
      gdel=subgraph.edges(core,linksid,delete.vertices = F)
      gdel=add.edges(gdel,sample.int(nrow(A),size=2*floor(affected*length(E(core))),replace = T))
      return(directedmodularity(membs,as_adjacency_matrix(gdel,sparse = T)))
    }
  }
}

# test
#modSensitivity(A,core,com$membership,0.3,"node","rewiring")


# define parameters
nreps = 1000
affected = seq(0.05,0.5,0.05)
target=c("node","edge")
type = c("removal","rewiring")
params=data.frame()
for(k in 1:nreps){for(f in affected){for(trgt in target){for(tp in type){
  params=rbind(params,c(k,f,trgt,tp),stringsAsFactors=F)
}}}}

library(doParallel)
cl <- makeCluster(50,outfile='log')
#cl <- makeCluster(4,outfile='log')
registerDoParallel(cl)

startTime = proc.time()[3]

res <- foreach(i=1:nrow(params)) %dopar% {
#res <- foreach(i=sample.int(nrow(params),size=8)) %dopar% {
  library(igraph);library(Matrix)
  source('corrs.R')
  show(paste0('row : ',i,'/',nrow(params)))
  show(paste0("affected = ",params[i,2]," ; target  ",params[i,3]," ; type = ",params[i,4]))
  #show(dim(A));show(length(com$membership))
  mod = modSensitivity(A,core,com$membership,as.numeric(params[i,2]),params[i,3],params[i,4])
  return(mod)
}

stopCluster(cl)

save(res,file=paste0('res/modsens.RData'))
  
show(paste0("Ellapsed Time : ",proc.time()[3]-startTime))

  

#######
## plot results
load('res/modsens.RData')

data = cbind(params,mod = unlist(res))
colnames(data)=c("rep","affected","target","type","modularity")
data$affected==as.numeric(data$affected)
data$affected[data$target=="node"&data$type=="rewiring"]=1-as.numeric(data$affected[data$target=="node"&data$type=="rewiring"])

g=ggplot(data,aes(x=affected,y=modularity,color=paste0(target,type),group=paste0(target,type)))
g+geom_point(pch='.')+geom_smooth()+geom_smooth(method="lm",linetype=2)

g=ggplot(data,aes(x=affected,y=modularity,color=paste0(target,type),group=paste0(target,type)))
g+geom_point(pch='.')+geom_smooth()+facet_wrap(~paste0(target,type),scales="free")+geom_smooth(method="lm",linetype=2)

g=ggplot(data[data$type=="removal",],aes(x=affected,y=modularity))
g+geom_boxplot()+facet_wrap(~paste0(target," ",type),scales="free")+ylab("Modularity")+xlab("Proportion affected")+stdtheme
ggsave(file='res/modsens_removal.png',width=30,height=15,units='cm')





