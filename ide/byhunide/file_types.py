import os


ALLOWED_EXTENSIONS = {".html", ".css", ".js"}


def is_allowed_file(path: str) -> bool:
    _, ext = os.path.splitext(path)
    return ext.lower() in ALLOWED_EXTENSIONS
