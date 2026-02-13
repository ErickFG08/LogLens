# Logic: Posit Connect API wrapper using {connectapi}
# https://go.appsilon.com/rhino-project-structure

box::use(
  connectapi[connect, get_content, content_item, get_job_list, get_log],
)

#' Create a connection to Posit Connect
#' Uses CONNECT_SERVER and CONNECT_API_KEY environment variables.
#' @return A Connect R6 object.
#' @export
create_client <- function() {
  connect()
}

#' List all deployed content
#' @param client A Connect R6 object from create_client().
#' @return A data frame with columns: guid, name, title, app_mode, content_url, etc.
#' @export
list_content <- function(client) {
  content <- get_content(client)
  # Keep only the most useful columns and sort by title
  cols_to_keep <- c("guid", "name", "title", "app_mode", "content_url",
                    "created_time", "last_deployed_time")
  available <- intersect(cols_to_keep, names(content))
  result <- content[, available, drop = FALSE]
  # Sort by title (or name if title is missing)
  result$display_name <- ifelse(
    is.na(result$title) | result$title == "",
    result$name,
    result$title
  )
  result <- result[order(result$display_name), ]
  result
}

#' Get jobs for a content item
#' @param client A Connect R6 object.
#' @param content_guid Character. The GUID of the content item.
#' @return A list of job objects (from get_job_list).
#' @export
list_jobs <- function(client, content_guid) {
  content <- content_item(client, content_guid)
  get_job_list(content)
}

#' Get log for a specific job
#' @param job A job object from list_jobs().
#' @return A data frame with columns: source, timestamp, data.
#' @export
fetch_log <- function(job) {
  get_log(job)
}
