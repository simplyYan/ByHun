from typing import List

from PySide6.QtCore import Qt, QStringListModel
from PySide6.QtGui import QFont, QKeySequence, QTextCursor
from PySide6.QtWidgets import QCompleter, QPlainTextEdit, QSizePolicy


class ByHunCodeEditor(QPlainTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._language = ""
        self._completer = QCompleter(self)
        self._completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        self._completer.setFilterMode(Qt.MatchFlag.MatchContains)
        self._completer.setWidget(self)
        self._completer.activated.connect(self._insert_completion)
        self._completer.setModel(QStringListModel([]))

        font = QFont("Consolas")
        font.setStyleHint(QFont.StyleHint.Monospace)
        font.setPointSize(11)
        self.setFont(font)
        self.setTabStopDistance(self.fontMetrics().horizontalAdvance(" ") * 4)

        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

    def set_language(self, ext: str) -> None:
        ext = ext.lower().strip()
        self._language = ext
        words: List[str]

        if ext == ".html":
            words = [
                "div",
                "span",
                "a",
                "img",
                "script",
                "link",
                "meta",
                "head",
                "body",
                "html",
                "input",
                "button",
                "form",
                "label",
                "section",
                "header",
                "footer",
                "main",
                "nav",
                "ul",
                "ol",
                "li",
                "p",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
                "class",
                "id",
                "src",
                "href",
                "style",
                "type",
                "rel",
                "charset",
                "content",
                "name",
                "value",
                "placeholder",
                "onclick",
                "onload",
            ]
        elif ext == ".css":
            words = [
                "display",
                "flex",
                "grid",
                "position",
                "absolute",
                "relative",
                "fixed",
                "sticky",
                "margin",
                "padding",
                "width",
                "height",
                "min-width",
                "min-height",
                "max-width",
                "max-height",
                "color",
                "background",
                "background-color",
                "border",
                "border-radius",
                "font-size",
                "font-family",
                "font-weight",
                "line-height",
                "text-align",
                "justify-content",
                "align-items",
                "gap",
                "top",
                "left",
                "right",
                "bottom",
                "z-index",
                "overflow",
                "cursor",
                "transition",
                "transform",
            ]
        else:
            words = [
                "console",
                "log",
                "warn",
                "error",
                "document",
                "window",
                "querySelector",
                "querySelectorAll",
                "getElementById",
                "addEventListener",
                "removeEventListener",
                "setTimeout",
                "setInterval",
                "fetch",
                "then",
                "catch",
                "async",
                "await",
                "function",
                "return",
                "const",
                "let",
                "var",
                "if",
                "else",
                "for",
                "while",
                "class",
                "new",
                "this",
            ]

        self._completer.setModel(QStringListModel(words))

    def _insert_completion(self, completion: str) -> None:
        tc = self.textCursor()
        tc.select(QTextCursor.SelectionType.WordUnderCursor)
        tc.removeSelectedText()
        tc.insertText(completion)
        self.setTextCursor(tc)

    def _current_word_prefix(self) -> str:
        tc = self.textCursor()
        tc.select(QTextCursor.SelectionType.WordUnderCursor)
        return tc.selectedText()

    def keyPressEvent(self, event):
        if event.matches(QKeySequence.StandardKey.InsertParagraphSeparator):
            super().keyPressEvent(event)
            return

        if event.modifiers() == Qt.KeyboardModifier.ControlModifier and event.key() == Qt.Key.Key_Space:
            self._show_completer(force=True)
            return

        super().keyPressEvent(event)
        if event.text().isalnum() or event.text() in {"-", "_"}:
            self._show_completer(force=False)

    def _show_completer(self, force: bool) -> None:
        prefix = self._current_word_prefix()
        if not force and len(prefix) < 2:
            self._completer.popup().hide()
            return

        model = self._completer.model()
        if isinstance(model, QStringListModel):
            self._completer.setCompletionPrefix(prefix)
            rect = self.cursorRect()
            rect.setWidth(self._completer.popup().sizeHintForColumn(0) + 24)
            self._completer.complete(rect)
