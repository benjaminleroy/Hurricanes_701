% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/delta_ball.R
\name{delta_ball_prop_interior}
\alias{delta_ball_prop_interior}
\title{Proportion of true TC steps within delta-ball CB}
\usage{
delta_ball_prop_interior(raw_data_points, truth_points, delta)
}
\arguments{
\item{raw_data_points}{data continuous data frame of individual points 
(in each row)}

\item{truth_points}{data frame of true points}

\item{delta}{radius of each ball inside the union}
}
\value{
in_out_vec boolean vector if point is within delta of raw points
}
\description{
Proportion of true TC steps within delta-ball CB
}
