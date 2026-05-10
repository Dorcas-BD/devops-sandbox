.PHONY: up down create destroy logs health simulate clean

up:
	docker run -d --name sandbox-nginx --network host \
		-v $(PWD)/nginx/nginx.conf:/etc/nginx/nginx.conf \
		-v $(PWD)/nginx/conf.d:/etc/nginx/conf.d \
		nginx:alpine || true
	pip install flask -q
	nohup bash platform/cleanup_daemon.sh &
	python3 platform/api.py &
	nohup bash monitor/health_poller.sh &
	@echo "Platform is up. API on :5000, Nginx on :80"

down:
	@for f in envs/*.json; do \
		[ -f "$$f" ] && bash platform/destroy_env.sh $$(jq -r '.id' $$f) || true; \
	done
	docker stop sandbox-nginx && docker rm sandbox-nginx || true
	pkill -f cleanup_daemon.sh || true
	pkill -f health_poller.sh || true
	pkill -f "python platform/api.py" || true

create:
	@read -p "Environment name: " NAME; \
	read -p "TTL in seconds [1800]: " TTL; \
	TTL=$${TTL:-1800}; \
	bash platform/create_env.sh "$$NAME" "$$TTL"

destroy:
	bash platform/destroy_env.sh $(ENV)

logs:
	tail -f logs/$(ENV)/app.log

health:
	@for f in envs/*.json; do \
		[ -f "$$f" ] && jq -r '"\(.id) | status: \(.status) | port: \(.port)"' $$f; \
	done

simulate:
	bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	rm -rf logs/* envs/* nginx/conf.d/*.conf
	mkdir -p logs envs
