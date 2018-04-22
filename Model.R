#--------------------------------------------------------------------------
# Hierarchical Risk Parity (by LdP)
#--------------------------------------------------------------------------

getHRP <- function(cov, corr, max = NULL, min = NULL, return_raw = NULL, robust_cov = F) {
	# Construct a hierarchical portfolio
	if (robust_cov == T) {
		cov <- cov_shrink(return_raw)
		corr <- cov2cor(cov)
	}
	
	# Set the constraint matrix
	if (is.null(max)) max <- rep(1,ncol(cov))
	if (is.null(min)) min <- rep(0,ncol(cov))
	if (length(max)==1) max <- rep(max,ncol(cov)) else if (length(max)<ncol(cov)) stop("Provide correct weights")
	if (length(min)==1) min <- rep(min,ncol(cov)) else if (length(min)<ncol(cov)) stop("Provide correct weights")
	const <- rbind(max, min)
	
	# check constraints
	if (sum(const[1,]) < 1 | sum(const[2,]) > 1) stop("Incompatible weights")
	
	distmat <- ((1 - corr) / 2)^0.5
	clustOrder <- hclust(dist(distmat), method = 'single')$order
	out <- getRecBipart(cov, clustOrder, const)
	return(out)
}

getClusterVar <- function(cov, cItems) {
	# compute cluster variance from the inverse variance portfolio above
	covSlice <- cov[cItems, cItems]
	weights <- getIVP(covSlice)
	cVar <- t(weights) %*% as.matrix(covSlice) %*% weights
	return(cVar)
}

getRecBipart <- function(cov, sortIx, const) {
	
	w <- rep(1, ncol(cov))
	
	# create recursion function within parent function to avoid use of globalenv
	recurFun <- function(cov, sortIx, const) {
		# get first half of sortIx which is a cluster order
		subIdx <- 1:trunc(length(sortIx)/2)
		
		# subdivide ordering into first half and second half
		cItems0 <- sortIx[subIdx]
		cItems1 <- sortIx[-subIdx]
		
		# compute cluster variances of covariance matrices indexed
		# on first half and second half of ordering
		cVar0 <- getClusterVar(cov, cItems0)
		cVar1 <- getClusterVar(cov, cItems1)
		alpha <- 1 - cVar0/(cVar0 + cVar1)
		
		# determining whether weight constraint binds
		alpha <- min(sum(const[1,cItems0]) / w[cItems0[1]],
								 max(sum(const[2,cItems0]) / w[cItems0[1]], 
										 alpha))
		alpha <- 1 - min(sum(const[1,cItems1]) / w[cItems1[1]], 
										 max(sum(const[2,cItems1]) / w[cItems1[1]], 
												 1 - alpha))
		
		w[cItems0] <<- w[cItems0] * rep(alpha, length(cItems0))
		w[cItems1] <<- w[cItems1] * rep((1-alpha), length(cItems1))
		
		# rerun the function on a half if the length of that half is greater than 1
		if(length(cItems0) > 1) {
			recurFun(cov, cItems0, const)
		}
		if(length(cItems1) > 1) {
			recurFun(cov, cItems1, const)
		}
		
	}
	
	# run recursion function
	recurFun(cov, sortIx, const)
	return(list(w=w,sortIx=sortIx))
}
      
getIVP <- function(covMat) {
	invDiag <- 1/diag(as.matrix(covMat))
 	weights <- invDiag/sum(invDiag)
 	return(weights)
}


cov <- read.csv("Data/Exported/cov.csv", header=T, row.names=1)
corr <- read.csv("Data/Exported/corr.csv", header=T, row.names=1)

outputs <- getHRP(cov, corr)

heatmap(data.matrix(corr[outputs$sortIx, outputs$sortIx]))
