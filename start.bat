@echo off
title Genomic Pipeline GUI
echo ====================================================
echo Starting Genomic Pipeline GUI
echo ====================================================

REM Check if virtual environment exists and activate it
if exist "venv\Scripts\activate.bat" (
    echo [INFO] Activating virtual environment...
    call "venv\Scripts\activate.bat"
) else (
    echo [WARNING] Virtual environment not found at venv\Scripts\activate.bat. Using system Python.
)

REM Start the FastAPI server in a new minimized command window
echo [INFO] Starting FastAPI Web Server on http://127.0.0.1:8000 ...
start "FastAPI Server" cmd /k "python -m uvicorn api.main:app --host 0.0.0.0 --port 8000"

REM Wait 3 seconds to allow the server to boot up
timeout /t 3 /nobreak > nul

REM Open the web interface in the default browser
echo [INFO] Opening Web GUI...
start http://127.0.0.1:8000

REM Start the background worker in the current window
echo [INFO] Starting Background Job Worker...
python -m api.worker

echo.
echo [INFO] If you close this window, the background worker will stop.
pause
