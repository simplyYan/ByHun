import sys


def main() -> int:
    try:
        from byhunide.app import main as run
    except ModuleNotFoundError as e:
        if e.name != "PySide6":
            raise
        sys.stderr.write(
            "PySide6 is not installed.\n"
            "Install dependencies and try again:\n\n"
            "  python -m pip install -r requirements.txt\n\n"
            "If you use a virtual environment, activate it before installing.\n"
        )
        raise SystemExit(1)
    return run()


if __name__ == "__main__":
    raise SystemExit(main())

