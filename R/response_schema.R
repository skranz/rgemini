gemini_response_schema <- function(type = c("object", "array")[1], example) {


  # Helper function: recursively infer the JSON Schema fragment for a given value,
  # without including the example data.
  infer_schema <- function(x) {
    if (is.null(x)) {
      return(list(type = "null"))
    } else if (is.atomic(x)) {
      # For atomic values:
      if (length(x) == 1) {
        if (is.character(x)) {
          return(list(type = "string"))
        } else if (is.numeric(x)) {
          # Distinguish between integer and number.
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
        # For an atomic vector of length > 1, treat it as an array.
        item_schema <- infer_schema(x[1])
        return(list(type = "array", items = item_schema))
      }
    } else if (is.list(x)) {
      # Determine if the list is a named list (object) or an unnamed list (array).
      if (!is.null(names(x)) && any(names(x) != "")) {
        properties <- list()
        required <- c()
        for (nm in names(x)) {
          properties[[nm]] <- infer_schema(x[[nm]])
          required <- c(required, nm)
        }
        return(list(
          type = "object",
          properties = properties,
          required = required
        ))
      } else {
        # Unnamed list: treat as an array.
        if (length(x) == 0) {
          return(list(type = "array", items = list()))
        } else {
          item_schema <- infer_schema(x[[1]])
          return(list(type = "array", items = item_schema))
        }
      }
    } else {
      # Fallback: treat as string.
      return(list(type = "string"))
    }
  }

  if (type == "object") {
    if (is.null(names(example)) || !any(names(example) != "")) {
      stop("For type 'object', the example must be a named list.")
    }
    properties <- list()
    required <- c()
    for (nm in names(example)) {
      properties[[nm]] <- infer_schema(example[[nm]])
      required <- c(required, nm)
    }
    schema <- list(
      type = "object",
      properties = properties,
      required = required
    )
  } else if (type == "array") {
    # If the example is a single object (named list), wrap it into a list.
    if (is.list(example) && !is.null(names(example))) {
      example <- list(example)
    } else if (!is.list(example)) {
      example <- list(example)
    }

    if (length(example) == 0) {
      schema <- list(
        type = "array",
        items = list()
      )
    } else {
      item_schema <- infer_schema(example[[1]])
      schema <- list(
        type = "array",
        items = item_schema
      )
    }
  }

  return(schema)
}


gemini_response_schema_with_example <- function(type = c("object", "array")[1], example) {
  #restore.point("gemini_response_schema")
  # Helper function: recursively infer the JSON schema fragment for a given value.
  infer_schema <- function(x) {
    if (is.null(x)) {
      return(list(type = "null", example = x))
    } else if (is.atomic(x)) {
      # For atomic vectors:
      if (length(x) == 1) {
        if (is.character(x)) {
          return(list(type = "string", example = x))
        } else if (is.numeric(x)) {
          # Distinguish between integer and number if possible.
          if (all(x == as.integer(x))) {
            return(list(type = "integer", example = x))
          } else {
            return(list(type = "number", example = x))
          }
        } else if (is.logical(x)) {
          return(list(type = "boolean", example = x))
        } else {
          return(list(type = "string", example = as.character(x)))
        }
      } else {
        # For an atomic vector of length > 1, treat it as an array.
        item_schema <- infer_schema(x[1])
        return(list(type = "array", items = item_schema, example = x))
      }
    } else if (is.list(x)) {
      # If the list has names, treat it as an object; otherwise as an array.
      if (!is.null(names(x)) && any(names(x) != "")) {
        properties <- list()
        required <- c()
        for (nm in names(x)) {
          properties[[nm]] <- infer_schema(x[[nm]])
          required <- c(required, nm)
        }
        return(list(
          type = "object",
          properties = properties,
          required = required,
          example = x
        ))
      } else {
        # Unnamed list: treat as an array.
        if (length(x) == 0) {
          return(list(type = "array", items = list(), example = x))
        } else {
          item_schema <- infer_schema(x[[1]])
          return(list(type = "array", items = item_schema, example = x))
        }
      }
    } else {
      # Fallback: convert to string.
      return(list(type = "string", example = as.character(x)))
    }
  }

  if (type == "object") {
    if (is.null(names(example)) || !any(names(example) != "")) {
      stop("For type 'object', the example must be a named list.")
    }
    properties <- list()
    required <- c()
    for (nm in names(example)) {
      properties[[nm]] <- infer_schema(example[[nm]])
      required <- c(required, nm)
    }
    schema <- list(
      type = "object",
      properties = properties,
      required = required,
      example = example
    )
  } else if (type == "array") {
    # Even if type is "array", allow the example to be a single object.
    # If the example is a named list (an object), wrap it in a list.
    if (is.list(example) && !is.null(names(example))) {
      example <- list(example)
    } else if (!is.list(example)) {
      # If not a list at all, wrap it.
      example <- list(example)
    }

    if (length(example) == 0) {
      schema <- list(
        type = "array",
        items = list(),
        example = example
      )
    } else {
      # Infer schema from the first element of the array.
      item_schema <- infer_schema(example[[1]])
      schema <- list(
        type = "array",
        items = item_schema,
        example = example
      )
    }
  }

  return(schema)
}
