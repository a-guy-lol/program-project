from flask import Flask, request
app = Flask(__name__)
@app.route('/receive-data', methods=['POST'])
def receive_data():
    data = request.get_json()
    if not data or "position" not in data:
        return "Invalid data", 400
    position = data["position"]
    x = position.get("x", 0)
    y = position.get("y", 0)
    z = position.get("z", 0)
    print(f"Received position: X={x}, Y={y}, Z={z}")
    return "Position received", 200

latest_position = "hi world"
@app.route('/')
def home():
    return latest_position

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
