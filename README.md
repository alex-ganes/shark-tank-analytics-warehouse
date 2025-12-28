# Shark Tank Analytics Warehouse
**by Alex Ganes**

## Overview

This project is an end-to-end analytics warehouse built to analyze *Shark Tank* deal outcomes across seasons, episodes, companies, and sharks.

The goal is to demonstrate real-world analytics engineering practices, including:
- dimensional modeling
- batch ETL design
- SQL-first transformations
- BI-ready analytics marts
- clear documentation of tradeoffs and data limitations

The warehouse is implemented using Microsoft SQL Server (T-SQL), orchestrated via SSIS, and surfaced through Power BI.

This repository is designed to be:
- easy to understand at a glance via this README
- fully inspectable through SQL, ETL, and BI files
- explicit about modeling decisions and design rationale

## About Shark Tank

*Shark Tank* is a U.S. television business reality show in which entrepreneurs pitch their companies to a panel of investors ("sharks") in hopes of securing funding. The show airs on *ABC* and features a core group of recurring "main sharks", with additional "guest sharks" appearing across certain seasons and episodes.

Each pitch results in either a deal or a rejection, with agreed-upon investment amounts, equity stakes, and deal conditions forming the primary analytical focus of this project.

## Data Sources & References

This project is based on publicly available data and reference material.

### Primary Dataset
- **Shark Tank US Dataset (Kaggle)**  
  [https://www.kaggle.com/datasets/thirumani/shark-tank-us-dataset](https://www.kaggle.com/datasets/thirumani/shark-tank-us-dataset) 
   
  The dataset contains pitch-level information including season, episode, company details, deal outcomes, investment amounts, equity percentages, and select deal attributes. The data was used as provided from the source.

### Supplemental Reference
- **Shark Tank (U.S.) - Wikipedia**  
  [https://en.wikipedia.org/wiki/Shark_Tank](https://en.wikipedia.org/wiki/Shark_Tank) 
   
  Used for high-level contextual validation (e.g., seasons, sharks, and show structure).  
  Wikipedia data was not merged directly into the warehouse and is referenced only for documentation and design discussion.