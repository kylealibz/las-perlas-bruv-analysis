# Las Perlas BRUV Analysis

## Whitetip Reef Shark Habitat Associations in the Las Perlas Archipelago, Panama

This repository presents an **R-based marine ecological analysis** completed as part of a **Research Officer recruitment assessment for MarAlliance**. The assessment used a supplied Baited Remote Underwater Video (BRUV) dataset from the **Las Perlas Archipelago, Gulf of Panama**, to investigate variation in the relative abundance of **whitetip reef sharks (*Triaenodon obesus*)**.

Relative abundance was quantified using **MaxN**, the maximum number of individuals observed simultaneously during a BRUV deployment. The analysis examined how MaxN varied in relation to **benthic habitat, depth, temperature, and survey round**.

The repository is maintained as a professional portfolio example demonstrating skills in **R programming, marine ecological data analysis, statistical modelling, data visualization, model diagnostics, GIS integration, and reproducible research**.

---

## Assessment Context

The project was completed for the **MarAlliance Research Officer Data Analysis and Mapping Task**.

The assessment required:

* preparation and integration of BRUV effort and sightings data;
* calculation of deployment-level whitetip reef shark MaxN;
* identification and exclusion of unusable deployments;
* derivation of February and September survey rounds;
* evaluation of habitat, depth, temperature, and survey-round effects on MaxN;
* selection, implementation, and interpretation of an appropriate statistical model in R;
* production of graphical interpretations of the results; and
* preparation of a publication-quality study-site map using QGIS or ArcGIS.

The R script in this repository documents the analytical workflow developed for the assessment.

---

## Study Overview

The analysis focuses on BRUV deployments conducted in the **Las Perlas Archipelago**, located in the Gulf of Panama.

Four benthic habitat categories were represented:

* **Coral/Algae**
* **Rock**
* **Rubble**
* **Sand**

Sampling was conducted across two survey rounds:

* **February 2025**
* **September 2025**

The species of interest was the **whitetip reef shark (*Triaenodon obesus*)**.

### Response Variable

Shark relative abundance was represented using **MaxN**.

MaxN is the greatest number of individuals of a species observed simultaneously within a BRUV deployment. This approach helps reduce the risk of repeatedly counting the same individual as it enters and leaves the camera's field of view.

Deployments with usable footage but no recorded whitetip reef sharks were assigned a MaxN of zero.

---

## Analytical Workflow

The analysis was designed as a reproducible workflow progressing from the original BRUV records through data validation, modelling, diagnostics, predictions, and graphical outputs.

### 1. Data Import and Validation

The script:

* imports BRUV effort and sightings data;
* imports the associated GRTS site-design information;
* derives survey round from deployment dates;
* checks deployment identifiers for uniqueness;
* verifies that sightings correspond to valid effort deployments; and
* creates an audit trail of the imported datasets.

### 2. MaxN Calculation and Data Cleaning

Whitetip reef shark records are extracted from the sightings dataset and summarized to obtain the maximum simultaneous count for each deployment.

The workflow then:

* joins MaxN values to deployment-level effort data;
* assigns zero values to deployments without whitetip detections;
* identifies deployments with unusable video;
* identifies records with missing required environmental information;
* retains complete observations for statistical analysis; and
* exports the cleaned analytical dataset and exclusion information for verification.

### 3. Statistical Modelling

MaxN is non-negative count data, so the analysis uses a **negative-binomial modelling framework**.

An initial negative-binomial generalized linear model is used to estimate the dispersion parameter. The primary analysis then uses a **negative-binomial generalized linear mixed model fitted by penalized quasi-likelihood**.

The model evaluates:

```text
MaxN ~ Habitat + Depth + Temperature + Survey Round + (1 | Site)
```

### Fixed Effects

* Benthic habitat
* Depth
* Temperature
* Survey round

### Random Effect

* Sampling site

The site-level random intercept accounts for repeated observations associated with the same sampling locations.

**Sand** is used as the habitat reference category and **February** as the survey-round reference. Depth and temperature are mean-centred before model fitting.

---

## Model Interpretation

Fixed-effect coefficients are exponentiated and reported as **incidence-rate ratios (IRRs)** with 95% confidence intervals.

For categorical predictors:

* **IRR > 1** indicates higher expected MaxN relative to the reference category.
* **IRR < 1** indicates lower expected MaxN relative to the reference category.

For continuous predictors such as depth and temperature, the IRR represents the multiplicative change in expected MaxN associated with a one-unit increase in the predictor while holding the other model variables constant.

Predictor-level and overall **Wald tests** are also generated to evaluate statistical evidence for the model terms.

---

## Model Diagnostics

The workflow includes diagnostic procedures to evaluate model performance.

### Residual Diagnostics

Pearson residuals are compared with fitted expected MaxN values to identify potential systematic patterns or model misspecification.

### Simulation-Based Zero Check

A simulation-based diagnostic evaluates whether the negative-binomial model adequately reproduces the observed frequency of zero-MaxN deployments.

The procedure:

1. simulates site-level random effects;
2. calculates expected MaxN from the fitted model;
3. generates negative-binomial response counts;
4. repeats the process across **1,000 simulated datasets**; and
5. compares the observed proportion of zero-MaxN deployments with the simulated distribution.

---

## Adjusted Predictions and Visualization

The script produces model-adjusted predictions to help visualize the ecological relationships identified by the analysis.

### Habitat and Survey Round

Expected MaxN is estimated for each habitat and survey-round combination while holding depth and temperature at their observed means and the site random effect at zero.

### Depth

Expected MaxN is predicted across the observed depth range for each habitat under standardized model conditions.

Predictions are accompanied by **95% confidence intervals**.

The workflow also generates high-resolution figures showing:

* observed MaxN among habitats;
* model diagnostics;
* adjusted habitat and survey-round relationships; and
* predicted relationships between depth and whitetip reef shark MaxN.

---

## Reproducibility

The R workflow incorporates several features intended to make the analysis transparent and reproducible, including:

* automated package checks;
* a fixed random seed for simulation diagnostics;
* source-file validation;
* deployment-key validation;
* explicit exclusion criteria;
* exported data-cleaning audit information;
* exported model coefficients and IRRs;
* exported Wald tests;
* exported adjusted predictions;
* saved fitted model objects; and
* recorded R session and package-version information.

The analysis uses the following R packages:

```r
readxl
dplyr
ggplot2
MASS
nlme
gridExtra
```

---

## Repository Contents

```text
las-perlas-bruv-analysis/
│
├── Kyle_Ali_Las_Perlas_BRUV_Analysis.R
├── README.md
├── LICENSE
└── .gitignore
```

### `Kyle_Ali_Las_Perlas_BRUV_Analysis.R`

Contains the complete R workflow for:

* data import and validation;
* deployment-level MaxN calculation;
* data cleaning and exclusions;
* negative-binomial modelling;
* mixed-effects analysis;
* coefficient and IRR extraction;
* Wald hypothesis testing;
* model diagnostics;
* simulation-based zero checking;
* adjusted predictions;
* figure generation; and
* export of analytical outputs.

---

## Running the Analysis

The original source datasets are not distributed with this repository.

Users with appropriately structured and authorized datasets can adapt the script by providing equivalent input files or modifying the data-import and processing sections.

The original workflow references:

```text
LasPerlas_BRUV_2025_EFFORT.xlsx
LasPerlas_BRUV_2025_SIGHTINGS.xlsx
Las_Perlas_GRTS_sites.csv
```

When the appropriate data are available, the analysis script can be run in R using:

```r
source("Kyle_Ali_Las_Perlas_BRUV_Analysis.R")
```

Generated tables, figures, diagnostics, predictions, and model objects are written to an `analysis_outputs/` directory.

---

## Data Availability and Ownership

The underlying BRUV datasets used for this assessment were supplied in connection with the **MarAlliance Research Officer recruitment assessment** and are **not redistributed through this repository**.

The source datasets have been intentionally excluded from the public repository to respect data ownership, confidentiality, and applicable data-sharing restrictions.

The filenames remain referenced within the R script solely because they formed the inputs to the original analytical workflow. Their inclusion as file references should not be interpreted as permission to obtain, reproduce, or redistribute the underlying datasets.

Researchers wishing to adapt this workflow should use their own appropriately authorized data and modify the import and data-processing sections where necessary.

---

## Attribution

The BRUV data and assessment materials used to develop this analysis were supplied in connection with a **MarAlliance Research Officer recruitment assessment**.

The R code and analytical implementation contained in this repository document my work on that assessment, except where particular methods, objectives, datasets, or requirements were specified by the assessment materials.

This repository is a **personal professional portfolio project** and is not an official MarAlliance research product, publication, or organizational repository.

---

## Skills Demonstrated

This project demonstrates experience with:

* **R programming**
* **Marine ecological data analysis**
* **BRUV data processing**
* **Ecological count data**
* **Negative-binomial modelling**
* **Generalized linear mixed models**
* **Data cleaning and validation**
* **Model diagnostics**
* **Simulation-based model checking**
* **Statistical inference**
* **Adjusted model predictions**
* **Data visualization with ggplot2**
* **GIS-compatible data preparation**
* **Reproducible research workflows**

---

## Author

**Kyle Ali**
BSc Marine Biology
University of Belize

Research interests include **marine ecology, fisheries science, shark ecology, marine conservation, spatial analysis, and quantitative ecological methods**.

---

## Disclaimer

This repository documents work undertaken as part of a recruitment assessment and is provided for **professional portfolio and educational purposes**.

**MarAlliance is not affiliated with, responsible for, or represented by this GitHub repository.** Reference to MarAlliance is included to accurately describe the context in which the assessment and associated data were provided.

Nothing in this repository should be interpreted as indicating employment by, endorsement from, or official representation of MarAlliance.

BRUV-derived MaxN is interpreted as an index of **relative abundance rather than absolute population abundance**. Relationships identified by the analysis represent statistical associations within the sampled deployments and environmental conditions and should not automatically be interpreted as causal relationships.

---

## License

The original R code in this repository is provided under the **MIT License**.

The license applies only to material for which the repository author holds the necessary rights. It **does not grant any rights to the underlying BRUV datasets, MarAlliance assessment materials, logos, or other third-party content**.

The underlying datasets should not be copied, redistributed, or republished without appropriate authorization from the relevant rights holder.

