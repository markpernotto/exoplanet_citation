.PHONY: help extract load diff test dbt-debug dbt-run dbt-test dbt-docs check-setup

# Load .env into the make process so subcommands inherit the vars.
ifneq (,$(wildcard .env))
    include .env
    export
endif

DBT_DIR := etl/transform

help:
	@echo "Targets:"
	@echo "  check-setup   verify Neon + R2 connectivity"
	@echo "  extract       fetch pscomppars and upload to R2"
	@echo "  load          load latest snapshot from R2 into Postgres"
	@echo "  diff          compute discovery_changes between latest two snapshots"
	@echo "  test          run pytest unit tests"
	@echo "  dbt-debug     verify dbt connects to Neon"
	@echo "  dbt-run       run all dbt models"
	@echo "  dbt-test      run all dbt tests"
	@echo "  dbt-docs      generate and serve dbt docs locally"

check-setup:
	python -m etl.check_setup

extract:
	python -m etl.extract

load:
	python -m etl.load

diff:
	python -m etl.diff

test:
	pytest -v

dbt-debug:
	cd $(DBT_DIR) && DBT_PROFILES_DIR=. dbt debug

dbt-run:
	cd $(DBT_DIR) && DBT_PROFILES_DIR=. dbt run

dbt-test:
	cd $(DBT_DIR) && DBT_PROFILES_DIR=. dbt test

dbt-docs:
	cd $(DBT_DIR) && DBT_PROFILES_DIR=. dbt docs generate && DBT_PROFILES_DIR=. dbt docs serve
