example = function() {
  set_gemini_api_key(file = "~/repbox/gemini/gemini_api_key.txt")
  prompt = paste0(rep("I will be cached. yjkdbsbd sajdbjs kasbd ksad bsjdb ksdjhsabd basbdjhsd sandjsakjd asjbdka iwsgdq mwsd x a dkjbsajd qwdbsaj d as dc..",2000), collapse="")
  context = gemini_context(prompt, do_cache=FALSE)
  gemini_context_cache_expire_sec(context)
  cont = gemini_cache_context(context)

  gemini_context_cache_expire_sec(cont)

  gemini_list_cached_contexts()
  cont$cache_name
}

#' Create a Gemini context
#'
#' Initializes a Gemini context object with caching options.
#'
#' @param prompt The input prompt for the model.
#' @param model The model to use.
#' @param media Optional media input.
#' @param ttl_sec Time-to-live for cache in seconds (default: `60*60`).
#' @param role The role of the request (default: `"user"`).
#' @param do_cache Logical; if `TRUE`, attempts to cache the context.
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#'
#' @return A `gemini_context` object.
#' @export
gemini_context = function(prompt=NULL,model="gemini-2.0-flash", media=NULL, ttl_sec=10*60, role="user", do_cache = TRUE,  api_key=getOption("gemini_api_key")) {
  context = list(
    prompt = prompt,
    model = model,
    media = media,
    ttl_sec = ttl_sec,
    role = role,
    is_cached = FALSE,
    caching_failed = FALSE,
    token_count = NA_integer_,
    cache_name = NA_character_
  )
  class(context) = c("gemini_context", "list")
  if (do_cache)  {
    context = gemini_cache_context(context, api_key=api_key)
  }
  context
}

#' Get remaining context cache expiration time
#'
#' Computes the remaining seconds until a cached context expires.
#'
#' @param context A `gemini_context` object.
#'
#' @return The remaining seconds until expiration, or `NA` if not cached.
#' @export
gemini_context_cache_expire_sec = function(context) {
  if (!context$is_cache) return(NA_real_)
  context$ttl_sec - ((as.numeric(Sys.time()) - as.numeric(context$caching_time)))
}

#' Update cached context expiration
#'
#' Updates the TTL of a cached Gemini context.
#'
#' @param context A `gemini_context` object.
#' @param ttl_sec New TTL value (default: existing TTL).
#' @param only_if_worked Logical; if `TRUE`, only updates if caching previously worked.
#' @param only_if_expired Logical; if `TRUE`, only updates if cache is expired.
#' @param expired_sec_margin Margin in seconds before cache is considered expired (default: `10`).
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#'
#' @return The updated `gemini_context` object.
#' @export
gemini_update_context_cache = function(context, ttl_sec = context$ttl_sec, only_if_worked=TRUE, only_if_expired=TRUE,expired_sec_margin = 10, verbose=TRUE,  api_key=getOption("gemini_api_key")) {
  restore.point("gemini_update_context_cache")
  if (isTRUE(context$caching_failed) & only_if_worked) {
    return(context)
  }
  is_expired = (as.numeric(Sys.time()) - as.numeric(context$caching_time)) > context$ttl_sec - expired_sec_margin
  if (!is_expired) return(context)

  if (!context$is_cached) {
    return(gemini_cache_context(context, api_key=api_key))
  }

  # Construct the PATCH request URL
  url = paste0(
    "https://generativelanguage.googleapis.com/v1beta/",
    context$cache_name,
    "?key=",
    api_key
  )
  context$ttl_sec = ttl_sec
  ttl = paste0(ttl_sec, "s")
  # Prepare the body with new TTL
  body = list(ttl = ttl)

  # Make the PATCH request
  response = httr::PATCH(
    url = url,
    httr::content_type_json(),
    encode = "json",
    body = body
  )
  # Check response status
  context$update_status_code = status_code = httr::status_code(response)
  # context does no longer exist: generate it newly
  if (status_code == 403) {
    cat("\nCached context no longer exists. Generate new cache.\n")
    return(gemini_cache_context(context, api_key=api_key))
  }

  if (status_code == 200) {
    context$caching_time = Sys.time()
    if (verbose) {
      cat("\nCache TTL successfully updated\n")
    }
  } else {
    cat("\nFailed to update context cache. Status code: ", status_code)
  }
  context
}

#' Cache a Gemini context
#'
#' Caches a Gemini context to the API.
#'
#' @param context A `gemini_context` object.
#' @param verbose Logical; if `TRUE`, prints additional logging information.
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#'
#' @return The updated `gemini_context` object with caching details.
#' @export
gemini_cache_context = function(context, verbose=TRUE, api_key=getOption("gemini_api_key")) {
  restore.point("gemini_cache_context")
  if (is.null(api_key)) {
    stop("Please set an api key by calling set_gemini_api_key.")
  }
  prompt=context$prompt; media = context$media; model = context$model

  url <- paste0("https://generativelanguage.googleapis.com/v1beta/cachedContents?key=", api_key)

  contents = gemini_curl_make_contents(prompt, media, encode_prompt=TRUE)
  contents$role = context$role

  body = list(
    model = paste0("models/", model),
    contents = contents,
    ttl = paste0(context$ttl_sec,"s")
  )

  if (verbose) cat("\nCache context ...")
  context$caching_time = Sys.time()
  response <- POST(
    url = url,
    query = list(key = api_key),
    content_type_json(),
    encode = "json",
    body = body
  )


  # Check the status code of the response
  context$status_code = status_code(response)
  # Output the content of the response
  context$caching_json = content(response, "text")
  context$caching_resp = try(fromJSON(context$caching_json),silent = TRUE)
  if (is(context$caching_resp, "try-error") | isTRUE(context$status_code==400)) {
    context$is_cached=FALSE
    context$caching_failed = TRUE
    cat(paste0(" failed: \n", context$caching_json),"\n")
    return(context)
  }
  context$is_cached = TRUE
  context$caching_failed = FALSE
  context$cache_name = context$caching_resp$name
  context$token_count = context$caching_resp$usageMetadata$totalTokenCount
  #context$token_count = context$caching_resp
  if (verbose)  cat(paste0(" done (", context$token_count, " tokens)\n"))

  context
}

gemini_curl_make_contents = function(prompt=NULL, media, encode_prompt=FALSE) {
  if (is.null(prompt)) {
    parts = list()
  } else if (encode_prompt) {
    library(base64enc)
    encoded_prompt = base64enc::base64encode(charToRaw(prompt))
    parts = list(
      list(
        inline_data = list(
          mime_type = "text/plain",
          data = encoded_prompt
        )
      )
    )
  } else {
    parts = list(list(text=prompt))
  }


  # If media is provided, add one or several media parts.
  if (!is.null(media)) {
    # If media is not already a list of media objects, wrap it in a list.
    if (!is.list(media) || (is.list(media) && !is.list(media[[1]]) &&
                            all(c("mime_type", "file_uri") %in% names(media)))) {
      media <- list(media)
    }
    for (m in media) {
      m = m[c("mime_type", "file_uri")]
      parts[[length(parts) + 1]] <- list(file_data = m)
    }
  }
  contents = list(
    parts = parts
  )
  contents
}

#' List all cached contexts
#'
#' Retrieves a list of all cached contexts from the Gemini API.
#'
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#'
#' @return A data frame with cached context details, or `NULL` if no caches are found.
#' @export
gemini_list_context_caches <- function(api_key = getOption("gemini_api_key")) {
  # Check for API key
  if (is.null(api_key)) {
    stop("Please set an API key by calling set_gemini_api_key.")
  }

  # Build the URL
  url <- paste0("https://generativelanguage.googleapis.com/v1beta/cachedContents?key=", api_key)

  # Make GET request
  response <- httr::GET(url, httr::content_type_json())
  status_code <- httr::status_code(response)
  json_response <- httr::content(response, as = "text", encoding = "UTF-8")

  # Attempt to parse the JSON response
  result <- tryCatch({
    jsonlite::fromJSON(json_response)
  }, error = function(e) {
    cat(paste0("\nError in list_context_caches: ", e$message))
    return(NULL)
  })
  result = result$cachedContents
  if (NROW(result)==0) {
    return(NULL)
  }
  result = as.data.frame(result)
  names(result)[1] = "cache_name"
  return(result)
}

#' Delete all cached contexts
#'
#' Deletes all cached contexts from the Gemini API.
#'
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#'
#' @return The number of caches deleted.
#' @export
gemini_delete_all_context_caches = function(api_key = getOption("gemini_api_key")) {
  cache_df = gemini_list_context_caches(api_key)
  if (NROW(cache_df)==0) return(0L)
  for (cache_name in cache_df$cache_name) {
    gemini_delete_context_cache(cache_name = cache_name)
  }
  return(NROW(cache_df))
}

#' Delete a cached context
#'
#' Deletes a cached context from the Gemini API.
#'
#' @param context An optional context object containing the cache name.
#' @param cache_name The name of the cache to delete (default is extracted from `context`).
#' @param api_key The API key for authentication (default is taken from `getOption("gemini_api_key")`).
#' @param verbose Logical; if TRUE, prints messages about the deletion process.
#'
#' @return Returns `TRUE` if deletion is successful, `FALSE` otherwise. If `context` is provided, returns the updated context.
#' @export
gemini_delete_context_cache = function(context=NULL,
  cache_name=context$cache_name,
  api_key=getOption("gemini_api_key"),
  verbose=FALSE
) {
  if (is.null(api_key)) {
    stop("Please set an api key by calling set_gemini_api_key.")
  }

  # Construct the DELETE request URL
  url = paste0(
    "https://generativelanguage.googleapis.com/v1beta/",
    cache_name,
    "?key=",
    api_key
  )

  if (verbose) {
    cat("\nDeleting cache:", cache_name, "\n")
  }

  # Make the DELETE request
  response = httr::DELETE(url)

  # Check response status
  status_code = httr::status_code(response)
  if (status_code == 204) {
    if (verbose) {
      cat("Cache successfully deleted\n")
    }
    if (is.null(context)) return(TRUE)
    context$is_cached = FALSE
    context
    return(context)
  } else {
    warning("Failed to delete cache. Status code: ", status_code)
    if (is.null(context)) return(FALSE)
    return(context)
  }
}
