SHELL := /bin/bash

MODE ?= registry
COLOR ?= green
TARGET ?= active
ENV_FILE ?= .env
SERVICE ?= api-sandbox

COMPOSE = docker compose --env-file $(ENV_FILE) -f docker-compose.yml -f compose.$(MODE).yml

ifneq ($(strip $(VERSION)),)
export SERVICE_WEBHOOK_VERSION := $(VERSION)
endif

ifneq ($(strip $(IMAGE)),)
export SERVICE_WEBHOOK_IMAGE := $(IMAGE)
endif

export COMPOSE_MODE := $(MODE)

.PHONY: help config deploy deploy-service switch switch-service rollback verify readyz readyz-service healthcheck status status-service stop stop-service

help:
	@printf '%s\n' 'compose-manager targets:'
	@printf '%s\n' '  make config MODE=registry|build [ENV_FILE=.env] [VERSION=v1.2.3] [IMAGE=repo/image]'
	@printf '%s\n' '  make deploy COLOR=blue|green MODE=registry|build [VERSION=v1.2.3] [IMAGE=repo/image]'
	@printf '%s\n' '  make deploy-service SERVICE=api-sandbox|api-verixa|api-lgpay COLOR=blue|green MODE=registry|build [VERSION=v1.2.3]'
	@printf '%s\n' '  make switch COLOR=blue|green'
	@printf '%s\n' '  make switch-service SERVICE=api-sandbox|api-verixa|api-lgpay COLOR=blue|green [VERSION=v1.2.3]'
	@printf '%s\n' '  make rollback COLOR=blue|green'
	@printf '%s\n' '  make verify'
	@printf '%s\n' '  make readyz COLOR=blue|green'
	@printf '%s\n' '  make readyz-service SERVICE=api-sandbox|api-verixa|api-lgpay COLOR=blue|green'
	@printf '%s\n' '  make healthcheck TARGET=active|blue|green'
	@printf '%s\n' '  make status'
	@printf '%s\n' '  make status-service SERVICE=api-sandbox|api-verixa|api-lgpay COLOR=blue|green'
	@printf '%s\n' '  make stop COLOR=blue|green'
	@printf '%s\n' '  make stop-service SERVICE=api-sandbox|api-verixa|api-lgpay COLOR=blue|green'

config:
	$(COMPOSE) config

deploy:
	./scripts/deploy-color.sh $(COLOR)

deploy-service:
	@case "$(SERVICE)" in api-verixa|api-lgpay|api-sandbox) ;; *) echo "Unsupported SERVICE=$(SERVICE) (use api-verixa, api-lgpay, or api-sandbox)" >&2; exit 2 ;; esac
	@case "$(COLOR)" in blue|green) ;; *) echo "Unsupported COLOR=$(COLOR) (use blue or green)" >&2; exit 2 ;; esac
	@case "$(MODE)" in \
		build) $(COMPOSE) build "$(SERVICE)-$(COLOR)" ;; \
		registry) $(COMPOSE) pull "$(SERVICE)-$(COLOR)" ;; \
		*) echo "Unsupported MODE=$(MODE) (use build or registry)" >&2; exit 2 ;; \
	esac
	$(COMPOSE) up -d --no-deps --force-recreate "$(SERVICE)-$(COLOR)"

switch:
	./scripts/switch-active.sh $(COLOR)

switch-service:
	./scripts/switch-service.sh $(SERVICE) $(COLOR)

rollback:
	./scripts/rollback.sh $(COLOR)

verify:
	./scripts/verify-active.sh

readyz:
	./scripts/readyz.sh $(COLOR)

readyz-service:
	@case "$(SERVICE)" in api-verixa) port=8900 ;; api-lgpay) port=8902 ;; api-sandbox) port=8904 ;; *) echo "Unsupported SERVICE=$(SERVICE) (use api-verixa, api-lgpay, or api-sandbox)" >&2; exit 2 ;; esac; \
	case "$(COLOR)" in blue|green) ;; *) echo "Unsupported COLOR=$(COLOR) (use blue or green)" >&2; exit 2 ;; esac; \
	$(COMPOSE) exec -T "$(SERVICE)-$(COLOR)" wget -qO- "http://127.0.0.1:$$port/readyz" >/dev/null; \
	echo "$(SERVICE)-$(COLOR) ready"

healthcheck:
	./scripts/healthcheck.sh $(TARGET)

status:
	./scripts/status.sh

status-service:
	@case "$(SERVICE)" in api-verixa|api-lgpay|api-sandbox) ;; *) echo "Unsupported SERVICE=$(SERVICE) (use api-verixa, api-lgpay, or api-sandbox)" >&2; exit 2 ;; esac
	@case "$(COLOR)" in blue|green) ;; *) echo "Unsupported COLOR=$(COLOR) (use blue or green)" >&2; exit 2 ;; esac
	$(COMPOSE) ps "$(SERVICE)-$(COLOR)"

stop:
	./scripts/stop-color.sh $(COLOR)

stop-service:
	@case "$(SERVICE)" in api-verixa|api-lgpay|api-sandbox) ;; *) echo "Unsupported SERVICE=$(SERVICE) (use api-verixa, api-lgpay, or api-sandbox)" >&2; exit 2 ;; esac
	@case "$(COLOR)" in blue|green) ;; *) echo "Unsupported COLOR=$(COLOR) (use blue or green)" >&2; exit 2 ;; esac
	$(COMPOSE) stop "$(SERVICE)-$(COLOR)"
