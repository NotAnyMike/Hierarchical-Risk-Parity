#!/usr/bin/Rscript
# optimization1.r, N risky assets case
#args <- commandArgs(TRUE)
read_data <- function(args){
	data <- read.table(paste("./Data/Exported/", args, sep=""),header=TRUE, sep=",");
	return(list(data, as.integer(args[2]),as.double(args[3])));
}

returns <- function(data){
	dat <- data[[1]]; 
	N <- nrow(dat) - 1; 
	J <- ncol(dat); 
	ret <- (dat[1:N,1] - dat[2:(N+1),1])/dat[2:(N+1),1]; 
	if(J > 1){ 
		for(j in 2:J){
        	ret <- cbind(ret, (dat[1:N,j] - dat[2:(N+1),j])/dat[2:(N+1),j])
		}
	}
	return(list(ret, names(data[[1]]), data[[2]], data[[3]]));
}

optimization <- function(returns){
	p <- colMeans(returns[[1]]); 
	names(p) <- returns[[2]]; 
	J <- ncol(returns[[1]]); 
	M <- returns[[3]];
	Rmax <- returns[[4]];	
	S <- cov(returns[[1]]); 	
	Q <- solve(S); 	
	u <- rep(1,J);	
	a <- matrix(rep(0,4),nrow=2);		
	a[1,1] <- u%*%Q%*%u;		
	a[1,2] <- a[2,1] <- u%*%Q%*%p;		
	a[2,2] <- p%*%Q%*%p;
	d <- a[1,1]*a[2,2] - a[1,2]*a[1,2]; 
	f <- (Q%*%( a[2,2]*u - a[1,2]*p))/d;
	g <- (Q%*%(-a[1,2]*u + a[1,1]*p))/d;
	r <- seq(0, Rmax, length=M);
	w <- matrix(rep(0,J*M), nrow=J);
	for(m in 1:M) w[,m] <- f + r[m]*g;
	s <- sqrt( a[1,1]*((r - a[1,2]/a[1,1])^2)/d + 1/a[1,1]);
	ss <- sqrt(diag(S));
	minp <- c(sqrt(1/a[1,1]), a[1,2]/a[1,1]);
	wminp <- f + (a[1,2]/a[1,1])*g;
	tanp <- c(sqrt(a[2,2])/a[1,2], a[2,2]/a[1,2]);
	wtanp <- f + (a[2,2]/a[1,2])*g;
	Q <- sqrt(diag(1.0/ss));
	x <- eigen(Q%*%S%*%Q);
	v <- Q%*%x$vec;
	for(j in 1:J) v[,j] <- v[,j]/(u%*%v[,j]);
	sv <- rv <- rep(0, J);
	for(j in 1:J){
		rv[j] <- t(v[,j])%*%p;
		if(rv[j] < 0){
			rv[j] <- -rv[j];
			v[,j] <- -v[,j];
		}
	sv[j] <- sqrt(t(v[,j])%*%S%*%v[,j]);
	}
	return(list(s, r, ss, p, minp, tanp, wminp, wtanp,w, v, sv, rv));
}

plot_results<- function(data, returns, results){
	dat <- log(data[[1]]); 
	M <- nrow(dat);
	ymax = max(dat); 
	ymin = min(dat)
	mycolors <- rainbow(J+1);
	s <- results[[1]]; 
	r <- results[[2]];
	ss <- results[[3]]; 
	p <- results[[4]];
	minp <- results[[5]]; 
	tanp <- results[[6]]; 
	wminp <- results[[7]]; 
	wtanp <- results[[8]]; 
	f <- t(results[[9]]); 
	v <- results[[10]]; 
	sv <- results[[11]]; 
	rv <- results[[12]]; 
	postscript(file="./results1/fig1.eps", onefile=FALSE, horizontal=FALSE, height=10, width=5);
	par(mfrow=c(2,1));
	id <- c(1:nrow(dat));
	plot(id, rev(dat[,1]), ylim=c(ymin, ymax), type="l",col=mycolors[1], xlab="day", ylab="log(price)",main = "Asset Prices");
	if(J > 1){
    	for(j in 2:J){
        	lines(id, rev(dat[,j]), type="l",col=mycolors[j]);
		}
	} 
	legend("topleft", names(dat), cex=0.5, pch=rep(15, J),col=mycolors);
	ret <- returns[[1]];
	ymax = max(ret); 
	ymin = min(ret);
	id <- c(1:nrow(ret));
	plot(id, rev(ret[,1]), ylim=c(ymin, ymax), type="l",col=mycolors[1], xlab="day", ylab="returns",main = "Asset Returns");
	if(J > 1){
		for(j in 2:J){
			lines(id, rev(ret[,j]),type="l",col=mycolors[j]);
		}
	} 
	legend("topleft", returns[[2]], cex=0.5, pch=rep(15, J),col=mycolors);
	postscript(file="./results1/fig2.eps", onefile=FALSE,horizontal=FALSE, height=10, width=5);
	par(mfrow=c(2,1));
	plot(s, r, xlim=c(0,max(s)), ylim=c(min(r,p), max(r,p)),type="l", col="blue", xlab="risk", ylab="return",
	main = "Efficient Frontier, MVP1, TGP"); 
	points(ss, p, pch=19, col=mycolors);
	text(ss, p, pos=4, cex=0.5, names(p));
	points(sv[1], rv[1], pch=15, col="black");
	text(sv[1], rv[1], pos=4, cex=0.5, "DEP"); 
	points(minp[1], minp[2], pch=19, col="black"); 
	text(minp[1], minp[2], pos=2, cex=0.5, "MVP1"); 
	points(tanp[1], tanp[2], pch=19, col="black"); 
	text(tanp[1], tanp[2], pos=2, cex=0.5, "TGP"); 
	lines(c(0,max(s)), c(0,max(s)*tanp[2]/tanp[1]), lty=3); 
	abline(h=0, lty=2); 
	abline(v=0, lty=2); 
	plot(s, f[,1], xlim=c(0,max(s)), ylim=c(min(f),max(f)),col=mycolors[1], type="l",xlab="risk", ylab="portfolio weights",main = "Efficient Portfolio Weights"); 
	if(J > 1){
		for(j in 2:J){
			lines(s, f[,j], type="l", col=mycolors[j]);
		}
	} 
	abline(h=0, lty=2); 
	abline(v=minp[1], lty=3); 
	abline(v=tanp[1], lty=3);
	text(minp[1], min(f), pos=4, cex=0.5, "MVP1"); 
	text(tanp[1], min(f), pos=4, cex=0.5, "TGP"); 
	legend("topleft", names(p), cex=0.5, pch=rep(15, J), col=mycolors);
	postscript(file="./results1/fig3.eps", onefile=FALSE,horizontal=FALSE, height=10, width=5);
	par(mfrow=c(2,1));
	barplot(wminp, main="Minimum Variance Portfolio 1 (MVP1)", xlab="Assets", ylab="Weights", col=mycolors, beside=TRUE);
	abline(h=0, lty=1);
	legend("topleft", names(p), cex=0.5, pch=rep(15, J),col=mycolors);
	barplot(wtanp, main="Tangency Portfolio (TGP)",xlab="Assets", ylab="Weights", col=mycolors,beside=TRUE);
	abline(h=0, lty=1);
	legend("topleft", names(p), cex=0.5, pch=rep(15, J),col=mycolors);
	barplot(v[,1], main="Dominant Eigen-Portfolio (DEP)", xlab="Assets", ylab="Weights", col=mycolors,beside=TRUE);
	abline(h=0, lty=1);
	legend("topleft", names(p), cex=0.5, pch=rep(15, J), col=mycolors); 
}
	
data <- read_data("Series.csv");
returns <- returns(data);
dir.create("results1", showWarnings = FALSE);
results <- optimization(returns);
plot_results(data, returns, results);


