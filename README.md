# 🚗 Cruze

The AI-driven fleet safety application.

## 🛠️ Prerequisites
1.  **Flutter SDK** (Installed and in PATH).
2.  **Python 3.9+** (For the backend demo).
3.  **Git**.

---

## 🚀 Setup Instructions (Step-by-Step)

### 1. Clone the Repository
```bash
git clone https://github.com/cruzemaps/cruze.git
cd cruze
```

### 2. Configure Secrets (Critical!)
The project uses environment variables for API keys. These are **not** committed to GitHub.
You must create them manually.

1.  Create a folder named `env` in the root directory.
2.  Create a file named `.env` inside `env/` (Path: `cruze/env/.env`).


### 3. Setup Backend (The Brain)
We use a Python backend for Authentication and Crash Telemetry.

1.  Open a terminal in the project root.
2.  Install dependencies:
    ```bash
    python3 -m pip install flask flask-cors requests azure-functions azure-cosmos
    ```
3.  Start the Local Server:
    ```bash
    python3 backend/flask_server.py
    ```
    *You should see: "Starting Cruze Backend... on port 7071"*
    *Keep this terminal running!*

### 4. Run the App (Frontend)
1.  Open a **new** terminal.
2.  Install Flutter packages:
    ```bash
    flutter pub get
    ```
3.  Run the App:
    - **For Web (Recommended for Demo)**:
      ```bash
      flutter run -d chrome
      ```
    - **For Mobile**:
      ```bash
      flutter run
      ```

---

## 🎮 How to Demo
1.  **Sign Up**: On the login screen, toggle to "Sign Up". Enter any name/email/password.
2.  **Log In**: Use the credentials you just created.
3.  **Navigate**: In the Map, search for "**The Alamo**". Tap the result to start navigation.
    - *Observe: Turn-by-Turn instructions and Speedometer appear.*
4.  **Crash Test**: Shake the device (or observe logs if on simulator).
    - *Observe: Backend terminal will print `CRASH DETECTED`.*

## 📁 Project Structure
- `lib/`: Flutter App Source Code
  - `screens/`: Map, Login, Profile UI
- `backend/`: Python Azure Functions & Local Demo Server
- `env/`: Secrets (Ignored by Git)
