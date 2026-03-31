print("--- Sourcing basecode.R ---")
if(!require("tidyverse")) install.packages("tidyverse")
if(!require("htmlTable")) install.packages("htmlTable")
if(!require("broom")) install.packages("broom")
if(!require("labelled")) install.packages("labelled")
if(!require("readxl")) install.packages("readxl")
if (!require("jsonlite")) install.packages("jsonlite")
if (!require("DBI")) install.packages("DBI")
if(!require("RSQLite")) install.packages("RSQLite")

# packages from github
if(!require("remotes")) install.packages("remotes")
library(remotes)
if(!require("devtools")) install.packages("devtools")
library(devtools)
if(!require("tabf")) install_github("jinha-dspub/tabf")
library(tabf)
if(!require("advf")) install_github("jinha-dspub/advf")
library(advf)
library(DBI)
library(RSQLite)
library(tidyverse)

# Global DB Connection for AMH Framework
# 프로젝트 루트 기반 상대경로 우선, 없으면 절대경로 폴백
.find_project_root <- function() {
  wd <- getwd()
  if (grepl("/prj_", wd)) {
    return(sub("(/prj_[^/]+).*$", "\\1", wd))
  }
  return(NULL)
}

.prj_root <- .find_project_root()

# DB 연결: 로컬 현재 폴더 > prj_root > 절대경로 폴백
.db_path <- if (file.exists("kwcs_2023.db")) {
  "kwcs_2023.db"
} else if (!is.null(.prj_root) && file.exists(file.path(.prj_root, "00_source/01_raw_data/kwcs_2023.db"))) {
  file.path(.prj_root, "00_source/01_raw_data/kwcs_2023.db")
} else {
  "/home/aiproject_shared/kwcs_2023.db"
}
con <<- DBI::dbConnect(RSQLite::SQLite(), .db_path)
print(paste("--- DB Connection established:", exists("con"), "| path:", .db_path))

# Questionnaire data (로컬 현재 폴더 > prj_root > 절대경로 폴백)
QUESTIONNAIRE_DIR <- if (dir.exists("questionnaire")) {
  "questionnaire"
} else if (file.exists("questionnaire_full_validated_static.json")) {
  "."  # 현재 폴더에 직접 있는 경우
} else if (!is.null(.prj_root) && dir.exists(file.path(.prj_root, "00_source/questionnaire"))) {
  file.path(.prj_root, "00_source/questionnaire")
} else {
  "/home/aiproject_shared/questionnaire"
}

# 파일 존재 여부 확인 후 로드
json_file <- if (file.exists(file.path(QUESTIONNAIRE_DIR, "questionnaire_full_validated_static.json"))) {
  file.path(QUESTIONNAIRE_DIR, "questionnaire_full_validated_static.json")
} else {
  "questionnaire_full_validated_static.json" # 최악의 경우 현재 폴더 가정
}

questionnaire_json <- if (file.exists(json_file)) {
  jsonlite::fromJSON(json_file)
} else {
  NULL
}

# Suppress VS Code R extension workspace save warnings (Fixing '/tmp/.../vscode-R/workspace.json' error)
if ("vsc.workspace" %in% getTaskCallbackNames()) {
  removeTaskCallback("vsc.workspace")
}

# -------------------------------------------------------------------------
# Dynamic Working Directory Enforcement (Project Root Setting)
# -------------------------------------------------------------------------
# Many environments (React UI temp, code-server `~/aianalytics`, Claude root) 
# have different default `getwd()`. We want relative paths like `04_outputs/plots/` 
# to ALWAYS resolve to the specific user project folder.
tryCatch({
  # Try to infer the project directory path from the getwd()
  current_wd <- getwd()
  
  # If currently inside a project (e.g. /home/st101/aianalytics/prj_hi/01_A_molecules/temp),
  # walk up the tree until we hit a folder starting with "prj_"
  if (grepl("/prj_", current_wd)) {
    # Extract the project root path
    prj_root <- sub("(/prj_[^/]+).*$", "\\1", current_wd)
    if (dir.exists(prj_root)) {
      setwd(prj_root)
      message(paste("✅ Working directory automatically set to project root:", getwd()))
    }
  } else {
    message("⚠️ Not inside a /prj_* directory. Working directory remains:", getwd())
  }
}, error = function(e) {
  message("⚠️ Could not establish dynamic working directory.")
})
