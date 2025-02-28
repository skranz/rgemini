---
output: 
  html_document: 
    keep_md: yes
---
# R interface to Google Gemini API

Functions to use Gemini from R. In development. Currently supports:

- Basic prompts
- JSON output also with structured response
- Upload of images, pdf and other documents

See examples below.

# Installation

Best install from r-universe:

```r
install.packages('rgemini', repos = c('https://skranz.r-universe.dev', 'https://cloud.r-project.org'))
```

Otherwise try to install directly from Github:

```r
if (!requireNamespace("remotes", quietly = TRUE)) { install.packages("remotes") }
remotes::install_github("skranz/rgemini") 
```

# Examples


## 1. Set API key and Basic prompt


Load library and specify API key.

```r
library(rgemini)
set_gemini_api_key("<YOUR GEMINI API KEY>")
```

A simple prompt.

```r
run_gemini("Tell a joke.")
```

```
## [1] "Why don't scientists trust atoms?\n\nBecause they make up everything!\n"
```

Return more details of Gemini API response.


```r
details = run_gemini("Tell a joke.",detailed_results = TRUE)
# str(details)
```

The returned `details` are a large list with all sort of information.

## 2. JSON mode


```r
run_gemini("Tell 2 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE)
```

```
##         topic                                                              joke
## 1 Programming Why do programmers prefer dark mode? Because light attracts bugs!
## 2        Math            Why was six afraid of seven? Because seven eight nine!
```


# 3. JSON mode with a response schema

The Gemini API also allows to provide JSON response schemas (see https://json-schema.org/learn/getting-started-step-by-step) for better guarantees that your JSON output satisfies a desired structure.

`rgemini` has small helper functions `arr_resp`, `obj_resp` and `response_schema` to build simple json schemas from an example. 


```r
prompt = "List 3 asian countries, their capital, the most famous building and the countries' inhabitants in million."

# Creates a schema from an example
schema = response_schema(arr_resp(obj_resp(capital = "Paris", country="France", famous_building="Eiffel Tower", population = 60.1)))

run_gemini(prompt = prompt,response_schema = schema)
```

```
##   capital     country      famous_building population
## 1   Tokyo       Japan        Tokyo Skytree     125.70
## 2 Beijing       China  Great Wall of China    1453.00
## 3   Seoul South Korea Gyeongbokgung Palace      51.75
```

Here is a more comples nested schema. Will return nested tibbles.


```r
prompt = "Show info for one african country, its capital with name and population in mio, the most famous building and inhabitants in million. Add three facts about the country."

# obj_resp expects to return a single object
# arr_resp expected a list of objects
# Both can be nested
schema = response_schema(obj_resp(
  capital = obj_resp(capital="Paris", cap_pop=5),
  country="France", famous_building="Eiffel Tower",
  population = 60.2,
  facts = arr_resp(obj_resp(factno=1L, name="fact1", descr="fact_description"))
))

# For this schema run_gemini currently
# returns a list (obj_resp) or data frame (arr_resp) with nested data frames
res = run_gemini(prompt = prompt,response_schema = schema)
str(res)
```

```
## List of 5
##  $ capital        :List of 2
##   ..$ cap_pop: int 4
##   ..$ capital: chr "Nairobi"
##  $ country        : chr "Kenya"
##  $ facts          :'data.frame':	3 obs. of  3 variables:
##   ..$ descr : chr [1:3] "Kenya is known for its safaris and diverse wildlife reserves." "Kenya is home to numerous world-renowned athletes, particularly in long-distance running." "Kenya is a major producer of coffee and tea, contributing significantly to its economy."
##   ..$ factno: int [1:3] 1 2 3
##   ..$ name  : chr [1:3] "Wildlife Safaris" "Athletic Prowess" "Agricultural Exports"
##  $ famous_building: chr "Kenyatta International Conference Centre"
##  $ population     : int 55
```


Two things to note:

- From my experience with larger tasks providing a schema does not always improve things, I often got better output without a schema. But that might change.

- I am currently building the package `DataSchema` (https://github.com/skranz/DataSchema) that will allow more complex schema specifications.


## 4. Use an image

That is the image we upload:

![image](docs/word_img.png)



```r
img_file = paste0("~/repbox/gemini/word_img.png")
media <- gemini_media_upload(img_file)
run_gemini("Please write down all words you can detect in the image.", media=media)
```

```
## [1] "Here are the words I can detect in the image:\n\n*   Music\n*   Bach\n*   Economics\n*   Physics"
```


## 5. Use a PDF and an Image


```r
files = c("docs/word_img.png", "docs/colors_pdf.pdf")
media <- gemini_media_upload(files)
run_gemini("Please write down all words you can detect in the uploaded pdf and image.", media=media)
```

```
## [1] "Here are the words I detected in the images:\n\n**From the first image:**\n\n*   Music\n*   Bach\n*   Economics\n*   Physics\n\n**From the second image:**\n\n*   blue\n*   greed\n*   red\n*   white\n*   1"
```

## 6. Context caching

The gemini API also allows context caching (see https://ai.google.dev/gemini-api/docs/caching). Context caching can e.g. be helpful if you have repeated prompts to the same large PDF document (or a set of PDF documents). 

To use context caching you can generate a context object with `gemini_context` and pass it to `gemini_run`. I have not yet made a nice example for this README though.

## 7. Get information about available gemini models

Use a `gemini_list_models()` function to get a data frame with information about all available models at the Gemini API. 


```r
gemini_list_models() %>% 
  filter(startsWith(displayName, "Gemini 2"))
```

```
## Warning: Outer names are only allowed for unnamed scalar atomic inputs
```

```
## # A tibble: 25 × 11
##    name    version displayName  description     inputTokenLimit outputTokenLimit
##    <chr>   <chr>   <chr>        <chr>                     <int>            <int>
##  1 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
##  2 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
##  3 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
##  4 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
##  5 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
##  6 models… 2.0     Gemini 2.0 … Stable version…         1048576             8192
##  7 models… 2.0     Gemini 2.0 … Stable version…         1048576             8192
##  8 models… 2.0     Gemini 2.0 … Stable version…         1048576             8192
##  9 models… 2.0     Gemini 2.0 … Stable version…         1048576             8192
## 10 models… 2.0     Gemini 2.0 … Gemini 2.0 Fla…         1048576             8192
## # … with 15 more rows, and 5 more variables: supportedGenerationMethods <list>,
## #   temperature <dbl>, topP <dbl>, topK <int>, maxTemperature <int>
```

