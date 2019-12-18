library(RSocrata)
library(dplyr)
library(plyr)
library(plotly)
library(data.table)
library(readr)
library(httr)
library(jsonlite)
library(r2d3)
library(leaflet)
library(htmltools)
library(shiny)

#chicago_accidents <- read.socrata("https://data.cityofchicago.org/resource/85ca-t3if.json")

csv_url <- "https://data.cityofchicago.org/api/views/85ca-t3if/rows.csv?accessType=DOWNLOAD"
chicago_accidents <- read.socrata(csv_url) %>% data.frame()

chicago_accidents$crash_month_year <- substr(chicago_accidents$crash_date, 1,7)

#df <- read.csv("https://raw.githubusercontent.com/charleyferrari/CUNY_DATA_608/master/module3/data/cleaned-cdc-mortality-1999-2010-2.csv")

ui <- navbarPage(title = "Chicago Accidents Statistics",
                 tabPanel("Chicago Accidents Stats - Introduction",
                          headerPanel("Counts of accidents in Chicago area - over the years"),
                          mainPanel(
                            plotlyOutput('plot1'),
                            headerPanel("Distribution by some important parameters"),
                            tableOutput('traffic_control_device_tbl'),
                            tableOutput('weather_condition_tbl'),
                            tableOutput('lighting_condition_tbl'),
                            tableOutput('prim_contributory_cause_tbl')
                          )
                          ),
                 tabPanel("Monthwise accidents - Fatal or non-Ftal",
                          sidebarPanel(
                            selectInput('month', 'Month', unique(month.abb), selected='Jan'),
                            selectInput('classification', 'Classification of accident - Fatal/non-Fatal', c('Fatal','Non-fatal'))
                            )
                          ,
                          mainPanel(plotlyOutput('class_month_selected_plot'))
                 ),
                 tabPanel("Map and streets",
                          sidebarPanel(
                            div(style="display: inline-block;vertical-align:top; width: 150px;",selectInput("month2", "Month",unique(month.abb), selected='Nov')),
                            div(style="display: inline-block;vertical-align:top; width: 150px;",selectInput("year2", "Year",sort(unique(substr(chicago_accidents$crash_date, 1, 4)), 
                                                                                                                                 decreasing = TRUE), selected='2019')),
                            textOutput("Top 10 streets having maximum # of accidents for the month"),
                            tableOutput('most_accidents_street_tbl')
                            ),
                          
                          mainPanel(h3(textOutput("All accident points for the month")),
                                    h5(textOutput("zoom in - to see further detail points")),
                                    (leafletOutput('month_year_map_plot')))
                 )
                 )

server <- function(input, output, session) {
  
  output$plot1 <- renderPlotly({
    
    plyr::count(chicago_accidents, "crash_month_year") %>% 
      subset(crash_month_year > '2015-09' & crash_month_year < substr(Sys.Date(),1,7)) %>% 
      plot_ly(x = ~crash_month_year, y = ~freq, mode = 'lines', type = 'scatter') %>%
      layout(title = "month wise accidents counts over years")
  })
  
  output$traffic_control_device_tbl <- renderTable({
    traffic_control_device_df <- as.data.frame(plyr::count(chicago_accidents, "traffic_control_device"))
    
    traffic_control_device_df$percent <- traffic_control_device_df$freq * 100 / sum(traffic_control_device_df$freq)
    
    traffic_control_device_df[order(traffic_control_device_df$percent, decreasing = TRUE),]
    
  })
  
  output$weather_condition_tbl <- renderTable({
    weather_condition_df <- as.data.frame(plyr::count(chicago_accidents, "weather_condition"))
    weather_condition_df$percent <- weather_condition_df$freq * 100 / sum(weather_condition_df$freq)
    
    weather_condition_df[order(weather_condition_df$percent, decreasing = TRUE),]
  })
  
  output$lighting_condition_tbl <- renderTable({
    lighting_condition_df <- as.data.frame(plyr::count(chicago_accidents, "lighting_condition"))
    lighting_condition_df$percent <- lighting_condition_df$freq * 100 / sum(lighting_condition_df$freq)
    
    lighting_condition_df[order(lighting_condition_df$percent, decreasing = TRUE),]
  })
  
  output$prim_contributory_cause_tbl <- renderTable({
    prim_contributory_cause_df <- as.data.frame(plyr::count(chicago_accidents, "prim_contributory_cause"))
    prim_contributory_cause_df$percent <- prim_contributory_cause_df$freq * 100 / sum(prim_contributory_cause_df$freq)
    
    prim_contributory_cause_df[order(prim_contributory_cause_df$percent, decreasing = TRUE),]
  })
  #  month_num <- reactive({
  #    match(input$month, month.abb)
  #  })
  
  #  output$month_selected <- renderPlotly({
  #    month_num <- match(input$month, month.abb)
  #    paste("you selected the month: ", month_num)
  #  })
  output$class_month_selected_plot <- renderPlotly({
    month_num <- match(input$month, month.abb)
    if (input$classification == 'Fatal'){
      #      fatal_value <- 1
      
      chicago_accidents %>% subset(injuries_fatal > 0) %>%
        subset(crash_month == month_num) %>%
        plyr::count("roadway_surface_cond") %>%
        plot_ly(x = ~roadway_surface_cond, y = ~freq, type = 'bar') %>%
        layout(yaxis = list(title = 'accidents count'), barmode = 'stack', 
               title = "Fatal Accidents counts per road surface condition - for selected month")
    }
    else {
      #      fatal_value <- 0
      
      chicago_accidents %>% subset(injuries_fatal == 0) %>%
        subset(crash_month == month_num) %>%
        plyr::count("roadway_surface_cond") %>%
        plot_ly(x = ~roadway_surface_cond, y = ~freq, type = 'bar') %>%
        layout(yaxis = list(title = 'value'), barmode = 'stack', 
               title = "Non-Fatal Accidents counts per road surface condition - for selected month")
    }
    
    #    paste("you selected the fatal value: ", fatal_value)
  })
  
  chicago_accidents_year_month_subset2 <- reactive({
    
    month_num2 <- match(input$month2, month.abb)
    
    chicago_accidents %>% subset(crash_month_year == paste(input$year2,"-",month_num2, sep = ""))
    
  })
  
  output$month_year_map_plot <- renderLeaflet({
#    month_num2 <- match(input$month2, month.abb)
    
#    chicago_accidents_year_month_subset2 <- chicago_accidents %>% subset(crash_month_year == paste(year2,"-",month_num2, sep = ""))
    
    leaflet() %>% addTiles() %>% 
      addCircles(data = chicago_accidents_year_month_subset2(), lat = ~as.numeric(as.character(latitude)), lng = ~as.numeric(as.character(longitude)),
                 fillColor = ~injuries_fatal)
  })
  
  output$most_accidents_street_tbl <- renderTable({
    street_count_df <- as.data.frame(plyr::count(chicago_accidents_year_month_subset2(), "street_name"))
    street_count_df[order(street_count_df$freq, decreasing = TRUE),] %>% head(10)
  })
}

shinyApp(ui = ui, server = server)