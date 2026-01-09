import base64
import os
import tempfile
import zipfile
from typing import Set


def obfuscate_js(js_text: str) -> str:
    payload = base64.b64encode(js_text.encode("utf-8")).decode("ascii")
    return "(function(){const s=atob('" + payload + "');(0,eval)(s);})();"


def obfuscate_html(html_text: str) -> str:
    payload = base64.b64encode(html_text.encode("utf-8")).decode("ascii")
    return (
        "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>"
        "<script>(function(){const h=atob('"
        + payload
        + "');document.open();document.write(h);document.close();})();</script>"
        "</body></html>"
    )


def compile_project(project_root: str, out_path: str) -> None:
    excluded_dirs: Set[str] = {".git", "__pycache__"}
    excluded_files = {os.path.abspath(out_path)}

    with tempfile.TemporaryDirectory(prefix="byhunide_build_") as tmp:
        tmp_root = os.path.join(tmp, "project")
        os.makedirs(tmp_root, exist_ok=True)

        for root, dirs, files in os.walk(project_root):
            dirs[:] = [d for d in dirs if d not in excluded_dirs]
            for fn in files:
                src = os.path.join(root, fn)
                if os.path.abspath(src) in excluded_files:
                    continue

                rel = os.path.relpath(src, project_root)
                dst = os.path.join(tmp_root, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)

                _, ext = os.path.splitext(src)
                ext = ext.lower()

                if ext in {".html", ".js", ".css"}:
                    with open(src, "r", encoding="utf-8", errors="replace") as f:
                        text = f.read()
                    if ext == ".js":
                        out_text = obfuscate_js(text)
                    elif ext == ".html":
                        out_text = obfuscate_html(text)
                    else:
                        out_text = text
                    with open(dst, "w", encoding="utf-8") as f:
                        f.write(out_text)
                else:
                    with open(src, "rb") as fsrc:
                        data = fsrc.read()
                    with open(dst, "wb") as fdst:
                        fdst.write(data)

        if not out_path.lower().endswith(".zip"):
            out_path += ".zip"

        with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(tmp_root):
                for fn in files:
                    full = os.path.join(root, fn)
                    rel = os.path.relpath(full, tmp_root)
                    zf.write(full, rel)
