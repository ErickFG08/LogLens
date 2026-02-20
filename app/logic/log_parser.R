# Logic: Parse and classify log lines
# https://go.appsilon.com/rhino-project-structure

box::use(
  dplyr[case_when],
)

#' Classify a log message into a severity level
#'
#' Inspects the message text for known keywords (ERROR, WARN, INFO, DEBUG, TRACE).
#' Falls back to the source field (stdout/stderr) when no keyword is found.
#'
#' @param message Character. The log message text.
#' @param source Character. "stdout" or "stderr".
#' @return Character. One of: "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "STDOUT", "STDERR".
#' @export
classify_level <- function(message, source) {
  msg_upper <- toupper(message)

  case_when(
    grepl("\\bERROR\\b|\\bFATAL\\b|\\bCRITICAL\\b", msg_upper) ~ "ERROR",
    grepl("\\bWARN(ING)?\\b", msg_upper) ~ "WARN",
    grepl("\\bINFO\\b", msg_upper) ~ "INFO",
    grepl("\\bDEBUG\\b", msg_upper) ~ "DEBUG",
    grepl("\\bTRACE\\b", msg_upper) ~ "TRACE",
    source == "stderr" ~ "STDERR",
    TRUE ~ "STDOUT"
  )
}

#' Parse a log data frame from connectapi::get_log()
#'
#' Adds a `level` column based on message content and source.
#'
#' @param log_df A data frame with columns: source, timestamp, data.
#' @return A data frame with additional columns: line_number, level.
#' @export
parse_log <- function(log_df) {
  if (is.null(log_df) || nrow(log_df) == 0) {
    return(data.frame(
      line_number = integer(0),
      timestamp = character(0),
      source = character(0),
      level = character(0),
      message = character(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    line_number = seq_len(nrow(log_df)),
    timestamp = as.character(log_df$timestamp),
    source = log_df$source,
    level = classify_level(log_df$data, log_df$source),
    message = log_df$data,
    stringsAsFactors = FALSE
  )
}

#' Get CSS class for a log level
#' @param level Character. The log level.
#' @return Character. CSS class name.
#' @export
level_css_class <- function(level) {
  case_when(
    level == "ERROR" ~ "log-error",
    level == "WARN" ~ "log-warn",
    level == "INFO" ~ "log-info",
    level == "DEBUG" ~ "log-debug",
    level == "TRACE" ~ "log-trace",
    level == "STDERR" ~ "log-stderr",
    level == "STDOUT" ~ "log-stdout",
    TRUE ~ "log-default"
  )
}

#' Get display colour for a log level
#' @param level Character. The log level.
#' @return Named character vector with "bg" and "fg" colours.
#' @export
level_colors <- function(level) {
  colors <- list(
    ERROR  = c(bg = "#ef4444", fg = "#ffffff"),
    WARN   = c(bg = "#f59e0b", fg = "#1a1a2e"),
    INFO   = c(bg = "#3b82f6", fg = "#ffffff"),
    DEBUG  = c(bg = "#8b5cf6", fg = "#ffffff"),
    TRACE  = c(bg = "#6b7280", fg = "#ffffff"),
    STDERR = c(bg = "#f43f5e", fg = "#ffffff"),
    STDOUT = c(bg = "#10b981", fg = "#ffffff")
  )
  if (level %in% names(colors)) colors[[level]] else c(bg = "#374151", fg = "#ffffff")
}
