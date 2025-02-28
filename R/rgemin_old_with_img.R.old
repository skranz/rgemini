run_gemini_with_image = function(prompt, model="gemini-2.0-flash", json_mode=!is.null(response_schema),response_schema = NULL, temperature=0.1,img_mimeType=NULL, img_base64=NULL, add_prompt=FALSE, verbose=FALSE, api_key=getOption("gemini_api_key"), as_data_frame=TRUE, just_content=FALSE) {
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
  # If a structured output schema is provided, add it to the generation configuration.
  if (!is.null(response_schema)) {
    generationConfig$response_schema <- response_schema
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
  if (just_content) {
    df = gemini_result_to_df(res)
    return(gemini_content(df))
  }
  if (!as_data_frame) {
    return(res)
  }
  gemini_result_to_df(res)

}
