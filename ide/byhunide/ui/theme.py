def apply_dark_theme(window) -> None:
    window.setStyleSheet(
        "QMainWindow{background:#0b1020;color:#c0caf5;}"
        "QToolBar{background:#0f1730;border:0px;spacing:8px;padding:6px;}"
        "QMenuBar{background:#0f1730;color:#c0caf5;}"
        "QMenuBar::item:selected{background:#1f2a4a;}"
        "QMenu{background:#0f1730;color:#c0caf5;border:1px solid #1f2a4a;}"
        "QMenu::item:selected{background:#1f2a4a;}"
        "QStatusBar{background:#0f1730;color:#c0caf5;}"
        "QTreeView{background:#0b1020;color:#c0caf5;border:0px;}"
        "QTreeView::item:selected{background:#1f2a4a;}"
        "QTabWidget::pane{border:0px;background:#0b1020;}"
        "QTabBar::tab{background:#0f1730;color:#c0caf5;padding:8px 10px;border-top-left-radius:6px;border-top-right-radius:6px;margin-right:4px;}"
        "QTabBar::tab:selected{background:#1f2a4a;}"
        "QPlainTextEdit{background:#0b1020;color:#c0caf5;border:0px;padding:10px;selection-background-color:#1f2a4a;}"
    )
