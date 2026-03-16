#!/usr/bin/env python3
"""
PDF to Text Converter
Extracts text content from PDF files for analysis
"""

import sys
import os

def extract_with_pypdf2(pdf_path, output_path):
    """Extract text using PyPDF2 (lightweight)"""
    try:
        import PyPDF2
    except ImportError:
        print("Installing PyPDF2...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "PyPDF2"])
        import PyPDF2
    
    print(f"Extracting text from: {pdf_path}")
    with open(pdf_path, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        total_pages = len(reader.pages)
        print(f"Found {total_pages} pages")
        
        text = ""
        for i, page in enumerate(reader.pages, 1):
            print(f"Processing page {i}/{total_pages}...", end='\r')
            text += f"\n\n--- Page {i} ---\n\n"
            text += page.extract_text()
    
    with open(output_path, 'w', encoding='utf-8') as output:
        output.write(text)
    
    print(f"\n✓ Extracted {total_pages} pages to: {output_path}")
    return output_path

def extract_with_pdfplumber(pdf_path, output_path):
    """Extract text using pdfplumber (better table support)"""
    try:
        import pdfplumber
    except ImportError:
        print("Installing pdfplumber...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pdfplumber"])
        import pdfplumber
    
    print(f"Extracting text from: {pdf_path}")
    with pdfplumber.open(pdf_path) as pdf:
        total_pages = len(pdf.pages)
        print(f"Found {total_pages} pages")
        
        text = ""
        for i, page in enumerate(pdf.pages, 1):
            print(f"Processing page {i}/{total_pages}...", end='\r')
            text += f"\n\n--- Page {i} ---\n\n"
            page_text = page.extract_text()
            if page_text:
                text += page_text
            
            # Try to extract tables
            tables = page.extract_tables()
            if tables:
                text += "\n[Tables found on this page]\n"
                for table in tables:
                    for row in table:
                        text += " | ".join(str(cell) if cell else "" for cell in row) + "\n"
    
    with open(output_path, 'w', encoding='utf-8') as output:
        output.write(text)
    
    print(f"\n✓ Extracted {total_pages} pages to: {output_path}")
    return output_path

def main():
    if len(sys.argv) < 2:
        print("Usage: python pdf_to_text.py <pdf_file> [output_file] [--method=pypdf2|pdfplumber]")
        print("\nExample:")
        print("  python pdf_to_text.py document.pdf")
        print("  python pdf_to_text.py document.pdf output.txt --method=pdfplumber")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    
    if not os.path.exists(pdf_path):
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)
    
    # Determine output path
    if len(sys.argv) > 2 and not sys.argv[2].startswith('--'):
        output_path = sys.argv[2]
    else:
        output_path = os.path.splitext(pdf_path)[0] + '.txt'
    
    # Determine extraction method
    method = 'pypdf2'  # default
    for arg in sys.argv:
        if arg.startswith('--method='):
            method = arg.split('=')[1]
    
    # Extract text
    if method == 'pdfplumber':
        extract_with_pdfplumber(pdf_path, output_path)
    else:
        extract_with_pypdf2(pdf_path, output_path)

if __name__ == "__main__":
    main()
