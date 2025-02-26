example = function() {
  df = gemini_list_models()
}

gemini_list_models <- function(api_key=getOption("gemini_api_key"))  {
  # Construct the URL with the API key
  url <- paste0("https://generativelanguage.googleapis.com/v1beta/models", "?key=", api_key)
  # Make the GET request
  response <- httr::GET(url)
  # Parse and return the JSON response
  result <- bind_rows(httr::content(response, "parsed"))
  return(result)
}
