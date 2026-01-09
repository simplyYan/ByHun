from typing import List, Tuple

from PySide6.QtCore import QRegularExpression
from PySide6.QtGui import QColor, QFont, QTextCharFormat, QSyntaxHighlighter


class BaseHighlighter(QSyntaxHighlighter):
    def __init__(self, document):
        super().__init__(document)
        self._rules: List[Tuple[QRegularExpression, QTextCharFormat]] = []

    def add_rule(self, pattern: str, fmt: QTextCharFormat) -> None:
        self._rules.append((QRegularExpression(pattern), fmt))

    def highlightBlock(self, text: str) -> None:
        for regex, fmt in self._rules:
            it = regex.globalMatch(text)
            while it.hasNext():
                m = it.next()
                self.setFormat(m.capturedStart(), m.capturedLength(), fmt)


class HtmlHighlighter(BaseHighlighter):
    def __init__(self, document):
        super().__init__(document)

        tag_fmt = QTextCharFormat()
        tag_fmt.setForeground(QColor("#7dcfff"))
        tag_fmt.setFontWeight(QFont.Weight.Bold)

        attr_fmt = QTextCharFormat()
        attr_fmt.setForeground(QColor("#bb9af7"))

        str_fmt = QTextCharFormat()
        str_fmt.setForeground(QColor("#9ece6a"))

        cmt_fmt = QTextCharFormat()
        cmt_fmt.setForeground(QColor("#565f89"))

        self.add_rule(r"</?\s*[A-Za-z][A-Za-z0-9:-]*", tag_fmt)
        self.add_rule(r"\b[A-Za-z_:][A-Za-z0-9_:\-\.]*\b(?=\=)", attr_fmt)
        self.add_rule(r"\"[^\"]*\"", str_fmt)
        self.add_rule(r"\'[^\']*\'", str_fmt)
        self.add_rule(r"<!--[^>]*?-->", cmt_fmt)


class CssHighlighter(BaseHighlighter):
    def __init__(self, document):
        super().__init__(document)

        selector_fmt = QTextCharFormat()
        selector_fmt.setForeground(QColor("#7dcfff"))
        selector_fmt.setFontWeight(QFont.Weight.Bold)

        prop_fmt = QTextCharFormat()
        prop_fmt.setForeground(QColor("#bb9af7"))

        value_fmt = QTextCharFormat()
        value_fmt.setForeground(QColor("#9ece6a"))

        cmt_fmt = QTextCharFormat()
        cmt_fmt.setForeground(QColor("#565f89"))

        self.add_rule(r"^[^\{]+(?=\{)", selector_fmt)
        self.add_rule(r"\b[a-zA-Z\-]+(?=\s*:)", prop_fmt)
        self.add_rule(r":\s*[^;]+(?=;)", value_fmt)
        self.add_rule(r"/\*.*?\*/", cmt_fmt)


class JsHighlighter(BaseHighlighter):
    def __init__(self, document):
        super().__init__(document)

        kw_fmt = QTextCharFormat()
        kw_fmt.setForeground(QColor("#7dcfff"))
        kw_fmt.setFontWeight(QFont.Weight.Bold)

        str_fmt = QTextCharFormat()
        str_fmt.setForeground(QColor("#9ece6a"))

        num_fmt = QTextCharFormat()
        num_fmt.setForeground(QColor("#ff9e64"))

        cmt_fmt = QTextCharFormat()
        cmt_fmt.setForeground(QColor("#565f89"))

        keywords = [
            "break",
            "case",
            "catch",
            "class",
            "const",
            "continue",
            "debugger",
            "default",
            "delete",
            "do",
            "else",
            "export",
            "extends",
            "finally",
            "for",
            "function",
            "if",
            "import",
            "in",
            "instanceof",
            "let",
            "new",
            "return",
            "super",
            "switch",
            "this",
            "throw",
            "try",
            "typeof",
            "var",
            "void",
            "while",
            "with",
            "yield",
            "await",
            "async",
            "true",
            "false",
            "null",
            "undefined",
        ]

        self.add_rule(r"\\b(" + "|".join(keywords) + r")\\b", kw_fmt)
        self.add_rule(r"\"[^\"]*\"", str_fmt)
        self.add_rule(r"\'[^\']*\'", str_fmt)
        self.add_rule(r"`[^`]*`", str_fmt)
        self.add_rule(r"\\b[0-9]+(\\.[0-9]+)?\\b", num_fmt)
        self.add_rule(r"//.*$", cmt_fmt)
        self.add_rule(r"/\*.*?\*/", cmt_fmt)
