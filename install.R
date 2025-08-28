# One-time package installer for the project
packages <- c(
  "tm", "wordcloud", "wordcloud2", "syuzhet", "ggplot2",
  "dplyr", "lubridate", "reshape2", "SnowballC", "RColorBrewer"
)
to_install <- setdiff(packages, rownames(installed.packages()))
if (length(to_install)) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All packages already installed.")
}
