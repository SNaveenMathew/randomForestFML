treesize <- function(x, terminal=TRUE) {
  if(!inherits(x, "randomForestFML"))
    stop("This function only works for objects of class `randomForestFML'")
  if(is.null(x$forest)) stop("The object must contain the forest component")
  if(terminal) return((x$forest$ndbigtree+1)/2) else return(x$forest$ndbigtree)
}
