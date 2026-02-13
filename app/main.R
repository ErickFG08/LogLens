box::use(
  shiny[bootstrapPage, div, moduleServer, NS, tags],
  bslib[page_sidebar, sidebar, card, card_header, card_body, bs_theme],
)

box::use(
  app/view/sidebar,
  app/view/log_viewer,
)

#' @export
ui <- function(id) {
  ns <- NS(id)
  page_sidebar(
    title = div(
      class = "app-title",
      tags$span(class = "title-icon", "\U0001F50D"),
      tags$span("LogLens"),
      tags$span(class = "title-sub", "Posit Connect Log Analyser"),
      tags$button(
        id = "theme-toggle",
        class = "theme-toggle",
        title = "Toggle dark / light mode",
        tags$span(class = "theme-icon", "\U0001F319")
      )
    ),
    theme = bs_theme(
      version = 5,
      preset = "shiny",
      bg = "#f1f5f9",
      fg = "#1e293b",
      primary = "#2563eb",
      secondary = "#f8fafc",
      success = "#059669",
      danger = "#dc2626",
      warning = "#d97706",
      info = "#7c3aed",
      base_font = "Inter, system-ui, sans-serif",
      heading_font = "Inter, system-ui, sans-serif",
      font_scale = 0.9
    ),
    sidebar = sidebar(
      width = 300,
      bg = "#ffffff",
      sidebar$ui(ns("sidebar"))
    ),
    card(
      class = "log-card",
      full_screen = TRUE,
      card_body(
        class = "log-card-body p-0",
        log_viewer$ui(ns("log_viewer"))
      )
    )
  )
}

#' @export
server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # sidebar$server returns a reactive with parsed log data
    logs_data <- sidebar$server("sidebar")

    # pass that reactive to log_viewer
    log_viewer$server("log_viewer", logs_data)
  })
}
