# Logic: Parse and format job start times from Posit Connect metadata
# https://go.appsilon.com/rhino-project-structure

na_posixct <- function() {
  as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
}

normalize_timezone_offset <- function(timestamp) {
  if (!grepl("[+-][0-9]{2}:[0-9]{2}$", timestamp)) {
    return(timestamp)
  }

  # Convert +HH:MM to +HHMM for %z parsing on systems that reject the colon form.
  prefix <- substr(timestamp, 1, nchar(timestamp) - 3)
  suffix <- gsub(":", "", substr(timestamp, nchar(timestamp) - 2, nchar(timestamp)), fixed = TRUE)
  paste0(prefix, suffix)
}

has_clock_time <- function(timestamp) {
  grepl("(T|\\s)[0-9]{2}:[0-9]{2}", timestamp)
}

#' Parse a job start time into POSIXct
#' @param start_time A start_time value from a Connect job.
#' @return POSIXct in UTC, or NA when parsing fails.
#' @export
parse_job_start_time <- function(start_time) {
  if (is.null(start_time) || length(start_time) == 0) {
    return(na_posixct())
  }

  value <- if (is.list(start_time)) start_time[[1]] else start_time[1]
  if (is.null(value) || length(value) == 0 || is.na(value[1])) {
    return(na_posixct())
  }

  if (inherits(value, "POSIXt")) {
    return(as.POSIXct(value, tz = "UTC"))
  }

  if (inherits(value, "Date")) {
    return(as.POSIXct(value, tz = "UTC"))
  }

  if (is.numeric(value)) {
    return(as.POSIXct(value, origin = "1970-01-01", tz = "UTC"))
  }

  timestamp <- trimws(as.character(value))
  if (!nzchar(timestamp)) {
    return(na_posixct())
  }

  normalized <- normalize_timezone_offset(timestamp)
  formats <- c(
    "%Y-%m-%dT%H:%M:%OSZ",
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%dT%H:%M:%OS%z",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%d %H:%M:%OS",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%dT%H:%MZ",
    "%Y-%m-%dT%H:%M%z",
    "%Y-%m-%d %H:%M"
  )

  for (fmt in formats) {
    parsed <- suppressWarnings(strptime(normalized, format = fmt, tz = "UTC"))
    if (!is.na(parsed)) {
      return(as.POSIXct(parsed, tz = "UTC"))
    }
  }

  # Avoid silently collapsing full timestamps to midnight when parsing fails.
  if (has_clock_time(timestamp)) {
    return(na_posixct())
  }

  parsed_date <- suppressWarnings(strptime(timestamp, format = "%Y-%m-%d", tz = "UTC"))
  if (is.na(parsed_date)) {
    return(na_posixct())
  }

  as.POSIXct(parsed_date, tz = "UTC")
}

#' Format a job start time for UI labels
#' @param start_time A start_time value from a Connect job.
#' @return Character scalar such as "Feb 13, 14:30" or "unknown date".
#' @export
format_job_start_time <- function(start_time) {
  time_obj <- parse_job_start_time(start_time)
  if (is.na(time_obj)) {
    return("unknown date")
  }

  format(time_obj, "%b %d, %H:%M")
}
