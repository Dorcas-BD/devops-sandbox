from flask import Flask, jsonify #jsonify conver python dict to JSON response
import os #let us read environment variables


app = Flask(__name__)
ENV_ID = os.environ.get("ENV_ID", "unknown")

@app.route("/")
def home():
    return jsonify({"message": f"Hello from env {ENV_ID}", "env_id": ENV_ID})

@app.route("/health")
def health():
    return jsonify({"status": "ok", "env_id": ENV_ID}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
