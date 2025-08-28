# ================================
# Apple Tweets Sentiment Analysis
# Author: Eva Samitova
# Date: 2025-08
# Unique extras:
#   - Top Positive vs Negative Words (bing lexicon via tidytext)
#   - Sentiment Over Time (daily)
# ================================

# ---------- 0) Install + load packages ----------
needed <- c(
  "tm","wordcloud","syuzhet","ggplot2","dplyr",
  "lubridate","reshape2","SnowballC","RColorBrewer","tidytext"
)
to_install <- setdiff(needed, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")

suppressPackageStartupMessages({
  library(tm)
  library(wordcloud)
  library(syuzhet)
  library(ggplot2)
  library(dplyr)
  library(lubridate)
  library(reshape2)
  library(SnowballC)
  library(RColorBrewer)
  library(tidytext)   # for get_sentiments() and tidy() on TDM
})

set.seed(222)

# ---------- 1) Paths ----------
DATA_PATH <- "C:/Users/User/OneDrive/__Личное__/BELLEVUE COLLEGE/DATA333/apple-sentiment-analytics/apple.csv"
FIG_DIR   <- "figures"
if (!dir.exists(FIG_DIR)) dir.create(FIG_DIR, recursive = TRUE)

# ---------- 2) Load data ----------
apple <- read.csv(DATA_PATH, header = TRUE, stringsAsFactors = FALSE, encoding = "UTF-8")
if (!"text" %in% names(apple)) stop("Expected a 'text' column in apple.csv.")

# If there is no date column, synthesize one so we can show a time plot
if (!"date" %in% names(apple)) {
  apple$date <- seq(Sys.Date() - nrow(apple) + 1, Sys.Date(), by = "1 day")
}
# Make sure it's Date
apple$date <- as.Date(apple$date)

# Clean encoding
tweets <- iconv(apple$text, to = "UTF-8", sub = "byte")
tweets_df <- data.frame(text = tweets, date = apple$date, stringsAsFactors = FALSE)

# ---------- 3) Build & clean corpus ----------
corpus <- VCorpus(VectorSource(tweets_df$text))
to_space <- content_transformer(function(x, pattern) gsub(pattern, " ", x))

corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, to_space, "http[[:alnum:][:punct:]]*")  # URLs
corpus <- tm_map(corpus, removePunctuation)
corpus <- tm_map(corpus, removeNumbers)
corpus <- tm_map(corpus, removeWords, stopwords("english"))
corpus <- tm_map(corpus, removeWords, c("aapl","apple"))         # domain-specific
corpus <- tm_map(corpus, stripWhitespace)
corpus <- tm_map(corpus, stemDocument)

# ---------- 4) Term-Document Matrix & frequencies ----------
tdm <- TermDocumentMatrix(corpus)
tdm_matrix <- as.matrix(tdm)
word_freq <- sort(rowSums(tdm_matrix), decreasing = TRUE)

# Choose top terms for readable barplot (95th percentile or >=10, whichever larger)
cutoff <- max(10, as.numeric(quantile(word_freq, 0.95)))
word_freq_filtered <- word_freq[word_freq >= cutoff]

# ---------- Figure A: Frequent Words Barplot ----------
png(file.path(FIG_DIR, "frequent_words_barplot.png"), width = 1200, height = 800, res = 150)
par(mar = c(10, 5, 3, 1))
barplot(word_freq_filtered,
        las = 2,
        col = rainbow(max(1, length(word_freq_filtered))),
        main = "Frequent Words in Apple Tweets",
        ylab = "Frequency")
dev.off()

# ---------- Figure B: Word Cloud ----------
png(file.path(FIG_DIR, "wordcloud.png"), width = 1200, height = 800, res = 150)
suppressWarnings(
  wordcloud(
    words = names(word_freq),
    freq = unname(as.numeric(word_freq)),
    max.words = 150,
    min.freq = 5,
    random.order = FALSE,
    colors = brewer.pal(8, "Dark2"),
    scale = c(5, 0.3),
    rot.per = 0.3
  )
)
dev.off()

# ---------- 5) NRC sentiment (syuzhet) ----------
sentiment_scores <- get_nrc_sentiment(tweets_df$text)
sent_totals <- colSums(sentiment_scores)

# ---------- Figure C: NRC Sentiment Totals ----------
png(file.path(FIG_DIR, "sentiment_scores_barplot.png"), width = 1200, height = 800, res = 150)
par(mar = c(8, 5, 3, 1))
barplot(sent_totals,
        las = 2,
        col = rainbow(length(sent_totals)),
        ylab = "Count",
        main = "Sentiment Scores from Apple Tweets")
dev.off()

# ---------- 6) UNIQUE Figure D: Top Positive vs Negative Words (bing) ----------
# Use tidytext::tidy() to turn TDM into a long data frame and join with bing lexicon
bing_lex <- get_sentiments("bing")  # sentiments: "positive" / "negative"

tidy_words <- tidy(tdm) %>%                    # columns: term, document, count
  inner_join(bing_lex, by = c(term = "word")) %>%
  group_by(sentiment, term) %>%
  summarise(freq = sum(count), .groups = "drop") %>%
  arrange(desc(freq)) %>%
  group_by(sentiment) %>%
  slice_head(n = 12)                           # top 12 each for a fuller plot

png(file.path(FIG_DIR, "top_pos_neg_words.png"), width = 1200, height = 800, res = 150)
ggplot(tidy_words, aes(x = reorder(term, freq), y = freq, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ sentiment, scales = "free_y") +
  coord_flip() +
  labs(title = "Top Positive vs Negative Words (bing lexicon)",
       x = "Term", y = "Frequency") +
  theme_minimal(base_size = 13)
dev.off()

# ---------- 7) UNIQUE Figure E: Sentiment Over Time (daily) ----------
tweets_df$positive <- sentiment_scores$positive
tweets_df$negative <- sentiment_scores$negative

daily <- tweets_df %>%
  group_by(date) %>%
  summarise(Positive = sum(positive), Negative = sum(negative), .groups = "drop") %>%
  arrange(date)

png(file.path(FIG_DIR, "sentiment_over_time.png"), width = 1200, height = 800, res = 150)
ggplot(daily, aes(x = date)) +
  geom_line(aes(y = Negative, color = "Negative"), linewidth = 1) +
  geom_line(aes(y = Positive, color = "Positive"), linewidth = 1) +
  scale_color_manual(values = c("Negative" = "red", "Positive" = "darkgreen")) +
  labs(title = "Positive vs Negative Sentiment Over Time",
       x = "Date", y = "Count", color = "Sentiment") +
  theme_minimal(base_size = 13)
dev.off()

message("✅ Done. Figures written to: ", normalizePath(FIG_DIR))
