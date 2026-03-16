# EMG Device Extraction Environment Setup

This guide helps you set up a Python environment for using LangChain’s agentic document extraction on EMG device PDF files.

## 1. Create a Virtual Environment

Open a terminal in the emg_device folder and run:

```
python -m venv venv
```

Activate it:
- On Windows:
  ```
  .\venv\Scripts\activate
  ```
- On macOS/Linux:
  ```
  source venv/bin/activate
  ```

## 2. Install Required Packages

Run:
```
pip install langchain pypdf openai
```

- `langchain`: For agentic document extraction
- `pypdf`: For PDF loading
- `openai`: For LLM backend (or use another supported LLM)

## 3. Add Your PDF

Place your EMG device PDF (e.g., `emg_protocol.pdf`) in this folder.

## 4. Next Steps

- Create a Python script (e.g., `extract_emg_pdf.py`) to load and extract data from the PDF.
- Configure your OpenAI API key or other LLM credentials as needed.

---
For a sample extraction script or further help, just ask!
