import sys

from PySide6.QtWidgets import QApplication

from byhunide.ui.main_window import ByHunIDE


def main() -> int:
    app = QApplication(sys.argv)
    win = ByHunIDE()
    win.show()
    return app.exec()
