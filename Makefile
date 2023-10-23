up:
	docker compose up

wordpress:
	docker compose -f docker-compose.wordpress.yml up

homeassistant:
	docker compose -f docker-compose.homeassistant.yml up

prom:
	docker compose -f docker-compose.prometheus.yml up

grafana:
	docker compose -f docker-compose.grafana.yml up

supabase:
	docker compose -f docker-compose.supabase.yml up

all:
	docker compose \
	-f docker-compose.yml \
	-f docker-compose.wordpress.yml \
	-f docker-compose.homeassistant.yml \
	-f docker-compose.prometheus.yml \
	-f docker-compose.grafana.yml \
	-f docker-compose.supabase.yml \
	up
