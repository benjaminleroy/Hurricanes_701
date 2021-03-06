# Graphics and Tables for section 5.3: 
# "Results" (5) > "Prediction Bands to Predict True Tropical Cyclones" (5.3)

library(tidyverse)
library(reshape2)
library(xtable)
library(forcats)
library(progress)
library(latex2exp)
library(gridExtra)
library(TCpredictionbands)

# theme -----------------

tc_theme <- theme_minimal() + 
  theme(strip.background = element_rect(fill = "grey90", color = NA),
        plot.title = element_text(hjust = 0.5, size = 18),
        strip.text.x = element_text(size = 13),
        strip.text.y = element_text(size = 13),
        axis.title = element_text(size = 14),
        axis.text = element_text(size = 12), 
        legend.title = element_text(size = 14),
        legend.text = element_text(size = 12),
        plot.caption = element_text(size = 10))

# Load Data ------------------

data_loc <- "main/data/"
image_path <- "report/images/"
table_path <- "report/tables/"

latest_full_output_pipeline <- 'output_pipeline_alphalevel0.1_all.Rdata'
a <- load(paste0(data_loc, latest_full_output_pipeline))
eval(parse(text = paste0("output_list_pipeline <- ",a)))




###########################
# Accuracy vs Size of PBs #
###########################

# Process Accuracy and Size information ----------------


acc_size_df <- data.frame(prop_acc = 0, area = 0, tc = "CMU",
                          sim_type = "sim", cb_type = "circles",
                          smart_size = "check") %>%
  mutate(tc = as.character(tc),
         sim_type = as.character(sim_type),
         cb_type = as.character(cb_type),
         smart_size = as.character(smart_size))


if (is.null(names(output_list_pipeline))) {
  warning(paste("output_list_pipeline list missing names.",
          "Renaming output_list_pipeline's entries with test env's names"))
  b <- load(paste0(data_loc,"Test_Sims_350.Rdata"))
  names(output_list_pipeline) <- names(test_env)
}

for (tc in names(output_list_pipeline)) {
  specific_tc_info <- output_list_pipeline[[tc]]

  for (type in names(specific_tc_info)) {


    area_vec <- c(specific_tc_info[[type]][["kde"]][["area"]],
                  specific_tc_info[[type]][["bubble_ci"]][["area"]],
                  specific_tc_info[[type]][["delta_ball"]][["area"]],
                  specific_tc_info[[type]][["convex_hull"]][["area"]]
    )
    convex_hull_vec <- specific_tc_info[[type]][["convex_hull"]][["in_vec"]]

    if (type %in% c("Auto_DeathRegs", "Auto_NoDeathRegs")) {
      convex_hull_vec[1:3] <- 1
    } else {
      convex_hull_vec[1:2] <- 1
    }


    prop_vec <- c(mean(specific_tc_info[[type]][["kde"]][["in_vec"]]),
                  mean(specific_tc_info[[type]][["bubble_ci"]][["in_vec"]]),
                  mean(specific_tc_info[[type]][["delta_ball"]][["in_vec"]]),
                  mean(convex_hull_vec)
    )
    cb_vec <- c("kde", "bubble_ci", "delta_ball", "convex_hull")
    smart_size_vec <- c("small","small","large","large")
    inner_df <- data.frame(prop_acc = prop_vec, area = area_vec,
                           tc = tc, sim_type = type, cb_type = cb_vec,
                           smart_size = smart_size_vec)

    acc_size_df <- rbind(acc_size_df, inner_df)
  }
}

acc_size_df <- acc_size_df[-1,] 

acc_size_df <- acc_size_df %>%
  mutate(prop_acc2 = ifelse(prop_acc == 1, runif(nrow(acc_size_df),1,1.1),
  										   prop_acc))


cb_type_table_levels <- c("Kernel Density Estimate" = "kde",
                          "Spherical" = "bubble_ci",
                          "Delta Ball"     = "delta_ball",
                          "Convex Hull"             = "convex_hull")
cb_type_table_labels <- names(cb_type_table_levels)

cb_type_graphic_levels <- c("Kernel Density Estimate" = "kde",
                            "Spherical" = "bubble_ci",
                            "Delta Ball"     = "delta_ball",
                            "Convex Hull"             = "convex_hull")
cb_type_graphic_labels <- names(cb_type_graphic_levels)

sim_type_table_levels <- c("AR \\& Logistic"     = "Auto_DeathRegs",
                           "AR \\& Kernel"       = "Auto_NoDeathRegs",
                           "Non-AR \\& Logistic" = "NoAuto_DeathRegs",
                           "Non-AR \\& Kernel"   = "NoAuto_NoDeathRegs")
sim_type_table_labels <- names(sim_type_table_levels)

sim_type_graphic_levels <- c("Autoregression & Logistic Death"   = "Auto_DeathRegs",
                           "Autoregression & Kernel Death"       = "Auto_NoDeathRegs",
                           "Non-Autoregression & Logistic Death" = "NoAuto_DeathRegs",
                           "Non-Autoregression & Kernel Death"   = "NoAuto_NoDeathRegs")
sim_type_graphic_labels <- names(sim_type_graphic_levels)

data_run <- acc_size_df %>% mutate(
  cb_type_full = factor(cb_type, levels  = cb_type_graphic_levels,
                        labels = cb_type_graphic_labels),
  sim_type_full = factor(sim_type, levels = sim_type_graphic_levels,
                      labels = sim_type_graphic_labels),
  cb_type_full_table = factor(cb_type, levels = cb_type_table_levels,
                              labels = cb_type_table_labels),
  sim_type_full_table = factor(sim_type, levels = sim_type_table_levels,
                               labels = sim_type_table_labels)) #%>% 

# Visualization Function ------------------

#' add or create a set of boxplots but discretizing continuous variable
#'
#' @param data data frame
#' @param x_string string of column name for x variable (continuous)
#' @param y_string string of column name of y variable (continuous)
#' @param facet_string string of column name for faceting (discrete)
#' @param breaks vector of values for breaks
#' @param base_gg_obj base ggplot to add the graphic onto
#' @param frac fraction of bar width across
#' @param alpha opacity for bar plots fill color
#' @param fill fill color for boxplot
#' @param color line color for boxplot
#'
#' @return ggplot object
#' @export
#'
#' @examples
box_plus_scatter <- function(data, x_string, y_string, facet_string, breaks,
                             base_gg_obj = ggplot(), frac = .9, alpha = .3,
                             fill = "orange", color = "orange"){
  data_new <- data
  data_new[,"x_string_inner_break_ben"] <- cut(x = data_new[,x_string],
                                           breaks = breaks)
  	#^just a new column


  shift <- diff(breaks)*(1 - frac)/2
  lower_breaks <- breaks[-length(breaks)] + shift
  upper_breaks <- breaks[-1] - shift
  middle_of_breaks <- (lower_breaks + upper_breaks)/2

  x_break_df <- data.frame(
  					levels = levels(data_new[,"x_string_inner_break_ben"]),
                    xlower = lower_breaks,
                    xupper = upper_breaks,
                    xmiddle = middle_of_breaks)

  data_new <- data_new %>% left_join(x_break_df,
                by = c("x_string_inner_break_ben" = "levels"))

  data_new[,"my_y"] <- data_new[,y_string]

  group_by_columns <- c("x_string_inner_break_ben", facet_string)

  data_sum <- data_new %>%
    group_by_at(vars(one_of(group_by_columns))) %>%
    summarize(ymax = max(my_y),
              q75 = quantile(my_y, probs = .75),
              median = median(my_y),
              q25 = quantile(my_y, probs = .25),
              ymin = min(my_y),
              xlower = max(xlower),
              xupper = max(xupper),
              xmiddle = max(xmiddle)) %>%
    mutate(iqr = q75 - q25)

    # mutate wouldn't work correctly with min/ max functions
    a <- ifelse(data_sum$ymax > data_sum$q75 + 1.5*data_sum$iqr,
                data_sum$q75 + 1.5*data_sum$iqr, data_sum$ymax)
    b <- ifelse(data_sum$ymin < data_sum$q25 - 1.5*data_sum$iqr,
                data_sum$q25 - 1.5*data_sum$iqr, data_sum$ymin)

    data_sum$upper <- a
    data_sum$lower <- b

  ggout <- base_gg_obj +
    geom_rect(data = data_sum,
              aes(xmin = xlower, xmax = xupper,
                  ymin = q25, ymax = q75),
              alpha = alpha, color = color, fill = fill) +
    geom_segment(data = data_sum, # median
                 aes(x = xlower, xend = xupper, y = median, yend = median),
                 color = color, size = 1) +
    geom_segment(data = data_sum, # upper
                 aes(x = xmiddle, xend = xmiddle, y = q75, yend = upper),
                 color = color) +
    geom_segment(data = data_sum, # lower
                 aes(x = xmiddle, xend = xmiddle, y = q25, yend = lower),
                 color = color)

    return(ggout)
}


# Actual Graphics -------------

large_acc_vs_area <- data_run %>%
						filter(smart_size == "large", area < 3250) %>%
  ggplot() +
  geom_point(aes(x = area, y = prop_acc2),alpha = .15) +
  facet_grid(~cb_type_full, scales = "free_x" ) +
  geom_hline(yintercept = 1) +  tc_theme +
  scale_x_continuous(breaks = seq(0, 3250, by = 250)) +
  theme(axis.text.x = element_text(angle = 90)) +
  labs(y = "Proportion Captured", x = "Area")

large_acc_vs_area2 <- box_plus_scatter(data = data_run %>%
							filter(smart_size == "large", area < 3250),
                 x_string = "area", y_string = "prop_acc",
                 facet_string = "cb_type_full",
                 breaks = seq(0,3309,by = 250),
                 base_gg_obj = large_acc_vs_area,
                 frac = .7, fill = rgb(1, 0.3, 0.3, .7), 
                 color = rgb(1, 0.3, 0.3, .7),
                 alpha = .1)

large_acc_vs_area_final <- large_acc_vs_area2 +
								geom_smooth(aes(x = area, y = prop_acc))




small_acc_vs_area <- data_run %>%
  						filter(smart_size == "small",area < 2400) %>%
  ggplot() +   
  geom_point(aes(x = area, y = prop_acc2),alpha = .15) +
  facet_grid(~cb_type_full, scales = "free_x" ) +
  geom_hline(yintercept = 1) +  
  tc_theme +
  scale_x_continuous(breaks = seq(0, 2400, by = 125), lim = c(0, 2400)) +
  theme(axis.text.x = element_text(angle = 90)) +
  labs(y = "Proportion Captured", x = "Area")

small_acc_vs_area2 <- box_plus_scatter(
				data = data_run %>% filter(smart_size == "small",area < 2400),
                 x_string = "area", y_string = "prop_acc",
                 facet_string = "cb_type_full",
                 breaks = seq(0,2400,by = 125), base_gg_obj = small_acc_vs_area,
                 frac = .7, fill = rgb(1,0.3,0.3,.7), color = rgb(1,0.3,0.3,.7),
                 alpha = .1)

small_acc_vs_area_final <- small_acc_vs_area2 +
								geom_smooth(aes(x = area, y = prop_acc))

arrangement <- arrangeGrob(large_acc_vs_area_final +
						labs(title = "Larger Prediction Bands",
                             x = "Area in Square Nautical Miles (maximum = 3250)"),
             small_acc_vs_area_final + 
             			labs(title = "Smaller Prediction Bands",
                              x = "Area in Square Nautical Miles (maximum = 2400)"), ncol = 1)

ggsave(plot = arrangement,
	   filename = paste0(image_path,"tc_results_area_vs_prop.png"),
	   device = "png", width = 10, height = 6.5, units = "in")

# Tables ------------

# ~ bolding solution from https://stackoverflow.com/questions/33218469/boldify-the-contents-of-bottom-row-in-xtable
bold_somerows <- function(x) gsub('BOLD(.*)',paste0('\\\\textbf{\\1','}'),x)

# ~ for multistacked headers: https://cran.r-project.org/web/packages/xtable/vignettes/xtableGallery.pdf
#   page: 27
#   in Latex file you'll need need:
#         \newcolumntype{L}[1]{>{\raggedright\let\newline\\
#         \arraybackslash\hspace{0pt}}b{#1}}
#         \newcolumntype{C}[1]{>{\centering\let\newline\\
#         \arraybackslash\hspace{0pt}}b{#1}}
#         \newcolumntype{R}[1]{>{\raggedleft\let\newline\\
#         \arraybackslash\hspace{0pt}}b{#1}}
#         \newcolumntype{P}[1]{>{\raggedright\tabularxbackslash}p{#1}}
#  

# average proportion captured 
table <- data_run %>% 
  group_by(sim_type_full_table, cb_type_full_table) %>%
  dplyr::summarize(
    full_acc = sprintf("%.2f / %.2f" ,
                       round(mean(prop_acc),2),
                       round(median(prop_acc),2)) ) %>%
  dcast(sim_type_full_table ~ cb_type_full_table) %>%
  rename("Simulation Curve Type" = "sim_type_full_table")

addtorow <- list()
addtorow$pos <- list(0)
addtorow$command <- c("\\hline \\hline \\\\\n")

xtable1 <- table %>% xtable(align = c("rR{1.5in}L{1.1in}L{.95in}L{.95in}L{.95in}"),
                 digits = 2,
                 caption = paste("Mean / median proportion of true test TC", 
                                 "points captured by their PBs."),
                 label = "tab:average_captured",
                 add.to.row = addtorow)

print(xtable1, 
      table.placement = "h!",
      include.rownames = FALSE,
      sanitize.text.function = identity, 
      caption.placement = "top",
      hline.after = c(-1, -1, 0, 4),
      file = paste0(table_path,"tc_average_proportion_update.tex"))

# proportion with capture above .3, .9, =1

# ~ adding math in caption from https://cran.r-project.org/web/packages/xtable/vignettes/xtableGallery.pdf
#   and https://www.sharelatex.com/learn/Mathematical_expressions 

table2 <- data_run %>%
  group_by(sim_type_full_table, cb_type_full_table) %>%
  dplyr::summarize(
    both = paste0(sprintf("%.2f",round(mean(prop_acc >= .30),2)),
                  " / ",
                  sprintf("%.2f",round(mean(prop_acc >= .90),2)),
                  " BOLD(",
                  sprintf("%.2f",round(mean(prop_acc >= 1), 2)),
                   ")")) %>%
  dcast(sim_type_full_table ~ cb_type_full_table) %>%
  rename("Simulation Curve Type" = "sim_type_full_table")


xtable2 <- xtable(table2, align = c("rR{1.4in}L{1.1in}L{.95in}L{.95in}L{.95in}"),
                 caption = paste("Proportion of test TCs with", 
                                 "($\\geq 30\\%$) / ($\\geq 90\\%$)", 
                                 "\\textbf{(= 100\\%)} of", 
                                 "points captured."),
                 label = "tab:prop_captured")

print(xtable2, 
      table.placement = "h!",
      include.rownames = FALSE,
      sanitize.text.function = bold_somerows,
      caption.placement = "top",
      hline.after = c(-1, -1, 0, 4),
      file = paste0(table_path,"tc_prop_above_p3p9p10.tex"))
