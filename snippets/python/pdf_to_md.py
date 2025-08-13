import pdfplumber
import argparse

def pdf_to_markdown(pdf_path: str, md_path: str) -> None:
    """
    Extracts text from a PDF and writes it out as a simple Markdown file,
    inserting a page header for each page.
    """
    with pdfplumber.open(pdf_path) as pdf, open(md_path, 'w', encoding='utf-8') as md_file:
        for i, page in enumerate(pdf.pages, start=1):
            md_file.write(f"# Page {i}\n\n")
            text = page.extract_text()
            if text:
                md_file.write(text + "\n\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert PDF to Markdown")
    parser.add_argument("pdf_path", help="Path to the input PDF file")
    parser.add_argument("md_path", help="Path to the output Markdown file")
    args = parser.parse_args()
    pdf_to_markdown(args.pdf_path, args.md_path)
