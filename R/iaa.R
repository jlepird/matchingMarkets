# ----------------------------------------------------------------------------
# R-code (www.r-project.org/) for the Deferred Acceptance Algorithm
#
# Copyright (c) 2013 Thilo Klein
#
# This library is distributed under the terms of the GNU Public License (GPL)
# for full details see the file LICENSE
#
# ----------------------------------------------------------------------------

#' @title Immediate Acceptance Algorithm (a.k.a. Boston mechanism) for two-sided matching markets
#'
#' @description Finds the optimal assignment of students to colleges in the 
#' \href{http://en.wikipedia.org/wiki/Hospital_resident}{college admissions} problem
#' based on the Boston mechanism. The option \code{acceptance="deferred"} instead uses the Gale-Shapley 
#' (1962) Deferred Acceptance Algorithm with male offer. The function works with either 
#' given or randomly generated preferences.
#'
#' @param nStudents integer indicating the number of students (in the college admissions problem) 
#' or men (in the stable marriage problem) in the market. Defaults to \code{ncol(s.prefs)}.
#' @param nColleges integer indicating the number of colleges (in the college admissions problem) 
#' or women (in the stable marriage problem) in the market. Defaults to \code{ncol(c.prefs)}.
#' @param nSlots vector of length \code{nColleges} indicating the number of places (i.e. 
#' quota) of each college. Defaults to \code{rep(1,nColleges)} for the marriage problem.
#' @param s.prefs matrix of dimension \code{nColleges} \code{x} \code{nStudents} with the \code{j}th 
#' column containing student \code{j}'s ranking over colleges in decreasing order of 
#' preference (i.e. most preferred first).
#' @param c.prefs matrix of dimension \code{nStudents} \code{x} \code{nColleges} with the \code{i}th 
#' column containing college \code{i}'s ranking over students in decreasing order of 
#' preference (i.e. most preferred first).
#' @param acceptance if \code{acceptance="deferred"} returns the solution found by the student-proposing Gale-Shapley deferred acceptance algorithm; if \code{acceptance="immediate"} (the default) returns the solution found by the Boston mechanism.
#' @export
#' @import stats
#' @section Minimum required arguments:
#' \code{iaa} requires the following combination of arguments, subject to the matching problem.
#' \describe{
#' \item{\code{nStudents, nColleges}}{Marriage problem with random preferences.}
#' \item{\code{s.prefs, c.prefs}}{Marriage problem with given preferences.}
#' \item{\code{nStudents, nSlots}}{College admissions problem with random preferences.}
#' \item{\code{s.prefs, c.prefs, nSlots}}{College admissions problem with given preferences.}
#' }
#' @return
#' \code{iaa} returns a list with the following elements.
#' \item{s.prefs}{student-side preference matrix.}
#' \item{c.prefs}{college-side preference matrix.}
#' \item{iterations}{number of interations required to find the stable matching.}
#' \item{matchings}{edgelist of matches}
#' \item{singles}{identifier of single (or unmatched) students/men.}
#' @author Thilo Klein 
#' @keywords algorithms
#' @references Gale, D. and Shapley, L.S. (1962). College admissions and the stability 
#' of marriage. \emph{The American Mathematical Monthly}, 69(1):9--15.
#' 
#' Kojima, F. and M.U. Unver (2014). The "Boston" school-choice mechanism. \emph{Economic Theory}, 55(3): 515--544. 
#' 
#' @examples
#' ## --------------------------------
#' ## --- College admission problem
#' 
#' ## Boston mechanism for 7 students, 2 colleges with 3 slots each
#'  set.seed(123)
#'  iaa(nStudents=7, nSlots=c(3,3))
#' 
#' ## Gale-Shapley algorithm
#'  set.seed(123)
#'  iaa(nStudents=7, nSlots=c(3,3), acceptance="deferred")
#' 
#' ## Same results for the Gale-Shapley algorithm with hri() function
#'  set.seed(123)
#'  hri(nStudents=7, nSlots=c(3,3))
#' 
#' ## 7 students, 2 colleges with 3 slots each, given preferences:
#'  s.prefs <- matrix(c(1,2, 1,2, 1,2, 1,2, 1,2, 1,2, 1,2), 2,7)
#'  c.prefs <- matrix(c(1,2,3,4,5,6,7, 1,2,3,4,5,6,7), 7,2)
#'  iaa(s.prefs=s.prefs, c.prefs=c.prefs, nSlots=c(3,3))
iaa <- function(nStudents=ncol(s.prefs), nColleges=ncol(c.prefs), nSlots=rep(1,nColleges), s.prefs=NULL, c.prefs=NULL, acceptance="immediate"){
  
  ## If 'nColleges' not given, obtain it from nSlots
  if(is.null(nColleges)){
    nColleges <- length(nSlots)
  }
  ## If no prefs given, make them randomly:
  if(is.null(s.prefs)){  
    s.prefs <- replicate(n=nStudents,sample(seq(from=1,to=nColleges,by=1)))
  }
  if(is.null(c.prefs)){    
    c.prefs <- replicate(n=nColleges,sample(seq(from=1,to=nStudents,by=1)))
  }
  
  ## Consistency checks:
  if( dim(s.prefs)[1] != dim(c.prefs)[2] | dim(s.prefs)[2] != dim(c.prefs)[1] | 
      dim(s.prefs)[2] != nStudents | dim(c.prefs)[2] != nColleges | 
      dim(c.prefs)[1] != nStudents | dim(s.prefs)[1] != nColleges ){
    stop("'s.prefs' and 'c.prefs' must be of dimensions 'nColleges x nStudents' and 'nStudents x nColleges'!")
  }
  if( length(nSlots) != nColleges | length(nSlots) != dim(c.prefs)[2] ){
    stop("length of 'nSlots' must equal 'nColleges' and the number of columns of 'c.prefs'!")
  }
  
  iter <- 0
  
  s.hist    <- rep(0,length=nStudents)  # number of proposals made
  c.hist    <- lapply(nSlots, function(x) rep(0,length=x))  # current students
  s.singles <- 1:nStudents
  
  s.mat <- matrix(data=1:nStudents,nrow=nStudents,ncol=nColleges,byrow=F)
  
  while(min(s.hist) < nColleges){  # there are as many rounds as maximal preference orders
    # look at market: all unassigned students
    # if history not full (been rejected by all colleges in his prefs)
    # look at unassigned students' history
    # propose to next college on list
    iter         <- iter + 1
    offers       <- NULL
    
    ## Look at unassigned students that have not yet applied to all colleges 
    temp.singles <- c(na.omit( s.singles[s.hist[s.singles] < nColleges] ))
    if(length(temp.singles)==0){ # if unassigned students have used up all their offers: stop
      return(list(s.prefs=s.prefs,c.prefs=c.prefs,iterations=iter,matchings=edgefun(x=c.hist),singles=s.singles))
      break
    }
    
    ## Add to students' offer history
    for(i in 1:length(temp.singles)){
      s.hist[temp.singles[i]] <- s.hist[temp.singles[i]] + 1  # set history of student i one up.
      offers[i] <- s.prefs[s.hist[temp.singles[i]],temp.singles[i]]  # offer if unassigned i is index of current round college
    }
    
    ##print(paste("Iteration: ",iter))
    
    approached <- unique(offers)	# index of colleges who received offers
    s.singles  <- sort(s.singles[!s.singles %in% temp.singles])  # reset unassigned students, except for singles who already used up all offers
    
    for(j in approached){
      proposers   <- temp.singles[offers==j]
      proposers   <- c.prefs[,j][c.prefs[,j] %in% proposers]
      stay.single <- temp.singles[offers==0]	# students who prefer remaining unassigned at current history
      
      for (k in 1:length(proposers)){
        
        if(0 %in% (c.hist[[j]] & any(c.prefs[ ,j]==proposers[k]))){  # if no history and proposer is on preference list
          
          c.hist[[j]][c.hist[[j]]==0][1] <- proposers[k]			  # then accept
          
        } else if(acceptance=="deferred" & (TRUE %in% (match(c.prefs[c.prefs[ ,j]==proposers[k],j],c.prefs[ ,j]) < match(c.prefs[c.prefs[ ,j] %in% c.hist[[j]], j],c.prefs[ ,j])))){   # if proposer better than any current student
          
          worst <- max(match(c.prefs[c.prefs[ ,j] %in% c.hist[[j]], j], c.prefs[ ,j])) # determine worst current student
          s.singles <- c(s.singles,c.prefs[worst,j])   # reject worst current student
          c.hist[[j]][c.hist[[j]] == c.prefs[worst,j]] <- proposers[k]	# and take proposer on
          
        } else{
          s.singles <- c(s.singles,proposers[k])	# otherwise k stays unassigned
        }
      }	
    }
    
    s.singles <- sort(c(s.singles,stay.single))
    if(length(s.singles)==0){	# if no unassigned students left: stop
      current.match <- sapply(1:nColleges, function(x) s.mat[,x] %in% c.hist[[x]])
      return(list(s.prefs=s.prefs,c.prefs=c.prefs,iterations=iter,matchings=edgefun(x=c.hist),singles=s.singles))
      break
    }
    current.match <- sapply(1:nColleges, function(x) s.mat[,x] %in% c.hist[[x]])
  }
  
  ## return results
  return(list(s.prefs=s.prefs,c.prefs=c.prefs,iterations=iter,matchings=edgefun(x=c.hist),singles=s.singles))
}

## convert match matrix to edgelist
edgefun <- function(x){
  res <- data.frame(college = c(unlist( sapply(1:length(x), function(i){
    rep(i,length(x[[i]]))  
  }) )), 
  student = unlist(x),
  stringsAsFactors = FALSE)
  res <- with(res, res[order(college, student),])
}


