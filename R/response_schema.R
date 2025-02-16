

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
  # Recursive helper function to infer a JSON Schema fragment.
  # The argument in_array indicates whether we're already inside an array context.
  infer_schema <- function(x, in_array = FALSE) {
    if (is.null(x)) {
      return(list(type = "null"))
    } else if (inherits(x, "obj_resp")) {
      # Process an object response.
      if (is.null(names(x)) || !any(names(x) != "")) {
        stop("For an object response, the example must be a named list.")
      }
      properties <- list()
      required <- c()
      for (nm in names(x)) {
        properties[[nm]] <- infer_schema(x[[nm]], in_array = FALSE)
        required <- c(required, nm)
      }
      return(list(
        type = "object",
        properties = properties,
        required = required
      ))
    } else if (inherits(x, "arr_resp")) {
      # Process an array response.
      if (!in_array) {
        # At the top level, if x is a single object (named list), wrap it into a list.
        if (is.list(x) && !is.null(names(x))) {
          x <- list(x)
        } else if (!is.list(x)) {
          x <- list(x)
        }
        if (length(x) == 0) {
          return(list(type = "array", items = list()))
        } else {
          # Now, signal that we're inside an array.
          item_schema <- infer_schema(x[[1]], in_array = TRUE)
          return(list(type = "array", items = item_schema))
        }
      } else {
        # When already inside an array, do not rewrap.
        # Instead, treat x as a plain object (if named) or as an array.
        if (is.list(x) && !is.null(names(x)) && any(names(x) != "")) {
          properties <- list()
          required <- c()
          for (nm in names(x)) {
            properties[[nm]] <- infer_schema(x[[nm]], in_array = FALSE)
            required <- c(required, nm)
          }
          return(list(
            type = "object",
            properties = properties,
            required = required
          ))
        } else {
          if (length(x) == 0) {
            return(list(type = "array", items = list()))
          } else {
            item_schema <- infer_schema(x[[1]], in_array = TRUE)
            return(list(type = "array", items = item_schema))
          }
        }
      }
    } else if (is.atomic(x)) {
      # Process atomic values.
      if (length(x) == 1) {
        if (is.character(x)) {
          return(list(type = "string"))
        } else if (is.numeric(x)) {
          if (all(x == as.integer(x))) {
            return(list(type = "integer"))
          } else {
            return(list(type = "number"))
          }
        } else if (is.logical(x)) {
          return(list(type = "boolean"))
        } else {
          return(list(type = "string"))
        }
      } else {
        # For an atomic vector with length > 1, treat it as an array.
        item_schema <- infer_schema(x[1], in_array = TRUE)
        return(list(type = "array", items = item_schema))
      }
    } else if (is.list(x)) {
      # Process plain lists that are not marked as obj_resp or arr_resp.
      if (!is.null(names(x)) && any(names(x) != "")) {
        properties <- list()
        required <- c()
        for (nm in names(x)) {
          properties[[nm]] <- infer_schema(x[[nm]], in_array = FALSE)
          required <- c(required, nm)
        }
        return(list(
          type = "object",
          properties = properties,
          required = required
        ))
      } else {
        if (length(x) == 0) {
          return(list(type = "array", items = list()))
        } else {
          item_schema <- infer_schema(x[[1]], in_array = TRUE)
          return(list(type = "array", items = item_schema))
        }
      }
    } else {
      # Fallback: treat as a string.
      return(list(type = "string"))
    }
  }

  # Top-level: the example must be an obj_resp or arr_resp.
  if (inherits(example, "obj_resp") || inherits(example, "arr_resp")) {
    return(infer_schema(example, in_array = FALSE))
  } else {
    stop("Example must have class 'obj_resp' or 'arr_resp'")
  }
}
