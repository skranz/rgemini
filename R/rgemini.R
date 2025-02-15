
example = function() {
  set_gemini_api_key(file = "C:/libraries/gpt/gemini/gemini_api_key.txt")
  result = run_gemini("Tell 3 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE)
  df = fromJSON(result$content)
  result = run_gemini("Tell a joke.", add_prompt=TRUE, json_mode = FALSE)
  res = result
  gemini_result_to_df(result)
}

set_gemini_api_key = function(key=NULL, file=NULL) {
  if (is.null(key)) {
    key = suppressWarnings(readLines(file))
  }
  options(gemini_api_key = key)
}

gemini_result_to_df = function(res, ...) {

  prompt_var = if (is.null(res[["prompt"]])) NULL else "prompt"
  if (!is.null(res$error)) {
    li = c(
      list(...),
      res[c("model","json_mode","temperature",prompt_var)],
      list(
        error = res$error$message,
        finishReason = "error",
        content = NA
      )
    )
    return(as.data.frame(li))
  }

  parts = res$candidates$content$parts
  content = unlist(lapply(parts, function(df) df[[1]]))

  li = c(
    list(...),
    res[c("model","json_mode","temperature", prompt_var)],
    list(
      error = "",
      finishReason = res$candidates$finishReason[1],
      content = paste0(content, collapse="")
    )
  )
  return(as.data.frame(li))
}

run_gemini = function(prompt, model="gemini-2.0-flash", json_mode=FALSE, temperature=0.1,img_mimeType=NULL, img_base64=NULL, add_prompt=FALSE, verbose=FALSE, api_key=getOption("gemini_api_key"), as_data_frame=TRUE) {
  library(httr)
  library(jsonlite)
  if (is.null(api_key)) {
    stop("Please set an api key by calling set_gemini_api_key.")
  }

  url = paste0("https://generativelanguage.googleapis.com/v1beta/models/", model,":generateContent?key=", api_key)

  generationConfig = list(
    temperature = temperature
  )
  if (json_mode) {
    generationConfig$response_mime_type = "application/json"
  }

  part = list(text=prompt)

  if (!is.null(img_base64)) {
    # { "inlineData": {
    #   "mimeType": "image/png",
    #   "data": "'$(base64 -w0 cookie.png)'"
    # }
    part$inlineData = list(
      mimeType = img_mimeType,
      data = img_base64
    )

  }

  body = list(
    contents = list(
      parts = list(
        part
      )
    ),
    generationConfig = generationConfig
  )

  if (verbose)
    cat("\ncURL call body\n\n", toJSON(body))

  response <- POST(
    url = paste0("https://generativelanguage.googleapis.com/v1beta/models/", model,":generateContent"),
    query = list(key = api_key),
    content_type_json(),
    encode = "json",
    body = body
  )

  # Check the status code of the response
  status_code = status_code(response)

  # Output the content of the response
  json = content(response, "text")

  if (verbose) {
    cat("\n\nResult:\n",nchar(json), " characters:\n\n",json)
  }
  library(jsonlite)
  res = try(fromJSON(json),silent = TRUE)
  if (is(res, "try-error")) {
    res = list(status_code = status_code,parse_error=TRUE, json=json)
    return(res)
  }
  res$status_code = status_code
  res$parse_error = FALSE
  if (add_prompt) {
    res$prompt = prompt
  }
  res$model = model
  res$json_mode = json_mode
  res$temperature = temperature
  if (!as_data_frame) {
    return(res)
  }
  gemini_result_to_df(res)

}
