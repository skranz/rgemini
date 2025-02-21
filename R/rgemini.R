
example = function() {
  library(rgemini)
  set_gemini_api_key(file = "~/repbox/gemini/gemini_api_key.txt")
  files = "~/repbox/projects_share/aejapp_1_2_4/art/pdf/aejapp_1_2_4.pdf"
  media <- gemini_media_upload(files)

  content = run_gemini("Please extract Table 3 in the PDF as HTML table. Include table titles and table notes. Please make sure to include all numbers as they are. Just return the complete HTML file.

IMPORTANT: Make sure to have enough different columns and rows. Each number shall be in a a different table cell.

IMPORTANT: In regression tables ensure that coefficients and standard errors are in different table cells. Usually they will be in different <tr> rows.

IMPORTANT: Check whether really all numbers are correctly parsed and in the right position. If not, correct the table.
                       ", media=media)
  writeLines(content, "~/repbox/temp_tab3b.html")

  content = run_gemini("Please extract all tables in the PDF as HTML tables. Include table titles and table notes. Please make sure to include all numbers as they are. Just return the complete HTML file (no markdown markup).

IMPORTANT: Make sure to have enough different columns and rows. Each number shall be in a a different table cell.

IMPORTANT: In regression tables ensure that coefficients and standard errors are in different table cells. Usually they will be in different <tr> rows.

IMPORTANT: Check whether really all numbers are correctly parsed and in the right position. If not, correct the table.
                       ", media=media)
  writeLines(content, "~/repbox/temp_tables.html")


  library(rgemini)
  set_gemini_api_key(file = "~/repbox/gemini/gemini_api_key.txt")

  files = "~/repbox/temp_tab3b.html"
  media_html <- gemini_media_upload(files)
  schema = response_schema(arr_resp(
    tabid = "Table 1", table_title = "", table_main_html="", table_notes = ""))
  prompt = "Please extract all HTML tables from the attached .html document. Return as a JSON with fields:
  tabid: Table ID, e.g. 'Table 1'
  table_title: The table title
  table_main_html: The HTML code of the table. Make sure to properly escape the quotes in the HTML code so that it can be part of the JSON field.
  table_notes: The table notes
  "
  res = run_gemini(prompt=prompt,response_schema = schema, media=media_html,just_content = FALSE)
  content = gemini_content(res)

  writeLines(content$table_main_html, "~/repbox/test_tab3.html")

  # 1. Basic use

  run_gemini("Tell a joke.")

  # More detailed output
  run_gemini("Tell a joke.",just_content = FALSE)

  # 2. JSON mode without schema

  run_gemini("Tell 2 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE,just_content = FALSE)

  # directly parses json
  run_gemini("Tell 2 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE,just_content = TRUE)

  ######################################
  # 3. JSON mode with a response schema
  ######################################

  prompt = "List 3 asian countries, their capital, the most famous building and the countries' inhabitants in million."
  # creates a schema from an example
  schema = response_schema(arr_resp(capital = "Paris", country="France", famous_building="Eiffel Tower", population = 60.1))

  run_gemini(prompt = prompt,response_schema = schema)

  # A more complex nested response

  prompt = "Show info for one african country, its capital with name and population in mio, the most famous building and inhabitants in million. Add three facts about the country."
  schema = response_schema(obj_resp(
    capital = obj_resp(capital="Paris", cap_pop=5),
    country="France", famous_building="Eiffel Tower",
    population = 60.2,
    facts = arr_resp(name="fact1", descr="fact_description")
  ))
  # returns a data frame with nested data frames
  df = run_gemini(
    prompt = prompt,
    json_mode = TRUE,
    response_schema = schema,
    just_content = TRUE
  )
  str(df)

  ######################################
  # 4. Use image
  ######################################

  img_file = paste0("~/repbox/gemini/word_img.png")
  media <- gemini_media_upload(img_file)
  run_gemini("Please write down all words you can detect in the image.", media=media, just_content = TRUE)

  ######################################
  # 5. Use PDF and image
  ######################################
  files = c("~/repbox/gemini/word_img.png", "~/repbox/gemini/colors_pdf.pdf")
  media <- gemini_media_upload(files)
  run_gemini("Please write down all words you can detect in the uploaded pdf and image.", media=media)

  # Structured output from multiple files
  run_gemini("Please write down and classify all words you can detect in the uploaded files.", media=media, response_schema = gemini_response_schema("array", list(file_number=1L, word="blue",type_of_word="")))


}

#' Extract content from a more detailed run_gemini response
gemini_content = function(result) {
  if (result$json_mode) {
    fromJSON(result$content)
  } else {
    result$content
  }
}

#' Set your Gemini API
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

#' Generate Content with Gemini API
#'
#' Sends a text prompt (and optionally one or more media objects) to the Gemini API to generate content.
#'
#' @param prompt A character string containing the text prompt to be sent to the Gemini API.
#' @param model A character string specifying the Gemini model to use. Defaults to `"gemini-2.0-flash"`.
#' @param media Either a single media object or a list of media objects to be included in the prompt. Call \code{\link{gemini_media_upload}} to upload the document or media.
#' @param json_mode Logical. If \code{TRUE}, expects the response in JSON format. Defaults to \code{!is.null(response_schema)}.
#' @param response_schema Optional structured output schema for the response. Defaults to \code{NULL}.
#' @param temperature A numeric value controlling the randomness of the output. Defaults to 0.1.
#' @param add_prompt Logical. If \code{TRUE}, includes the prompt in the returned result. Defaults to \code{FALSE}.
#' @param verbose Logical. If \code{TRUE}, prints debugging and request information. Defaults to \code{FALSE}.
#' @param api_key A character string containing your Gemini API key. Defaults to the value obtained from \code{getOption("gemini_api_key")}.
#' @param just_content Logical. If \code{TRUE}, returns only the content portion of the result. JSON is transformed to R. Defaults to \code{TRUE}. Otherwise a data frame with the response of the POST call is returned, which includes fields like status_code.
#' @param httr_response Logical. Only relevant if just_content=FALSE. Returns POST response in original format, not transformed to a more convenient data set.
#'
#' @return A list containing the Gemini API response. If \code{as_data_frame} is \code{TRUE}, the response is converted to a data frame.
#'
#' @details
#' The function builds a JSON payload that includes the provided text prompt as well as any media objects supplied via the \code{media} parameter.
#' Each media object is appended to the \code{parts} of the request under the \code{file_data} key. The payload is then sent via a POST request
#' to the Gemini API endpoint for content generation.
#'
#' @examples
#' \dontrun{
#' # Example using only a text prompt:
#' result <- run_gemini(prompt = "Tell a joke", verbose = TRUE)
#'
#' }
#'
#' @seealso \code{\link[httr]{POST}}, \code{\link[jsonlite]{toJSON}}
#'
#' @export
run_gemini = function(prompt, model="gemini-2.0-flash", media=NULL, json_mode=!is.null(response_schema),response_schema = NULL, temperature=0.1, add_prompt=FALSE, verbose=FALSE, api_key=getOption("gemini_api_key"), just_content=TRUE, httr_response=FALSE) {
  #restore.point("run_gemini")
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


  parts = list(list(text=prompt))

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


  body = list(
    contents = list(
      parts = parts
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
  if (httr_response) {
    return(res)
  }
  gemini_result_to_df(res)

}

