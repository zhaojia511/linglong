@echo off
REM Windows batch script to automate Python venv setup and package installation for EMG device extraction

REM Create virtual environment
python -m venv venv

REM Activate virtual environment
call .\venv\Scripts\activate

REM Install required packages
pip install --upgrade pip
pip install langchain pypdf openai

echo.
echo Environment setup complete. Activate with:
echo   .\venv\Scripts\activate
echo Place your PDF in this folder and proceed with extraction scripts.
