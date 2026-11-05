# NYC Mobility Analytics Platform 🚕📊

An end-to-end Data Engineering pipeline that ingests, cleans, and analyzes NYC High-Volume For-Hire Vehicle (HVFHV) trip data. The project transforms raw Parquet files into a reliable Star Schema Data Warehouse and provides business insights via Apache Superset.

## 🏗️ Architecture (Lakehouse Pattern)
- **Bronze (Data Lake):** Raw `.parquet` files.
- **Silver (Compute):** **DuckDB** reads Parquet directly, applies 12 Data Quality rules, and separates clean vs. quarantined data in-memory.
- **Gold (Warehouse):** **PostgreSQL** stores the final Star Schema (`fact_trips`, `dim_time`, `dim_zone`, `dim_company`).
- **Orchestration:** Custom Batch Script (`run_pipeline_v2.bat`) handling dependencies, retries, and logging.

## 🛠️ Tech Stack
- **Docker & Docker Compose** (Environment)
- **DuckDB** (High-performance OLAP transformation)
- **PostgreSQL 16** (Data Warehouse)
- **Apache Superset** (BI Dashboard)
- **Batch Scripts** (Orchestration)

## 🚀 How to Run
1. **Start the environment:**
   `docker compose up -d`
2. **Run the pipeline for a specific month:**
   `run_pipeline.bat fhvhv_tripdata_2025-01.parquet`
3. **Run the pipeline for the whole year (Loop):**
   `run_whole_2025.bat`
4. **Access Superset:**
   - URL: `http://localhost:8088`
   - User: `admin`
   - Password: `admin`

## 📈 Performance Optimizations
- **B-Tree Indexing** on `time_key` improved query time by **~83%**.
- **Pre-aggregated table** (`agg_hourly_zone`) improved dashboard query time by **~99%**.

## 📂 Repository Structure
- `/sql`: Contains all DDL, DML, and validation scripts.
- `/ingestion_duckdb`: Scripts for DuckDB processing.
- `run_pipeline_v2.bat`: The main orchestrator.
- `/logs`: Execution logs and data quality reports.

## 📑 Documentation & Presentation
- https://docs.google.com/document/d/1ppENPHSdlo7GbM3F3tfCIZrkDQPD8xyxh09gFXYjDQw/edit?tab=t.0
- https://docs.google.com/presentation/d/1AezRPa6b1fcjyhsTSiUKiz73BYnxlmM_1apgv9kCtNM/edit?slide=id.p#slide=id.p
