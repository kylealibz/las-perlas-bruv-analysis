# Las Perlas BRUV Analysis

## Whitetip Reef Shark Habitat Associations in the Las Perlas Archipelago, Panama

This repository contains an R-based marine ecological data analysis completed as part of a **Research Officer recruitment assessment for MarAlliance**.

The assessment involved analysing a supplied BRUV dataset from the **Las Perlas Archipelago, Gulf of Panama**, with the objective of investigating how the relative abundance of **whitetip reef sharks (*Triaenodon obesus*)**, measured using MaxN, varied with **benthic habitat, depth, temperature, and survey period**.

The project required the development of a reproducible analytical workflow in R, including data preparation and validation, calculation of deployment-level MaxN, selection and implementation of an appropriate statistical model, interpretation of ecological patterns, model diagnostics, and graphical presentation of the results. A study-site map was also produced using GIS as part of the original assessment.

This repository is shared as a **professional portfolio example of my R programming, quantitative ecology, marine data analysis, statistical modelling, data visualization, and reproducible research skills**.

## Assessment Context

This analysis was originally completed for the **MarAlliance Research Officer Data Analysis and Mapping Task**.

The assessment required candidates to:

* prepare and combine BRUV effort and sightings data;
* calculate whitetip reef shark MaxN at the deployment level;
* identify and remove unusable deployments;
* derive the February and September survey rounds;
* evaluate the effects of habitat, depth, temperature, and survey round;
* select, fit, and interpret an appropriate statistical model in R;
* produce graphical interpretations of the results; and
* prepare a publication-quality study-site map using QGIS or ArcGIS.

The code presented here reflects my analytical approach to that assessment and is included to demonstrate the technical and ecological reasoning involved in completing the task.

## Data Availability and Ownership

**The underlying BRUV datasets supplied for this assessment are associated with MarAlliance and are not redistributed through this repository.**

The original data files used to conduct the analysis are therefore intentionally excluded from the public repository. Their absence is not an omission required to reproduce the repository structure, but a deliberate measure to respect data ownership, confidentiality, and any applicable data-sharing restrictions.

The original analysis used the following supplied files:

```text
LasPerlas_BRUV_2025_EFFORT.xlsx
LasPerlas_BRUV_2025_SIGHTINGS.xlsx
Las_Perlas_GRTS_sites.csv
```

These files are referenced by the R script because they were required to conduct the original assessment, but copies of the datasets are **not provided here**.

Anyone wishing to use the code with their own data would need to provide datasets with an equivalent structure or modify the relevant import and data-processing sections of the script.

## Attribution

The underlying BRUV data and assessment materials were provided in connection with a **MarAlliance Research Officer recruitment assessment**.

The **R analysis code, statistical workflow, data-processing decisions, model implementation, diagnostics, visualizations, and interpretation presented in this repository represent my assessment work**, except where methods or requirements were specified by the assessment instructions.

This repository is not presented as an official MarAlliance research product, publication, or organizational repository.

## Important Disclaimer

This repository is maintained as a **personal professional portfolio project** documenting work completed during a recruitment assessment.

**MarAlliance is not affiliated with, responsible for, or represented by this GitHub repository.** Inclusion of the organization's name is solely to provide appropriate context and attribution for the assessment and underlying data.

The repository should not be interpreted as indicating employment by, endorsement from, or official representation of MarAlliance.

The underlying assessment datasets should not be copied, redistributed, or republished without appropriate authorization from the relevant data owner.

Any licensing applied to this repository applies **only to material for which I hold the necessary rights, such as my original R code**, and does not grant rights to the underlying MarAlliance-associated datasets, assessment materials, logos, or other third-party content.

