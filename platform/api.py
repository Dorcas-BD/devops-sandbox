from flask import Flask, jsonify, request
import subprocess, json, os, glob

app = Flask(__name__)

def load_env(env_id):
    path = f"envs/{env_id}.json"
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)

@app.route("/envs", methods=["POST"])
def create_env():
    data = request.json or {}
    name = data.get("name", "env")
    ttl = data.get("ttl", 1800)
    result = subprocess.run(
        ["bash", "platform/create_env.sh", name, str(ttl)],
        capture_output=True, text=True
    )
    return jsonify({"output": result.stdout, "error": result.stderr}), 201

@app.route("/envs", methods=["GET"])
def list_envs():
    import time
    envs = []
    for f in glob.glob("envs/*.json"):
        with open(f) as fh:
            env = json.load(fh)
        ttl_remaining = (env["created_at"] + env["ttl"]) - int(time.time())
        env["ttl_remaining"] = max(0, ttl_remaining)
        envs.append(env)
    return jsonify(envs)

@app.route("/envs/<env_id>", methods=["DELETE"])
def destroy_env(env_id):
    result = subprocess.run(
        ["bash", "platform/destroy_env.sh", env_id],
        capture_output=True, text=True
    )
    return jsonify({"output": result.stdout})

@app.route("/envs/<env_id>/logs", methods=["GET"])
def get_logs(env_id):
    log_file = f"logs/{env_id}/app.log"
    if not os.path.exists(log_file):
        # Check archived
        log_file = f"logs/archived/{env_id}/app.log"
    if not os.path.exists(log_file):
        return jsonify({"error": "log not found"}), 404
    with open(log_file) as f:
        lines = f.readlines()[-100:]
    return jsonify({"logs": lines})

@app.route("/envs/<env_id>/health", methods=["GET"])
def get_health(env_id):
    log_file = f"logs/{env_id}/health.log"
    if not os.path.exists(log_file):
        return jsonify({"error": "health log not found"}), 404
    with open(log_file) as f:
        lines = f.readlines()[-10:]
    return jsonify({"health": lines})

@app.route("/envs/<env_id>/outage", methods=["POST"])
def trigger_outage(env_id):
    data = request.json or {}
    mode = data.get("mode", "crash")
    result = subprocess.run(
        ["bash", "platform/simulate_outage.sh", "--env", env_id, "--mode", mode],
        capture_output=True, text=True
    )
    return jsonify({"output": result.stdout, "error": result.stderr})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
