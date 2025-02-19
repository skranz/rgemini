

example = function() {
  undebug(response_schema)
  schema = response_schema(arr_resp(facts = arr_resp(name="fact1", descr="fact_description")))

  schema = response_schema(arr_resp(city = "Paris", country="France", famous_building="Eiffel Tower", population = 5.2, facts = arr_resp(name="fact1", descr="fact_description")))

}


#' Create an Array Response Template
#'
#' This function creates a template for an array response consisting of JSON objects.
#' Each element (object) in the array is expected to have the provided fields.
#'
#' @param ... Named elements that define the fields for each JSON object in the array.
#'
#' @return A list with class `arr_resp` that serves as a template for an array response.
#'
#' @examples
#' # Create an array response template with two fields.
#' arr_template <- arr_resp(city = "Paris", country = "France")
#' str(arr_template)
arr_resp = function(...) {
  x = list(...)
  class(x) = c("arr_resp","list")
  x
}

#' Create an Object Response Template
#'
#' This function creates a template for a single JSON object response.
#' The response is expected to be a JSON object with the provided fields.
#'
#' @param ... Named elements that define the fields for the JSON object.
#'
#' @return A list with class `obj_resp` that serves as a template for an object response.
#'
#' @examples
#' # Create an object response template with three fields.
#' obj_template <- obj_resp(city = "Paris", country = "France", population = 5.2)
#' str(obj_template)
obj_resp <- function(...) {
  x <- list(...)
  class(x) <- c("obj_resp", "list")
  x
}

#' Infer the JSON Response Type
#'
#' This function inspects the provided value and returns a string representing the
#' JSON type. It distinguishes between objects, arrays, and primitive types.
#'
#' @param x The value to inspect.
#'
#' @return A character string: one of "null", "object", "array", "string", "integer",
#'         "number", or "boolean".
infer_response_type <- function(x) {
  if (is.null(x)) {
    return("null")
  } else if (inherits(x, "obj_resp")) {
    return("object")
  } else if (inherits(x, "arr_resp")) {
    return("array")
  } else if (is.atomic(x)) {
    if (length(x) == 1) {
      if (is.character(x)) {
        return("string")
      } else if (is.numeric(x)) {
        if (all(x == as.integer(x))) {
          return("integer")
        } else {
          return("number")
        }
      } else if (is.logical(x)) {
        return("boolean")
      } else {
        return("string")
      }
    } else {
      # For an atomic vector with length > 1, treat it as an array.
      return("array")
    }
  } else if (is.list(x)) {
    if (!is.null(names(x)) && any(names(x) != "")) {
      return("object")
    } else {
      return("array")
    }
  } else {
    return("string")
  }
}

#' Generate a JSON Schema from a Response Template
#'
#' This function recursively generates a JSON Schema based on a response template.
#' The template must be created using either \code{obj_resp} (for a single object response)
#' or \code{arr_resp} (for an array response). The function infers the JSON Schema
#' by inspecting the data types of the provided fields without including the example values.
#'
#' @param example A response template created by \code{obj_resp} or \code{arr_resp}.
#'
#' @return A list representing the inferred JSON Schema for the provided response template.
response_schema <- function(example) {
  # Recursive helper function to generate a JSON Schema fragment.
  schema_fragment <- function(x, in_array = FALSE) {
    t <- infer_response_type(x)

    if (t == "null") {
      return(list(type = "null"))
    } else if (t == "object") {
      properties <- list()
      required <- c()
      for (nm in names(x)) {
        properties[[nm]] <- schema_fragment(x[[nm]], in_array = FALSE)
        required <- c(required, nm)
      }
      return(list(
        type = "object",
        properties = properties,
        required = required
      ))
    } else if (t == "array") {
      # If we're not already inside an array, then if x is a single (named) object, wrap it.
      if (!in_array) {
        if (is.list(x) && !is.null(names(x))) {
          x <- list(x)
        } else if (!is.list(x)) {
          x <- list(x)
        }
      }
      if (length(x) == 0) {
        items <- list()
      } else {
        items <- schema_fragment(x[[1]], in_array = TRUE)
      }
      return(list(type = "array", items = items))
    } else {
      # For primitive types ("string", "integer", "number", "boolean")
      return(list(type = t))
    }
  }

  if (!(inherits(example, "obj_resp") || inherits(example, "arr_resp"))) {
    stop("Example must have class 'obj_resp' or 'arr_resp'")
  }

  return(schema_fragment(example, in_array = FALSE))
}




