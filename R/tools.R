
first.non.null = function (...) {
  args = list(...)
  for (val in args) {
    if (!is.null(val))
      return(val)
  }
  return(NULL)
}


na.val = function (x, val = 0) {
  x[is.na(x)] = val
  x
}

escape_quotes = function(txt, double_quotes=TRUE, single_quotes=TRUE) {
  if (single_quotes) {
    txt = gsub("'","\\'",txt, fixed=TRUE)
  }
  if (double_quotes) {
    txt = gsub('"','\\"',txt, fixed=TRUE)
  }
  txt
}
