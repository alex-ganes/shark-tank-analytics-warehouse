# Shark Tank Analytics Warehouse
**ETL Portfolio by Alex Ganes**

## Overview
This project implements a complete, production-style analytics data warehouse for Shark Tank pitch and deal data, designed to reflect how a small analytics warehouse might be built in a constrained local environment (SQL Server Express / LocalDB).

It demonstrates ingestion, dimensional modeling, fact construction, orchestration, and BI-ready aggregation using SQL Server, SSIS, and Windows Task Scheduler.

The focus of this project is on data modeling decisions, ETL design, and operational realism, rather than exploratory analysis alone.

---

## Project Highlights

- Star-schema warehouse with clearly defined grain
- Deterministic, re-runnable warehouse load procedure
- SSIS-based staging ingestion with file handling
- Automated orchestration with Windows Task Scheduler
- BI-friendly analytics marts with validated outputs
- Explicit modeling tradeoffs and documented limitations

---

## About the Dataset

*Shark Tank* is a U.S. television business reality show in which entrepreneurs pitch companies to a panel of investors ("sharks") in exchange for funding. The show features a recurring set of main sharks, with additional guest sharks appearing across select seasons and episodes.

Each pitch results in either a deal or a rejection, with investment amounts, equity stakes, and deal conditions forming the primary analytical focus of this project.

---

## Data Sources & References

This project is based on publicly available data and reference material.

### Primary Dataset
- **Shark Tank US Dataset (Kaggle)**  
  https://www.kaggle.com/datasets/thirumani/shark-tank-us-dataset  

  This CSV dataset contains pitch-level information including season, episode, company details, deal outcomes, investment amounts, equity percentages, and select deal attributes. Data was used as provided from the source without alteration. The dataset is updated quarterly, with the most recent version cutting off mid-Season 17.

### Supplemental Reference
- **Shark Tank (U.S.) - Wikipedia**  
  https://en.wikipedia.org/wiki/Shark_Tank  

  Used for high-level contextual validation (ex: seasons, sharks, and show structure). Wikipedia data was not merged directly into the warehouse.

---

## Architecture Overview

### Database
- `SharkTankDWH` – Analytics database for the project

### Schemas
- `stage` – Raw CSV landing tables
- `dwh` – Dimensional warehouse (dimensions + facts)
- `analytics` – Aggregate, BI-ready views (data marts)

---

## Core Warehouse Objects

### Dimensions
- `dwh.dim_shark` – One row per shark  
- `dwh.dim_business` – One row per startup  
- `dwh.dim_season` – One row per season  
- `dwh.dim_episode` – One row per episode  
- `dwh.dim_date` – Standard calendar dimension  

### Facts
- `dwh.fact_pitch` – Stores pitch outcomes and deal-level attributes. **Grain**: one row per business-episode.

- `dwh.fact_deal_shark` – Captures investment amounts and equity by shark. **Grain**: one row per pitch-shark where a deal was made.

### Analytics Marts
- `analytics.vw_alltime_summary` – Overall aggregated metrics
- `analytics.vw_season_summary` – Season-level aggregated metrics
- `analytics.vw_episode_summary` – Episode-level aggregated metrics
- `analytics.vw_shark_alltime_summary` – Overall shark-level metrics

Note: These analytical mart views are designed as a direct consumption layer for BI tools (ex: Power BI, Tableau), with metrics pre-aggregated to minimize semantic modeling downstream.

### Star Schema
                           dwh.dim_date
                               ▲
                               │
                ┌──────────────┴────────────────┐
                │                               │
        dwh.dim_season                    dwh.dim_episode
        (1 row / season)                 (1 row / episode)
                │                               ▲
                │                               │
                └──────────────┬────────────────┘
                               │
                         dwh.fact_pitch
                (1 row / business × episode pitch)
                               │
               ┌───────────────┴────────────────┐
               │                                │
      dwh.dim_business                   dwh.fact_deal_shark
      (1 row / startup)             (1 row / pitch × shark deal)
                                                │
                                                │
                                          dwh.dim_shark
                                         (1 row / shark)


---

## Core Warehouse Load

### Stored Procedures
`EXEC dwh.load_shark_tank_dw;`

This procedure is the single source of truth for populating the warehouse.

It performs the following steps in order:
1. Upserts all dimensions  
2. Loads pitch-level and shark-level facts  
3. Applies deterministic natural keys  
4. Truncates staging only after successful completion  

The procedure is safe to re-run for the same batch.

`EXEC dwh.populate_dim_date @start_year = <INT>, @end_year = <INT>;`

This procedure populates the date dimension (`dwh.dim_date`) for a specified year range. It generates one row per calendar date and derives common date attributes such as day of week, month name, and related calendar fields.

---

## Data Modeling Decisions & Tradeoffs

### Dimension Strategy
All dimensions are modeled as Type 1:
- Overwrite on match  
- No historical versioning retained  

This approach prioritizes simplicity and analytical clarity for this dataset. Especially since it will not realistically receive frequent updates.

---

### Fact Strategy
Facts are modeled as event records:
- Append-only  
- Source deletions do not retract historical facts  

If a fact required removal, it would be handled explicitly via a controlled delete.

---

### Main Sharks vs Guest Sharks
The dataset defines a fixed set of "main" sharks using pivoted columns. In reality, main shark status can change over time. The source dataset was not modified to enforce this.

In a production setting with accurate historical role data, main-shark status would be more appropriately modeled as a Type 2 slowly changing dimension, allowing role changes to be tracked across seasons and time periods.

<p>
  <img src="Resources/Images/Wikipedia - Shark Status Over Time.png" alt="SSIS Control Flow" width="600"/>
</p>
Source reference: https://en.wikipedia.org/wiki/Shark_Tank

---

### Guest Shark Parsing
Guest sharks appear in a free-text field and may contain:
- One name  
- Multiple names (ex: "Alexis Ohanian, and Kendra Scott")  
- Multi-name entities (ex: "Chip and Joanna Gaines")  

Handling strategy:
- Normalize delimiters  
- Split into individual shark names  
- Preserve multi-name entities as a single shark  
- Allocate investment amounts evenly when multiple guests appear  

---

### Demographic Fields
Certain demographic attributes were intentionally excluded:
- Age  
- Gender  
- Personal demographics  

These fields are inconsistently populated, not self-reported, and often represent grouped entrepreneurs, making them analytically unreliable.

---

### Data Quality Limitations
The source does not consistently track shark presence for each pitch.  
Because this data is incomplete, shark attendance rates are not calculated.

In a real-world scenario, this would require clarification or supplementation from business stakeholders.

---

## Orchestration & Automation

### SSIS Package
An SSIS package is used to ingest the source CSV file into the staging table (`stage.pitch_raw_data`).

The package is intentionally lightweight, handling only file ingestion, column mapping, and basic validation, while deferring all business logic and transformations to the warehouse layer.

#### Control Flow
The Control Flow manages execution order and file lifecycle:
1. Check File Exists -- Confirms the source CSV is present before processing begins.
2. Truncate Staging Table -- Clears `stage.pitch_raw_data` to ensure a clean load.  
3. Load CSV to Staging Table -- Executes the Data Flow task to ingest the file.
4. Move File to Archive -- Archives the source file after a successful load to prevent reprocessing.

This structure supports repeatable, idempotent ingestion when run on a schedule.
<p>
  <img src="Resources/Images/SSIS - Control Flow.png" alt="SSIS Control Flow" width="300"/>
</p>

#### Data Flow
The Data Flow performs the actual ingestion:
1. CSV Source reads the raw file using a predefined schema  
2. Convert Columns performs minimal type conversions required for insertion  
3. Error Output captures rows that fail conversion without stopping the load  
4. OLE DB Destination inserts valid rows into `stage.pitch_raw_data`

No business rules or derived logic are applied in SSIS.
<p>
  <img src="Resources/Images/SSIS - Data Flow.png" alt="SSIS Data Flow" width="350"/>
</p>

---

### Windows Task Scheduler
Windows Task Scheduler is used to orchestrate both SSIS execution and warehouse loading.

SQL Server Agent would be preferred in a production environment, but is not available in SQL Server Express, which is commonly used for local development.

#### Load_Shark_Tank_CSV_to_Staging Task (SSIS)

Executes the SSIS package using `dtexec.exe` to load CSV data into the staging table.

- Runs on a scheduled interval  
- Executes in the Windows user context  
- Supports repeat polling for newly dropped files  

#### Load_Shark_Tank_Data_Warehouse Task (SQL)

Executes the core warehouse load procedure using `sqlcmd.exe`.

Due to SQL Server LocalDB limitations, this task:
- Requires the user to be logged on  
- Cannot reliably run as a background service  

In production, this step would be orchestrated via SQL Server Agent on a full SQL Server instance.

---

## Azure Virtual Machine

Development and execution were performed on a dedicated Azure Virtual Machine running Windows.

The VM was used to host:
- SQL Server (LocalDB / Express-compatible runtime)
- SQL Server Integration Services (SSIS)
- Windows Task Scheduler for orchestration
- Visual Studio 2022 with SSIS project support

Using an Azure VM provided an isolated, reproducible environment that closely mirrors a production-style Windows + SQL Server setup, while avoiding local machine dependencies.

This environment allowed SSIS execution, scheduled orchestration, and warehouse processing to be developed and validated end to end.

---

## Outputs & Validation

Final outputs include:
- Fully populated warehouse dimensions and facts  
- BI-ready analytics marts  

An exported Excel workbook containing analytics view outputs has been included in the repo. These outputs serve as validation that the full pipeline executed successfully end to end.

---

## Repository Structure

SQL deployment scripts are organized by object type:
- One-off initialization scripts  
- Table creation scripts  
- View definitions  
- Stored procedures  

Non-SQL assets (SSIS packages, default file drop location, scheduled task XML, and documentation) are included directly in the repository for reference and reproducibility.

The Kaggle CSV dataset is included as of the time of project creation, both at the repository root (as a source snapshot) and in the File Drop directory to support the ingestion workflow.

---

## Running Locally (Optional)

This project is designed to be read and evaluated without full local execution.

For users who wish to run the pipeline locally:
- SQL scripts must be executed in the documented order to create schemas, tables, and procedures
- SSIS and Windows Task Scheduler paths are environment-specific and require local adjustment
- SQL Server Express / LocalDB limitations apply (no SQL Server Agent)

### SQL Deployment Order

1. `SharkTankDWH\SQL\One-Off Scripts\init database.sql`
2. `SharkTankDWH\SQL\Tables\stage.pitch_raw_data.sql`
3. `SharkTankDWH\SQL\Tables\dwh.dim_date.sql`
4. `SharkTankDWH\SQL\Tables\dwh.dim_shark.sql`
5. `SharkTankDWH\SQL\Tables\dwh.dim_business.sql`
6. `SharkTankDWH\SQL\Tables\dwh.season.sql`
7. `SharkTankDWH\SQL\Tables\dwh.episode.sql`
8. `SharkTankDWH\SQL\Tables\dwh.fact_pitch`
9. `SharkTankDWH\SQL\Tables\dwh.fact_deal_shark`
10. `SharkTankDWH\SQL\Views\analytics.vw_alltime_summary.sql`
11. `SharkTankDWH\SQL\Views\analytics.vw_season_summary.sql`
12. `SharkTankDWH\SQL\Views\analytics.vw_episode_summary.sql`
13. `SharkTankDWH\SQL\Views\analytics.vw_shark_alltime_summary.sql`
14. `SharkTankDWH\SQL\Stored Procedures\dwh.load_shark_tank_dw.sql`
15. `SharkTankDWH\SQL\Stored Procedures\dwh.populate_dim_date.sql`
16. `SharkTankDWH\SQL\One-Off Scripts\add dates to dwh.dim_date.sql`
