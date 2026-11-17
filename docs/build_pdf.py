#!/usr/bin/env python3
"""Genera Reporte_Tecnico_Huellas.pdf a partir de reporte_tecnico.html.

Pasos:
  1. Chrome (sin interfaz) carga el HTML y Mermaid dibuja los diagramas.
  2. Se guarda el DOM ya renderizado (diagramas como SVG estático) y se
     verifica que todos los diagramas se hayan dibujado sin errores.
  3. Chrome imprime esa versión estática a PDF.

Uso:  python3 docs/build_pdf.py      (requiere Google Chrome e internet
                                       la primera vez, para descargar Mermaid)
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

DOCS = Path(__file__).resolve().parent
SOURCE = DOCS / "reporte_tecnico.html"
RENDERED = DOCS / ".reporte_renderizado.html"  # mismo directorio: img/ resuelve igual
OUTPUT = DOCS / "Reporte_Tecnico_Huellas.pdf"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def chrome(*args: str) -> str:
    with tempfile.TemporaryDirectory() as profile:
        result = subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", *args],
            capture_output=True,
            text=True,
            timeout=180,
        )
    return result.stdout


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    expected = source.count('<pre class="mermaid">')

    dom = chrome("--dump-dom", "--virtual-time-budget=30000", SOURCE.as_uri())
    blocks = re.findall(r'<pre class="mermaid"[^>]*>(.*?)</pre>', dom, re.S)
    drawn = [b for b in blocks if "<svg" in b and "Syntax error" not in b]
    if 'data-rendered="true"' not in dom or len(drawn) != expected:
        print(f"Error: se dibujaron {len(drawn)} de {expected} diagramas.", file=sys.stderr)
        return 1

    # Quita el script de Mermaid: la versión impresa es 100 % estática.
    static = re.sub(r'<script type="module">.*?</script>', "", dom, flags=re.S)
    RENDERED.write_text(static, encoding="utf-8")

    chrome(
        "--no-pdf-header-footer",
        "--virtual-time-budget=5000",
        f"--print-to-pdf={OUTPUT}",
        RENDERED.as_uri(),
    )
    RENDERED.unlink(missing_ok=True)
    print(f"PDF generado: {OUTPUT} ({expected} diagramas)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
