#--------------------------------------------------------------------------
# Development of the Asset Alocation problem
# The following algorithms are the HRP and Markowitz* models, at
# the end there is the constructions of both portfolios
#--------------------------------------------------------------------------


#--------------------------------------------------------------------------
# Importing libraries
#--------------------------------------------------------------------------
library(quadprog)
library(ggplot2)
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------


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
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Markowitz model simplified
#-------------------------------------------------------------------------------
eff.frontier <- function (returns, short="no", max.allocation=NULL, risk.premium.up=.5, risk.increment=.005){
# return argument should be a m x n matrix with one column per security
# short argument is whether short-selling is allowed; default is no (short selling prohibited)
# max.allocation is the maximum % allowed for any one security (reduces concentration)
# risk.premium.up is the upper limit of the risk premium modeled (see for loop below)
# risk.increment is the increment (by) value used in the for loop
 
covariance <- cov(returns)
print(covariance)
n <- ncol(covariance)
 
# Create initial Amat and bvec assuming only equality constraint (short-selling is allowed, no allocation constraints)
Amat <- matrix (1, nrow=n)
bvec <- 1
meq <- 1
 
# Then modify the Amat and bvec if short-selling is prohibited
if(short=="no"){
Amat <- cbind(1, diag(n))
bvec <- c(bvec, rep(0, n))
}
 
# And modify Amat and bvec if a max allocation (concentration) is specified
	if(!is.null(max.allocation)){
		if(max.allocation > 1 | max.allocation <0){
			stop("max.allocation must be greater than 0 and less than 1")
		}
		if(max.allocation * n < 1){
			stop("Need to set max.allocation higher; not enough assets to add to 1")
		}
		Amat <- cbind(Amat, -diag(n))
		bvec <- c(bvec, rep(-max.allocation, n))
	}
 
	# Calculate the number of loops based on how high to vary the risk premium and by what increment
	loops <- risk.premium.up / risk.increment + 1
	loop <- 1
 
	# Initialize a matrix to contain allocation and statistics
	# This is not necessary, but speeds up processing and uses less memory
	eff <- matrix(nrow=loops, ncol=n+3)
	# Now I need to give the matrix column names
	colnames(eff) <- c(colnames(returns), "Std.Dev", "Exp.Return", "sharpe")
 
	# Loop through the quadratic program solver
	for (i in seq(from=0, to=risk.premium.up, by=risk.increment)){
		dvec <- colMeans(returns) * i # This moves the solution up along the efficient frontier
		sol <- solve.QP(covariance, dvec=dvec, Amat=Amat, bvec=bvec, meq=meq)
		eff[loop,"Std.Dev"] <- sqrt(sum(sol$solution *colSums((covariance * sol$solution))))	
		eff[loop,"Exp.Return"] <- as.numeric(sol$solution %*% colMeans(returns)) * 250
		eff[loop,"sharpe"] <- eff[loop,"Exp.Return"] / eff[loop,"Std.Dev"]
		eff[loop,1:n] <- sol$solution
		loop <- loop+1
	}
 
	return(as.data.frame(eff))
}

#Function plot in order to plot the efficient frontier of the markowitz portfolio
plot_efficient_frontier <- function(eff){
	# Color Scheme
	ealred  <- "#7D110C"
	ealtan  <- "#CDC4B6"
	eallighttan <- "#F7F6F0"
	ealdark  <- "#423C30"
	ggplot(eff, aes(x=Std.Dev, y=Exp.Return)) + geom_point(alpha=.1, color=ealdark) +
	geom_point(data=eff.optimal.point, aes(x=Std.Dev, y=Exp.Return, label=sharpe), color=ealred, size=5) +
	annotate(geom="text", x=eff.optimal.point$Std.Dev, y=eff.optimal.point$Exp.Return,
	label=paste("Risk: ", round(eff.optimal.point$Std.Dev*100, digits=3),"\nReturn: ",
	round(eff.optimal.point$Exp.Return*100, digits=4),"%\nSharpe: ",
	round(eff.optimal.point$sharpe, digits=2), sep=""), hjust=0, vjust=1.2) +
	ggtitle("Efficient Frontier\nand Optimal Portfolio") + labs(x="Risk (standard deviation of portfolio variance)", y="Return") +
	theme(panel.background=element_rect(fill=eallighttan), text=element_text(color=ealdark),
	plot.title=element_text(size=24, color=ealred))
}

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# This function regards the reading and saving the records
#-------------------------------------------------------------------------------
save_records <- function(returns,hrp,train,test,eff){
	# Reading files
	records <- read.csv("records.csv", head=T, row.names=1)

	# adding configs from hrp
	n_assets <- ncol(returns)
	assets <- paste(colnames(returns), collapse=", ")
	w_str <- paste(hrp$w, collapse=", ")
	w <- hrp$w
	return <- sum(colMeans(train)*w)*250
	return_oos <- sum(colMeans(test)*w)*250
	volatility <- sum(apply(train,2,sd)*w)
	sharpe_ratio <- return/volatility
	timestamp <- Sys.time()
	type <- "hrp"
	n_samples <- split
	n_oos <- nrow(returns)-split

	to_add <- data.frame(
		n_assets=n_assets,
		assets=assets,
		w = w_str,
		return = return,
		return_oos = return_oos,
		volatility = volatility,
		sharpe_ratio = sharpe_ratio,
		timestamp = timestamp,
		type = type,
		n_samples = n_samples,
		n_oos = n_oos
	)
	records <- rbind(records, to_add)

	# adding configs from best sharpe ration markowitz portfolio
	assets <- paste(colnames(eff)[1:(ncol(eff)-3)], collapse=", ")
	w <- eff.min_vol.point[1,1:(ncol(eff)-3)]
	w_str <- paste(w, collapse=", ")
	return <- sum(colMeans(train)*w)*250
	return_oos <- sum(colMeans(test)*w)*250
	volatility <- sum(apply(train,2,sd)*w)
	sharpe_ratio <- return/volatility
	timestamp <- Sys.time()
	type <- "best_sharpe"
	n_samples <- split
	n_oos <- nrow(returns)-split

	to_add <- data.frame(
		n_assets=n_assets,
		assets=assets,
		w = w_str,
		return = return,
		return_oos = return_oos,
		volatility = volatility,
		sharpe_ratio = sharpe_ratio,
		timestamp = timestamp,
		type = type,
		n_samples = n_samples,
		n_oos = n_oos
	)
	records <- rbind(records, to_add)

	# adding configs from best volatitlity ration markowitz portfolio
	assets <- paste(colnames(eff)[1:(ncol(eff)-3)], collapse=", ")
	w <- eff.optimal.point[1,1:(ncol(eff)-3)]
	w_str <- paste(w, collapse=", ")
	return <- sum(colMeans(train)*w)*250
	return_oos <- sum(colMeans(test)*w)*250
	volatility <- sum(apply(train,2,sd)*w)
	sharpe_ratio <- return/volatility
	timestamp <- Sys.time()
	type <- "min_variance"
	n_samples <- split
	n_oos <- nrow(returns)-split

	to_add <- data.frame(
		n_assets=n_assets,
		assets=assets,
		w = w_str,
		return = return,
		return_oos = return_oos,
		volatility = volatility,
		sharpe_ratio = sharpe_ratio,
		timestamp = timestamp,
		type = type,
		n_samples = n_samples,
		n_oos = n_oos
	)
	records <- rbind(records, to_add)

	print(records[,c(1,4:11)])
	write.csv(records,"records.csv")
}
#-------------------------------------------------------------------------------



#-------------------------------------------------------------------------------
# Running models
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Initial config
train_test_splot = .8 # in %
DIR = "Data/Stocks/" # DO NOT change at least you have the data in another RELATIVE directory
#-------------------------------------------------------------------------------

# Reading files (in case files come clean)
returns <- read.csv("Data/Exported/series.csv",head=TRUE, row.names=1)	#returns

split <- as.integer(nrow(returns)* train_test_splot)
train <- returns[1:split,]
test <- returns[split:nrow(returns),]
cov <- cov(train)
corr <- cor(train)

#in case the cov and corr are bigdata
#cov <- read.csv("Data/Exported/cov.csv", header=T, row.names=1) #covariance
#corr <- read.csv("Data/Exported/corr.csv", header=T, row.names=1) #correlation

#-------------------------------------------------------------------------------
# Running HRP
hrp <- getHRP(cov, corr)
heatmap(data.matrix(corr[hrp$sortIx, hrp$sortIx])) # Plot of HRP
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Running Markowitz
eff <- eff.frontier(returns=returns, short="no", max.allocation=.40)
eff.optimal.point <- eff[eff$sharpe==max(eff$sharpe),]
eff.min_vol.point <- eff[eff$Std.Dev==min(eff$Std.Dev),]
plot_efficient_frontier(eff) # plot of Markowitz
#-------------------------------------------------------------------------------

# Saving models
save_records(returns,hrp,train,test,eff)