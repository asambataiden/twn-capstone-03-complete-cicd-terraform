import os

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def home():
    return jsonify(
        application="twn-capstone-03",
        status="running",
        version=os.getenv("APP_VERSION", "local"),
    )


@app.get("/health")
def health():
    return jsonify(status="healthy"), 200


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
