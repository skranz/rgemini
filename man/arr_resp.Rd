% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/response_schema.R
\name{arr_resp}
\alias{arr_resp}
\title{Create an Array Response Template}
\usage{
arr_resp(...)
}
\arguments{
\item{...}{Named elements that define the fields for each JSON object in the array.}
}
\value{
A list with class `arr_resp` that serves as a template for an array response.
}
\description{
This function creates a template for an array response consisting of JSON objects.
Each element (object) in the array is expected to have the provided fields.
}
\examples{
# Create an array response template with two fields.
arr_template <- arr_resp(city = "Paris", country = "France")
str(arr_template)
}
