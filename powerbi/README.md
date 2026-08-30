# Power BI

`WSL_Recruitment_Intelligence.pbix` contains the interactive recruitment dashboard.

The report connects to a local PostgreSQL database named:

```text
football_recruitment
```

Default development connection used during the project:

```text
Server: localhost:5432
Database: football_recruitment
```

If opening the PBIX on another machine, update the PostgreSQL data-source credentials / server settings before refreshing.

See `../docs/power_bi_model.md` for relationships and DAX measures.
