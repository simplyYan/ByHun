import os
from typing import Optional

from PySide6.QtWidgets import QHBoxLayout, QWidget

from byhunide.editor.code_editor import ByHunCodeEditor
from byhunide.editor.highlighters import CssHighlighter, HtmlHighlighter, JsHighlighter


class EditorTab(QWidget):
    def __init__(self, file_path: Optional[str], parent=None):
        super().__init__(parent)
        self.file_path = file_path
        self.editor = ByHunCodeEditor(self)
        self._highlighter = None

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.editor)

        self.setLayout(layout)
        self.set_file_path(file_path)

    def set_file_path(self, file_path: Optional[str]) -> None:
        self.file_path = file_path
        ext = ""
        if file_path:
            _, ext = os.path.splitext(file_path)

        self.editor.set_language(ext or ".js")

        if self._highlighter is not None:
            self._highlighter.setDocument(None)

        if ext.lower() == ".html":
            self._highlighter = HtmlHighlighter(self.editor.document())
        elif ext.lower() == ".css":
            self._highlighter = CssHighlighter(self.editor.document())
        else:
            self._highlighter = JsHighlighter(self.editor.document())

    def is_modified(self) -> bool:
        return self.editor.document().isModified()

    def set_modified(self, modified: bool) -> None:
        self.editor.document().setModified(modified)

    def load_from_disk(self) -> None:
        if not self.file_path:
            return
        with open(self.file_path, "r", encoding="utf-8", errors="replace") as f:
            self.editor.setPlainText(f.read())
        self.set_modified(False)

    def save_to_disk(self) -> None:
        if not self.file_path:
            return
        with open(self.file_path, "w", encoding="utf-8") as f:
            f.write(self.editor.toPlainText())
        self.set_modified(False)
