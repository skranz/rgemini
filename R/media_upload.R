#' Upload a document or image to Gemini API.
#'
#'  Returned object or a list of such objects can then be passed to gemini_run.
#'  Media should be available for around an hour.
gemini_media_upload <- function(file_path,
                                mime_type = NULL,
                                display_name = NULL,
                                api_key = getOption("gemini_api_key"),
                                verbose = FALSE) {
  if (is.null(api_key)) {
    stop("Please set an API key by calling set_gemini_api_key.")
  }

  if (length(file_path)>1) {
    results = lapply(seq_along(file_path), function(i) {
      if (verbose) {
        cat("\n", file_path)
      }
      file = file_path[i]
      if (length(mime_type)>=i) mt = mime_type[i] else mt = NULL
      if (length(display_name)>=i) dn = display_name[i] else dn = NULL

      gemini_media_upload(file, mt, dn, api_key, verbose)
    })
    return(results)
  }

  if (!file.exists(file_path)) {
    stop("File does not exist: ", file_path)
  }

  # Use the file name as display_name if not provided.
  if (is.null(display_name)) {
    display_name <- basename(file_path)
  }

  # Determine MIME type if not provided.
  if (is.null(mime_type)) {
    mime_type <- guess_mime_type(file_path)
  }

  # Get file size in bytes.
  file_size <- file.info(file_path)$size

  ## Step 1: Initiate the resumable upload.
  init_url <- paste0("https://generativelanguage.googleapis.com/upload/v1beta/files?key=", api_key)

  init_headers <- add_headers(
    "X-Goog-Upload-Protocol" = "resumable",
    "X-Goog-Upload-Command" = "start",
    "X-Goog-Upload-Header-Content-Length" = file_size,
    "X-Goog-Upload-Header-Content-Type" = mime_type,
    "Content-Type" = "application/json"
  )

  init_body <- toJSON(list(file = list(display_name = display_name)), auto_unbox = TRUE)

  if (verbose) {
    cat("Initiating upload...\n")
    cat("URL:", init_url, "\n")
    cat("Request body:", init_body, "\n")
  }

  init_resp <- POST(url = init_url, body = init_body, config = init_headers)
  init_status <- status_code(init_resp)

  if (verbose) {
    cat("Initiation response status:", init_status, "\n")
  }

  if (init_status != 200) {
    err_text <- content(init_resp, as = "text")
    stop("Failed to initiate upload. Status: ", init_status, "\nResponse: ", err_text)
  }

  # Extract the resumable upload URL from response headers.
  upload_url <- headers(init_resp)[["x-goog-upload-url"]]
  if (is.null(upload_url)) {
    stop("Upload URL not found in response headers.")
  }

  if (verbose) {
    cat("Resumable upload URL obtained:", upload_url, "\n")
  }

  ## Step 2: Upload the file data.
  # Read the file as binary data.
  bin_data <- readBin(file_path, what = "raw", n = file_size)

  upload_headers <- add_headers(
    "Content-Length" = file_size,
    "X-Goog-Upload-Offset" = 0,
    "X-Goog-Upload-Command" = "upload, finalize"
  )

  if (verbose) {
    cat("Uploading file data...\n")
  }

  upload_resp <- POST(url = upload_url, body = bin_data, encode = "raw", config = upload_headers)
  upload_status <- status_code(upload_resp)
  upload_text <- content(upload_resp, as = "text")

  if (verbose) {
    cat("File upload status:", upload_status, "\n")
    cat("File upload response:", upload_text, "\n")
  }

  if (upload_status != 200) {
    stop("Failed to upload file data. Status: ", upload_status, "\nResponse: ", upload_text)
  }

  parsed <- try(fromJSON(upload_text), silent = TRUE)
  if (inherits(parsed, "try-error")) {
    stop("Error parsing upload response: ", upload_text)
  }

  file_uri <- parsed$file$uri
  if (is.null(file_uri)) {
    stop("File URI not found in the upload response.")
  }

  if (verbose) {
    cat("File uploaded successfully. File URI:", file_uri, "\n")
  }

  # Return an object that can be directly used in run_gemini (file_data block)
  return(list(mime_type = mime_type, file_uri = file_uri))
}


guess_mime_type <- function(file_path) {
  ext <- tolower(tools::file_ext(file_path))
  switch(ext,
         "png"  = "image/png",
         "jpg"  = "image/jpeg",
         "jpeg" = "image/jpeg",
         "gif"  = "image/gif",
         "pdf"  = "application/pdf",
         "js"   = "application/x-javascript",  # JavaScript
         "py"   = "text/x-python",              # Python
         "txt"  = "text/plain",
         "html" = "text/html",
         "htm"  = "text/html",
         "css"  = "text/css",
         "md"   = "text/md",                   # Markdown
         "csv"  = "text/csv",
         "xml"  = "text/xml",
         "rtf"  = "text/rtf",
         "r"    = "text/x-r",                  # R scripts
         "do"   = "text/x-stata",              # Stata do-files
         "ado"  = "text/x-stata",              # Stata ado-files
         "application/octet-stream")
}
