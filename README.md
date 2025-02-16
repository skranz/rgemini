---
output: 
  html_document: 
    keep_md: yes
---
# R interface to Google Gemini API

Functions to use Gemini API from R. In development. Currently supports:

- Basic prompts
- JSON output also with structured response
- Upload of images, pdf and other documents

See examples below.

# Installation

Soon it should be available on r-universe. Then call:

```r
install.packages('rgemini', repos = c('https://skranz.r-universe.dev', 'https://cloud.r-project.org'))
```

Otherwise try to install directly from Github.

# Examples


## 1. Set API key and Basic prompt


```
## Loading required package: jsonlite
```

```
## Loading required package: httr
```

```
## Loading required package: restorepoint
```

```
## 
## Attaching package: 'rgemini'
```

```
## The following object is masked from 'package:utils':
## 
##     example
```

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

Return more details of Gemini API response (possible error codes etc)


```r
run_gemini("Tell a joke.",just_content = FALSE)
```

```
##              model json_mode temperature error finishReason
## 1 gemini-2.0-flash     FALSE         0.1               STOP
##                                                                   content
## 1 Why don't scientists trust atoms?\n\nBecause they make up everything!\n
```


## 2. JSON mode without schema


```r
run_gemini("Tell 2 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE)
```

```
##         topic                                                              joke
## 1 Programming Why do programmers prefer dark mode? Because light attracts bugs!
## 2        Math            Why was six afraid of seven? Because seven eight nine!
```

If you set just_content=FALSE the content field contents the JSON text.

```r
run_gemini("Tell 2 jokes. Return JSON with fields 'topic' and 'joke'.",json_mode = TRUE,just_content = FALSE)
```

```
##              model json_mode temperature error finishReason
## 1 gemini-2.0-flash      TRUE         0.1               STOP
##                                                                                                                                                                                                                               content
## 1 [\n  {\n    "topic": "Programming",\n    "joke": "Why do programmers prefer dark mode? Because light attracts bugs!"\n  },\n  {\n    "topic": "Math",\n    "joke": "Why was six afraid of seven? Because seven eight nine!"\n  }\n]
```


# 3. JSON mode with a response schema

We use `arr_resp` or `obj_resp` to build an example response, from which `response_schema` builds a proper JSON schema that can be passed to `run_gemini`


```r
prompt = "List 3 asian countries, their capital, the most famous building and the countries' inhabitants in million."

# Creates a schema from an example
schema = response_schema(arr_resp(capital = "Paris", country="France", famous_building="Eiffel Tower", population = 60.1))

run_gemini(prompt = prompt,response_schema = schema)
```

```
##     capital country     famous_building population
## 1     Tokyo   Japan       Tokyo Skytree      125.7
## 2   Beijing   China Great Wall of China     1453.0
## 3 New Delhi   India           Taj Mahal     1408.0
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
  facts = arr_resp(factno=1L, name="fact1", descr="fact_description")
))

# For this schema run_gemini returns a data frame with nested data frames
df = run_gemini(prompt = prompt,response_schema = schema)
str(df)
```

```
## List of 5
##  $ capital        :List of 2
##   ..$ cap_pop: int 4
##   ..$ capital: chr "Nairobi"
##  $ country        : chr "Kenya"
##  $ facts          :'data.frame':	3 obs. of  3 variables:
##   ..$ descr : chr [1:3] "Kenya is known for its diverse wildlife, including lions, elephants, and giraffes." "The Great Rift Valley, a geological fault line, runs through Kenya." "Kenya is a major producer of coffee and tea."
##   ..$ factno: int [1:3] 1 2 3
##   ..$ name  : chr [1:3] "Wildlife" "Great Rift Valley" "Agriculture"
##  $ famous_building: chr "Kenyatta International Conference Centre"
##  $ population     : int 54
```


## 4. Use an image

That is the image we upload:

![image](word_img.png)



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
files = c("~/repbox/gemini/word_img.png", "~/repbox/gemini/colors_pdf.pdf")
media <- gemini_media_upload(files)
run_gemini("Please write down all words you can detect in the uploaded pdf and image.", media=media)
```

```
## [1] "Here are the words I detected in the images:\n\n**From the first image:**\n\n*   Music\n*   Bach\n*   Economics\n*   Physics\n\n**From the second image:**\n\n*   blue\n*   greed\n*   red\n*   white\n*   1"
```

Finally, an example with structured output from the uploaded documents:

```r
run_gemini("Please write down and classify all words you can detect in the uploaded files.", media=media, response_schema = response_schema(arr_resp(file_number=1L, word="blue",type_of_word="")))
```

```
##   file_number type_of_word      word
## 1           1      subject     Music
## 2           1         name      Bach
## 3           1      subject Economics
## 4           1      subject   Physics
## 5           2        color      blue
## 6           2  description     greed
## 7           2        color       red
## 8           2  description     white
```

