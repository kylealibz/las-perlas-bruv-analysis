# Store the names of every add-on package required by the analysis.
required_packages <- c("readxl", "dplyr", "ggplot2", "MASS", "nlme", "gridExtra")
# Test whether each required package is installed without attaching it.
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
# Enter this block only if at least one required package is unavailable.
if (length(missing_packages) > 0) {
  # Stop the analysis and list the packages the user must install manually.
  stop(
    "Please install the following packages before running the analysis: ",
    paste(missing_packages, collapse = ", ")
  )
}


library(readxl)
library(dplyr)
library(ggplot2)
library(MASS)
library(nlme)
library(gridExtra)

# Fix the random number stream so simulation diagnostics are reproducible.
set.seed(2025)

# Read all command-line arguments supplied when the script was launched.
args <- commandArgs(trailingOnly = FALSE)
# Locate the argument containing the path of this script when run with Rscript.
script_arg <- grep("^--file=", args, value = TRUE)
# If the script path is available, make its folder the working directory.
if (length(script_arg) == 1) setwd(dirname(normalizePath(sub("^--file=", "", script_arg))))

# Construct the path of the folder that will contain every analysis output.
output_dir <- file.path(getwd(), "analysis_outputs")
# Create the output folder and any missing parent folders without issuing warnings.
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Store the exact filenames of the three required source datasets.
files <- c(
  "LasPerlas_BRUV_2025_EFFORT.xlsx",
  "LasPerlas_BRUV_2025_SIGHTINGS.xlsx",
  "Las_Perlas_GRTS_sites.csv"
)
# List the folders in which the script will search for all three datasets.
candidate_dirs <- c(file.path(getwd(), "data"), getwd(),
                    "C:/Users/heate/OneDrive/Desktop", "C:/Users/heate/Downloads")
# Retain only candidate folders that contain every required source file.
data_dirs <- candidate_dirs[vapply(candidate_dirs, function(x) all(file.exists(file.path(x, files))), logical(1))]
# Stop with a clear message if no complete data folder was found.
if (!length(data_dirs)) stop("The three source files were not found.")
# Use the first folder containing a complete set of source files.
data_dir <- data_dirs[1]

# Import deployment effort records from the first Excel workbook.
effort <- read_excel(file.path(data_dir, files[1]))
# Import all organism sighting records from the second Excel workbook.
sightings <- read_excel(file.path(data_dir, files[2]))
# Import the GRTS site-design CSV without changing its original column names.
sites_raw <- read.csv(file.path(data_dir, files[3]), check.names = FALSE)

# Build a compact audit table containing the row count of each raw dataset.
data_dimensions <- data.frame(
  Table = c("EFFORT", "SIGHTINGS", "GRTS sites"),
  Rows = c(nrow(effort), nrow(sightings), nrow(sites_raw))
)
# Export the raw-data dimension audit without an unnecessary row-number column.
write.csv(data_dimensions, file.path(output_dir, "Table_S1_raw_data_dimensions.csv"), row.names = FALSE)

# Convert deployment dates and derive the survey round from the recorded month.
effort <- effort %>% mutate(
  Date = as.Date(Date),
  survey_round = case_when(
    format(Date, "%m") == "02" ~ "February",
    format(Date, "%m") == "09" ~ "September",
    TRUE ~ NA_character_
  )
)

# Stop if any deployment date cannot be assigned to an expected survey round.
if (anyNA(effort$survey_round)) stop("A deployment falls outside February or September.")

# Count effort rows and distinct rounds for every location code to audit uniqueness.
key_audit <- effort %>% count(Location_Code, name = "Effort_rows") %>%
  left_join(effort %>% distinct(Location_Code, survey_round) %>%
              count(Location_Code, name = "Survey_rounds"), by = "Location_Code")
# Export the deployment-key audit for transparent verification.
write.csv(key_audit, file.path(output_dir, "Table_S1b_deployment_key_audit.csv"), row.names = FALSE)

# Stop before joining if a location code identifies more than one deployment.
if (any(key_audit$Effort_rows > 1)) {
  stop("Location_Code is not unique. Add survey_round or a deployment ID to the sightings workbook before joining.")
}
# Stop if any sighting lacks a matching deployment in the effort data.
if (any(!sightings$Location_Code %in% effort$Location_Code)) {
  stop("At least one sighting has no matching effort deployment.")
}

# Copy the verified unique location code into an explicitly named deployment key.
effort <- effort %>% mutate(Deployment_ID = Location_Code)
# Create the same deployment key in the sightings table for the later join.
sightings <- sightings %>% mutate(Deployment_ID = Location_Code)

# Retain whitetip records and calculate the largest simultaneous count per deployment.
maxn <- sightings %>%
  filter(Species == "Triobe") %>%
  group_by(Deployment_ID) %>%
  summarise(MaxN = max(N, na.rm = TRUE), .groups = "drop")

# List the exact effort-note phrases that indicate unusable video deployments.
failed_notes <- c("Camera flooded - no footage", "Frame lost on retrieval",
                  "Battery failure - no recording", "GoPro corrupted file")

# Join MaxN to every effort deployment and construct analysis fields and exclusions.
deployments <- effort %>%
  left_join(maxn, by = "Deployment_ID") %>%
  mutate(
    MaxN = coalesce(MaxN, 0),
    Round = factor(survey_round, levels = c("February", "September")),
    Site = factor(match(paste(Latitude, Longitude), unique(paste(Latitude, Longitude)))),
    Usable_video = is.na(Notes) | !Notes %in% failed_notes,
    Exclusion_reason = case_when(
      !Usable_video ~ Notes,
      is.na(Temp_C) ~ "Missing temperature",
      TRUE ~ "Included"
    )
  )

# Export the complete deployment-level audit trail before applying exclusions.
write.csv(deployments, file.path(output_dir, "Table_S2_all_deployments_with_exclusions.csv"), row.names = FALSE)

# Retain usable complete records, set reference categories and centre covariates.
analysis_data <- deployments %>%
  filter(Usable_video) %>%
  filter(complete.cases(MaxN, Habitat, Depth_m, Temp_C, Round, Site)) %>%
  mutate(
    Habitat = relevel(factor(Habitat), ref = "Sand"),
    Depth_c = Depth_m - mean(Depth_m),
    Temp_c = Temp_C - mean(Temp_C)
  )

# Confirm that the response is a valid non-negative integer count.
if (any(analysis_data$MaxN < 0 | analysis_data$MaxN != floor(analysis_data$MaxN))) {
  stop("MaxN must contain non-negative integers.")
}
# Confirm that multiple sites remain so a site-level random effect is estimable.
if (nlevels(droplevels(analysis_data$Site)) < 2) stop("At least two sites are required.")

# Export the exact cleaned dataset supplied to the statistical models.
write.csv(analysis_data, file.path(output_dir, "Table_S3_cleaned_whitetip_deployments.csv"), row.names = FALSE)

# Estimate the negative-binomial shape parameter with a fixed-effects model.
initial_nb <- glm.nb(MaxN ~ Habitat + Depth_c + Temp_c + Round, data = analysis_data)
# Store the estimated negative-binomial shape parameter for the mixed model.
theta <- initial_nb$theta

# Fit the requested repeated-site negative-binomial mixed model.
full_model <- glmmPQL(
  # Specify habitat, centred depth, centred temperature and round as fixed effects.
  fixed = MaxN ~ Habitat + Depth_c + Temp_c + Round,
  # Include a random intercept to account for repeated observations within sites.
  random = ~ 1 | Site,
  # Use a log-linked negative-binomial response distribution with the estimated shape.
  family = negative.binomial(theta = theta, link = "log"),
  # Supply the cleaned deployment-level dataset to the model.
  data = analysis_data,
  # Suppress iteration-by-iteration output during fitting.
  verbose = FALSE,
  # Allow sufficient mixed-model iterations and return the fitted object.
  control = lmeControl(msMaxIter = 200, niterEM = 50, returnObject = TRUE)
)

# Extract the fixed-effect coefficient table from the fitted mixed model.
coef_matrix <- summary(full_model)$tTable
# Convert model coefficients into a clearly labelled reporting table.
coef_table <- data.frame(
  Term = rownames(coef_matrix),
  Log_coefficient = coef_matrix[, "Value"],
  SE = coef_matrix[, "Std.Error"],
  df = coef_matrix[, "DF"],
  t = coef_matrix[, "t-value"],
  p = coef_matrix[, "p-value"],
  row.names = NULL
) %>% mutate(
  # Exponentiate log coefficients to obtain incidence-rate ratios.
  IRR = exp(Log_coefficient),
  # Calculate the lower Wald 95% confidence limit on the IRR scale.
  CI_low = exp(Log_coefficient - 1.96 * SE),
  # Calculate the upper Wald 95% confidence limit on the IRR scale.
  CI_high = exp(Log_coefficient + 1.96 * SE)
)
# Export coefficient estimates, uncertainty, tests and effect sizes.
write.csv(coef_table, file.path(output_dir, "Table_3_model_coefficients_and_IRRs.csv"), row.names = FALSE)

# Omnibus Wald tests calculated without refitting reduced models.
beta <- fixed.effects(full_model)
# Extract the variance-covariance matrix of the fixed-effect estimates.
V <- vcov(full_model)
# Define a reusable function that calculates a joint Wald chi-square test.
wald <- function(index) {
  # Select the coefficients included in the requested term test.
  b <- beta[index]
  # Select the matching covariance submatrix while preserving matrix dimensions.
  VV <- V[index, index, drop = FALSE]
  # Calculate the Wald quadratic form for the selected coefficient set.
  chisq <- as.numeric(t(b) %*% solve(VV, b))
  # Return degrees of freedom, chi-square statistic and upper-tail p-value.
  data.frame(df = length(index), Chi_square = chisq,
             p = pchisq(chisq, length(index), lower.tail = FALSE))
}
# Map each conceptual predictor to its coefficient position or positions.
term_indices <- list(
  Habitat = grep("^Habitat", names(beta)),
  Depth = which(names(beta) == "Depth_c"),
  Temperature = which(names(beta) == "Temp_c"),
  Survey_round = which(names(beta) == "RoundSeptember")
)
# Apply the Wald function to every predictor and combine the results by row.
term_tests <- bind_rows(lapply(names(term_indices), function(x) {
  cbind(Predictor = x, wald(term_indices[[x]]))
}))
# Export the predictor-level omnibus Wald tests.
write.csv(term_tests, file.path(output_dir, "Table_4_predictor_Wald_tests.csv"), row.names = FALSE)

# Jointly test all fixed predictors while excluding the intercept.
overall_test <- wald(which(names(beta) != "(Intercept)"))
# Add a plain-language description of the overall hypothesis test.
overall_test$Comparison <- "Joint Wald test of all fixed predictors"
# Export the overall fixed-effect test.
write.csv(overall_test, file.path(output_dir, "Table_5_overall_model_test.csv"), row.names = FALSE)

# Summarise sample size, detections and MaxN distribution separately by round.
round_summary <- analysis_data %>% group_by(Round) %>% summarise(
  Deployments = n(), Detections = sum(MaxN > 0), Detection_rate = mean(MaxN > 0),
  Mean_MaxN = mean(MaxN), SD_MaxN = sd(MaxN), Median_MaxN = median(MaxN),
  Maximum_MaxN = max(MaxN), .groups = "drop")
# Summarise sample size, detections and MaxN distribution separately by habitat.
habitat_summary <- analysis_data %>% group_by(Habitat) %>% summarise(
  Deployments = n(), Detections = sum(MaxN > 0), Detection_rate = mean(MaxN > 0),
  Mean_MaxN = mean(MaxN), SD_MaxN = sd(MaxN), Median_MaxN = median(MaxN),
  Maximum_MaxN = max(MaxN), .groups = "drop")
# Export the survey-round descriptive summary.
write.csv(round_summary, file.path(output_dir, "Table_1_summary_by_round.csv"), row.names = FALSE)
# Export the habitat descriptive summary.
write.csv(habitat_summary, file.path(output_dir, "Table_2_summary_by_habitat.csv"), row.names = FALSE)

# Select and rename GRTS design fields for a clean GIS-compatible site table.
qgis_sites <- sites_raw %>% transmute(
  Site_ID = siteID, Habitat = habitat, Site_use = siteuse,
  Replacement = replsite, Longitude = lon, Latitude = lat,
  Design_weight = wgt, Inclusion_probability = ip
)
# Export the GIS-ready site table in WGS84 coordinates.
write.csv(qgis_sites, file.path(output_dir, "QGIS_Las_Perlas_GRTS_sites_WGS84.csv"), row.names = FALSE)

# Extract the estimated standard deviation of the site random intercept.
random_sd <- as.numeric(VarCorr(full_model)[1, "StdDev"])
# Assemble core model-method and sample-size information for reporting.
model_info <- data.frame(
  Method = "Negative-binomial GLMM fitted by penalized quasi-likelihood",
  NB_theta = theta,
  Site_random_intercept_SD = random_sd,
  Deployments = nrow(analysis_data),
  Sites = nlevels(droplevels(analysis_data$Site))
)
# Export the model-method, shape parameter and random-effect information.
write.csv(model_info, file.path(output_dir, "Table_S4_model_information.csv"), row.names = FALSE)

#### GRAPHS ####

# Assign a consistent publication colour to each habitat category.
habitat_colours <- c(
  "Sand" = "#D8AE53", "Coral/Algae" = "#259D91",
  "Rock" = "#4D4D4D", "Rubble" = "#909090"
)
# Assign contrasting colours to the two survey rounds.
round_colours <- c("February" = "#247BA0", "September" = "#E07A3F")

# Start the observed-data graph with habitat on the x-axis and MaxN on the y-axis.
observed_plot <- ggplot(analysis_data, aes(Habitat, MaxN, colour = Habitat)) +
  # Add habitat-specific boxplots while hiding their default outlier symbols.
  geom_boxplot(width = 0.55, outlier.shape = NA, alpha = 0.15) +
  # Add jittered deployment observations and distinguish survey rounds by point shape.
  geom_jitter(aes(shape = Round), width = 0.16, height = 0.04,
              size = 2.1, alpha = 0.75) +
  # Apply the predefined habitat colours.
  scale_colour_manual(values = habitat_colours) +
  # Display integer count values as y-axis tick marks.
  scale_y_continuous(breaks = 0:max(analysis_data$MaxN)) +
  # Hide the redundant habitat-colour legend.
  guides(colour = "none") +
  # Label the observed-response axis and survey-round shape legend.
  labs(x = NULL, y = "Observed whitetip reef shark MaxN", shape = "Survey round") +
  # Apply a clean publication theme.
  theme_classic(base_size = 11) +
  # Angle habitat labels and position the remaining legend beneath the graph.
  theme(axis.text.x = element_text(angle = 22, hjust = 1), legend.position = "bottom")
# Save the observed MaxN graph as a high-resolution PNG.
ggsave(file.path(output_dir, "Figure_S1_observed_MaxN.png"), observed_plot,
       width = 7.2, height = 4.6, dpi = 320, bg = "white")

#### DIAGNOSTICS AND ZERO CHECK ####

# Assemble fitted values and residuals for every analysed deployment.
diagnostic_data <- data.frame(
  Deployment_ID = analysis_data$Deployment_ID,
  Location_Code = analysis_data$Location_Code,
  Site = analysis_data$Site,
  Fitted = exp(as.numeric(fitted(full_model))),
  Pearson_residual = as.numeric(residuals(full_model, type = "pearson")),
  Response_residual = as.numeric(residuals(full_model, type = "response"))
)

# glmmPQL/lme returns fitted values on the log-link scale. Confirm the scale
# conversion explicitly and prevent a mislabeled diagnostic graph.
# Record the range of fitted values returned on the model's log-link scale.
fitted_link_range <- range(as.numeric(fitted(full_model)), na.rm = TRUE)
# Exponentiate the fitted values and record their response-scale range.
fitted_response_range <- range(exp(as.numeric(fitted(full_model))), na.rm = TRUE)
# Stop if response-scale fitted expected counts are invalid or negative.
if (any(!is.finite(diagnostic_data$Fitted)) || any(diagnostic_data$Fitted < 0)) {
  stop("Response-scale fitted expected MaxN values must be finite and non-negative.")
}
# Export both ranges so the fitted-value scale conversion remains auditable.
write.csv(
  data.frame(
    Scale = c("Link scale", "Response scale (expected MaxN)"),
    Minimum = c(fitted_link_range[1], fitted_response_range[1]),
    Maximum = c(fitted_link_range[2], fitted_response_range[2])
  ),
  file.path(output_dir, "Table_S6b_fitted_value_scale_check.csv"),
  row.names = FALSE
)
# Export deployment-level fitted values and residuals.
write.csv(diagnostic_data, file.path(output_dir, "Table_S6_deployment_model_diagnostics.csv"), row.names = FALSE)

# Parametric simulation from the fitted fixed effects, site random intercept,
# and negative-binomial distribution.
# Construct the fixed-effect design matrix for the observed deployments.
X_observed <- model.matrix(~ Habitat + Depth_c + Temp_c + Round, data = analysis_data)
# Convert site factor levels to integer indices used during simulation.
site_number <- as.integer(droplevels(analysis_data$Site))
# Store the total number of represented sites.
n_sites <- max(site_number)
# Set the number of complete datasets to simulate.
nsim <- 1000
# Allocate a vector that will store one zero proportion per simulation.
simulated_zero_rates <- numeric(nsim)
# Repeat the following simulation procedure 1,000 times.
for (i in seq_len(nsim)) {
  # Draw one normally distributed random intercept for every site.
  simulated_site_effect <- rnorm(n_sites, mean = 0, sd = random_sd)
  # Calculate response-scale expected MaxN including each simulated site effect.
  simulated_mu <- exp(as.numeric(X_observed %*% beta) + simulated_site_effect[site_number])
  # Draw negative-binomial MaxN counts using the simulated means and fitted shape.
  simulated_response <- rnbinom(nrow(analysis_data), size = theta, mu = simulated_mu)
  # Store the proportion of simulated deployments with MaxN equal to zero.
  simulated_zero_rates[i] <- mean(simulated_response == 0)
}
# Calculate the zero proportion actually observed in the cleaned dataset.
observed_zero_rate <- mean(analysis_data$MaxN == 0)
# Summarise the observed and simulated zero proportions.
zero_check <- data.frame(
  Observed_zero_rate = observed_zero_rate,
  Simulated_median = median(simulated_zero_rates),
  Simulated_2.5_percent = unname(quantile(simulated_zero_rates, 0.025)),
  Simulated_97.5_percent = unname(quantile(simulated_zero_rates, 0.975))
)
# Export the simulation-based zero-frequency diagnostic.
write.csv(zero_check, file.path(output_dir, "Table_S5_simulation_zero_check.csv"), row.names = FALSE)

# Plot Pearson residuals against response-scale fitted expected MaxN.
residual_plot <- ggplot(diagnostic_data, aes(Fitted, Pearson_residual)) +
  # Add a dashed horizontal reference line at zero residual.
  geom_hline(yintercept = 0, linetype = 2, colour = "#6B7479") +
  # Add one semi-transparent point for each analysed deployment.
  geom_point(colour = "#126E75", alpha = 0.72, size = 2) +
  # Add a LOESS curve to reveal systematic residual patterns.
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
              colour = "#D07B27", linewidth = 0.8) +
  labs(x = "Fitted expected MaxN", y = "Pearson residual",
       title = "A  Residual pattern") +
  theme_classic(base_size = 11)

# Plot the distribution of zero proportions obtained from simulated datasets.
zero_plot <- ggplot(data.frame(Zero_rate = simulated_zero_rates), aes(Zero_rate)) +
  # Display the simulated distribution as a histogram.
  geom_histogram(bins = 25, fill = "#8CCAC4", colour = "white") +
  # Mark the observed zero proportion with a vertical red line.
  geom_vline(xintercept = observed_zero_rate, colour = "#C64A3A", linewidth = 1.1) +
  labs(x = "Proportion of zero MaxN deployments", y = "Simulated datasets",
       title = "B  Simulation check", subtitle = "Red line = observed proportion") +
  theme_classic(base_size = 11)

# Arrange the residual and zero-frequency diagnostics in two columns.
diagnostic_figure <- arrangeGrob(residual_plot, zero_plot, ncol = 2)
# Save the combined diagnostic figure as a high-resolution PNG.
ggsave(file.path(output_dir, "Figure_S2_model_diagnostics.png"), diagnostic_figure,
       width = 8.2, height = 4.2, dpi = 320, bg = "white")

#### ADJUSTED PREDICTIONS ####

# Define a function that produces fixed-effect predictions and Wald intervals.
fixed_prediction <- function(newdata) {
  # Construct the prediction design matrix using the fitted fixed-effect structure.
  X <- model.matrix(~ Habitat + Depth_c + Temp_c + Round, data = newdata)
  # Calculate predicted values on the log-link scale with site effect fixed at zero.
  eta <- as.numeric(X %*% beta)
  # Propagate coefficient uncertainty to obtain log-scale prediction standard errors.
  eta_se <- sqrt(pmax(0, diag(X %*% V %*% t(X))))
  # Return expected MaxN and 95% confidence limits on the response scale.
  data.frame(
    Expected_MaxN = exp(eta),
    CI_low = exp(eta - 1.96 * eta_se),
    CI_high = exp(eta + 1.96 * eta_se)
  )
}

# Create every habitat-by-round combination at mean depth and temperature.
habitat_predictions <- expand.grid(
  Habitat = levels(analysis_data$Habitat),
  Round = levels(analysis_data$Round),
  Depth_c = 0,
  Temp_c = 0
)
# Give habitat in the prediction grid the same factor ordering as the model data.
habitat_predictions$Habitat <- factor(habitat_predictions$Habitat,
                                      levels = levels(analysis_data$Habitat))
# Give round in the prediction grid the same factor ordering as the model data.
habitat_predictions$Round <- factor(habitat_predictions$Round,
                                    levels = levels(analysis_data$Round))
# Calculate fixed-effect expected MaxN and confidence intervals for the grid.
habitat_predictions <- cbind(habitat_predictions, fixed_prediction(habitat_predictions))
# Export the complete habitat-by-round prediction table.
write.csv(habitat_predictions, file.path(output_dir, "Table_6_adjusted_habitat_round_predictions.csv"), row.names = FALSE)

# Create a depth sequence for every habitat in February at mean temperature.
depth_predictions <- expand.grid(
  Depth_m = seq(min(analysis_data$Depth_m), max(analysis_data$Depth_m), length.out = 100),
  Habitat = levels(analysis_data$Habitat),
  Round = "February",
  Temp_c = 0
)
# Match the depth grid's habitat factor ordering to the fitted model.
depth_predictions$Habitat <- factor(depth_predictions$Habitat,
                                    levels = levels(analysis_data$Habitat))
# Match the depth grid's round factor ordering to the fitted model.
depth_predictions$Round <- factor(depth_predictions$Round,
                                  levels = levels(analysis_data$Round))
# Centre prediction depths using the same observed mean used during model fitting.
depth_predictions$Depth_c <- depth_predictions$Depth_m - mean(analysis_data$Depth_m)
# Calculate fixed-effect expected MaxN and confidence intervals across depth.
depth_predictions <- cbind(depth_predictions, fixed_prediction(depth_predictions))
# Export every value used to construct the depth-effect figure.
write.csv(depth_predictions, file.path(output_dir, "Table_S7_adjusted_depth_predictions.csv"), row.names = FALSE)

# Start the adjusted habitat-and-round prediction graph.
habitat_effect_plot <- ggplot(
  habitat_predictions,
  aes(Habitat, Expected_MaxN, colour = Round, shape = Round, group = Round)
) +
  # Add expected MaxN points and their 95% confidence intervals.
  geom_pointrange(aes(ymin = CI_low, ymax = CI_high),
                  position = position_dodge(width = 0.46), linewidth = 0.65, size = 1.2) +
  # Apply the predefined survey-round colours.
  scale_colour_manual(values = round_colours) +
  # Assign a different point shape to each survey round.
  scale_shape_manual(values = c("February" = 16, "September" = 17)) +
  # Add vertical space around the expected-MaxN scale.
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.12))) +
  # Add axis, legend, title and fixed-effect interpretation labels.
  labs(x = "Benthic habitat", y = "Adjusted expected MaxN",
       colour = "Survey round", shape = "Survey round",
       title = "Whitetip reef shark abundance by habitat and survey round",
       subtitle = "Fixed-effect estimates at mean depth and temperature; bars show 95% CIs") +
  theme_classic(base_size = 12) +
  theme(plot.title = element_text(face = "bold", colour = "#173D4B", size = 14),
        plot.subtitle = element_text(colour = "#53666E", size = 10),
        legend.position = "right")
# Save the adjusted habitat-and-round graph as a high-resolution PNG.
ggsave(file.path(output_dir, "Figure_2_habitat_and_season.png"), habitat_effect_plot,
       width = 7.8, height = 5.0, dpi = 320, bg = "white")

# Start the adjusted depth-response graph using habitat-specific colours and fills.
depth_effect_plot <- ggplot(
  depth_predictions,
  aes(Depth_m, Expected_MaxN, colour = Habitat, fill = Habitat)
) +
  # Draw translucent 95% confidence ribbons around each predicted depth curve.
  geom_ribbon(aes(ymin = CI_low, ymax = CI_high), alpha = 0.18, colour = NA) +
  # Draw the fixed-effect expected-MaxN relationship across depth.
  geom_line(linewidth = 1.05) +
  # Place each habitat in a separate panel to prevent overlapping ribbons.
  facet_wrap(~ Habitat, ncol = 2) +
  # Apply the predefined habitat line colours.
  scale_colour_manual(values = habitat_colours) +
  # Apply matching habitat ribbon colours.
  scale_fill_manual(values = habitat_colours) +
  # Add axes, title and prediction-condition subtitle.
  labs(x = "Depth (m)", y = "Adjusted expected MaxN",
       title = "Predicted relationship between depth and whitetip reef shark MaxN",
       subtitle = "February estimates at mean temperature; shading shows 95% CIs") +
  theme_classic(base_size = 12) +
  theme(plot.title = element_text(face = "bold", colour = "#173D4B", size = 14),
        plot.subtitle = element_text(colour = "#53666E", size = 10),
        strip.background = element_rect(fill = "#EAF3F2", colour = "#B8CECC"),
        strip.text = element_text(face = "bold", colour = "#173D4B"),
        legend.position = "none")
# Save the adjusted depth graph as a high-resolution PNG.
ggsave(file.path(output_dir, "Figure_3_depth_relationship.png"), depth_effect_plot,
       width = 8.2, height = 6.5, dpi = 320, bg = "white")

# Display the main figures in the RStudio Plots pane during an interactive run.
if (interactive()) {
  print(observed_plot)
  print(habitat_effect_plot)
  print(depth_effect_plot)
  print(residual_plot)
  print(zero_plot)
}

# Save fitted models, prepared data, results and predictions for later reuse.
save(full_model, initial_nb, analysis_data, coef_table, term_tests,
     habitat_predictions, depth_predictions,
     file = file.path(output_dir, "Las_Perlas_BRUV_analysis_objects.RData"))
# Record R, operating-system and package-version information for reproducibility.
writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))

# Print a clear completion heading in the R console.
cat("\nAnalysis completed successfully.\n")
# Print the number of deployments analysed by the model.
cat("Deployments:", nrow(analysis_data), "\n")
# Print the number of physical sites represented in the model.
cat("Sites:", nlevels(droplevels(analysis_data$Site)), "\n")
glcat("Negative-binomial theta:", theta, "\n")
# Print the estimated standard deviation of the site random intercept.
cat("Site random-intercept SD:", random_sd, "\n\n")
# Print the complete fitted mixed-model summary.
print(summary(full_model))
# Print the predictor-level Wald tests.
print(term_tests)
# Report the absolute folder containing all analysis outputs.
message("Results written to: ", normalizePath(output_dir))
