.PHONY: help extract load diff publish pipeline test api web dev web-install web-build dbt-debug dbt-run dbt-test dbt-docs check-setup smoke-gaia

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
	@echo "  publish       generate public/{rss.xml,discoveries.json,health.json}"
	@echo "  pipeline      run extract → load → dbt → diff → publish"
	@echo "  api           run FastAPI locally on :8000 with auto-reload"
	@echo "  web           run Vite dev server on :5550 (proxies /api → :8000)"
	@echo "  dev           run api + web together (you'll need two terminals)"
	@echo "  web-install   install npm deps under web/"
	@echo "  web-build     production build of the React app"
	@echo "  smoke-gaia    one-shot test of Gaia DR3 client against a host"
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

publish:
	python -m etl.publish

pipeline: extract load dbt-run diff publish

api:
	uvicorn api.index:app --reload --port 8000

web-install:
	cd web && npm install

web:
	cd web && npm run dev

web-build:
	cd web && npm run build

dev:
	@echo "Run 'make api' in one terminal and 'make web' in another."

smoke-gaia:
	python -m etl.smoke_gaia

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
