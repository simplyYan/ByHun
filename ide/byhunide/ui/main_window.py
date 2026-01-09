import os
from typing import Optional

from PySide6.QtCore import QDir, QModelIndex, Qt
from PySide6.QtGui import QAction, QKeySequence
from PySide6.QtWidgets import (
    QAbstractItemView,
    QFileDialog,
    QFileSystemModel,
    QHBoxLayout,
    QInputDialog,
    QMainWindow,
    QMessageBox,
    QSplitter,
    QStatusBar,
    QTabWidget,
    QToolBar,
    QTreeView,
    QWidget,
)

from byhunide.build.compiler import compile_project
from byhunide.editor.editor_tab import EditorTab
from byhunide.file_types import ALLOWED_EXTENSIONS, is_allowed_file
from byhunide.ui.theme import apply_dark_theme


class ByHunIDE(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ByHunIDE")
        self.setMinimumSize(1000, 650)

        self.project_root: Optional[str] = None

        self._setup_ui()
        self._setup_actions()
        apply_dark_theme(self)

    def _setup_ui(self) -> None:
        self.status = QStatusBar(self)
        self.setStatusBar(self.status)

        splitter = QSplitter(Qt.Orientation.Horizontal, self)

        self.fs_model = QFileSystemModel(self)
        self.fs_model.setFilter(QDir.Filter.AllDirs | QDir.Filter.NoDotAndDotDot | QDir.Filter.Files)
        self.fs_model.setNameFilters(["*.html", "*.css", "*.js"])
        self.fs_model.setNameFilterDisables(False)

        self.tree = QTreeView(self)
        self.tree.setModel(self.fs_model)
        self.tree.setHeaderHidden(True)
        self.tree.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.tree.doubleClicked.connect(self._on_tree_double_clicked)

        self.tabs = QTabWidget(self)
        self.tabs.setDocumentMode(True)
        self.tabs.setTabsClosable(True)
        self.tabs.tabCloseRequested.connect(self._close_tab)

        splitter.addWidget(self.tree)
        splitter.addWidget(self.tabs)
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([260, 740])

        central = QWidget(self)
        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(splitter)
        central.setLayout(layout)
        self.setCentralWidget(central)

        self.toolbar = QToolBar("Main", self)
        self.toolbar.setMovable(False)
        self.addToolBar(Qt.ToolBarArea.TopToolBarArea, self.toolbar)

    def _setup_actions(self) -> None:
        self.action_open_folder = QAction("Open Folder", self)
        self.action_open_folder.triggered.connect(self.open_folder)

        self.action_open_file = QAction("Open File", self)
        self.action_open_file.setShortcut(QKeySequence.StandardKey.Open)
        self.action_open_file.triggered.connect(self.open_file_dialog)

        self.action_new_file = QAction("New File", self)
        self.action_new_file.setShortcut(QKeySequence.StandardKey.New)
        self.action_new_file.triggered.connect(self.new_file)

        self.action_save = QAction("Save", self)
        self.action_save.setShortcut(QKeySequence.StandardKey.Save)
        self.action_save.triggered.connect(self.save_current)

        self.action_save_as = QAction("Save As", self)
        self.action_save_as.setShortcut(QKeySequence.StandardKey.SaveAs)
        self.action_save_as.triggered.connect(self.save_current_as)

        self.action_compile = QAction("Build", self)
        self.action_compile.setShortcut(QKeySequence(Qt.Key.Key_F5))
        self.action_compile.triggered.connect(self.build_project)

        self.toolbar.addAction(self.action_open_folder)
        self.toolbar.addAction(self.action_open_file)
        self.toolbar.addAction(self.action_new_file)
        self.toolbar.addSeparator()
        self.toolbar.addAction(self.action_save)
        self.toolbar.addAction(self.action_save_as)
        self.toolbar.addSeparator()
        self.toolbar.addAction(self.action_compile)

        menu_file = self.menuBar().addMenu("File")
        menu_file.addAction(self.action_open_folder)
        menu_file.addAction(self.action_open_file)
        menu_file.addAction(self.action_new_file)
        menu_file.addSeparator()
        menu_file.addAction(self.action_save)
        menu_file.addAction(self.action_save_as)
        menu_file.addSeparator()
        menu_file.addAction("Exit", self.close)

        menu_build = self.menuBar().addMenu("Build")
        menu_build.addAction(self.action_compile)

    def open_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Open Project Folder")
        if not folder:
            return
        self.set_project_root(folder)

    def set_project_root(self, folder: str) -> None:
        self.project_root = folder
        root_index = self.fs_model.setRootPath(folder)
        self.tree.setRootIndex(root_index)
        self.status.showMessage(f"Project: {folder}", 5000)

    def _on_tree_double_clicked(self, index: QModelIndex) -> None:
        if not index.isValid():
            return
        path = self.fs_model.filePath(index)
        if os.path.isdir(path):
            return
        self.open_file(path)

    def current_tab(self) -> Optional[EditorTab]:
        w = self.tabs.currentWidget()
        if isinstance(w, EditorTab):
            return w
        return None

    def open_file_dialog(self) -> None:
        start_dir = self.project_root or os.getcwd()
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Open File",
            start_dir,
            "Web Files (*.html *.css *.js)",
        )
        if not file_path:
            return
        self.open_file(file_path)

    def open_file(self, file_path: str) -> None:
        if not is_allowed_file(file_path):
            QMessageBox.warning(self, "Unsupported file", "ByHunIDE supports only HTML, CSS and JS.")
            return

        for i in range(self.tabs.count()):
            w = self.tabs.widget(i)
            if isinstance(w, EditorTab) and w.file_path == file_path:
                self.tabs.setCurrentIndex(i)
                return

        tab = EditorTab(file_path, self)
        tab.load_from_disk()
        name = os.path.basename(file_path)
        self.tabs.addTab(tab, name)
        self.tabs.setCurrentWidget(tab)

    def _confirm_discard_if_modified(self, tab: EditorTab) -> bool:
        if not tab.is_modified():
            return True

        resp = QMessageBox.question(
            self,
            "Unsaved changes",
            "You have unsaved changes. Save now?",
            QMessageBox.StandardButton.Yes
            | QMessageBox.StandardButton.No
            | QMessageBox.StandardButton.Cancel,
        )

        if resp == QMessageBox.StandardButton.Cancel:
            return False
        if resp == QMessageBox.StandardButton.Yes:
            return self._save_tab(tab)
        return True

    def _close_tab(self, index: int) -> None:
        w = self.tabs.widget(index)
        if not isinstance(w, EditorTab):
            self.tabs.removeTab(index)
            return
        if not self._confirm_discard_if_modified(w):
            return
        self.tabs.removeTab(index)

    def new_file(self) -> None:
        if not self.project_root:
            QMessageBox.information(self, "Project", "Open a project folder first.")
            return

        name, ok = QInputDialog.getText(self, "New File", "File name (e.g. index.html):")
        if not ok or not name.strip():
            return
        name = name.strip()

        _, ext = os.path.splitext(name)
        if ext.lower() not in ALLOWED_EXTENSIONS:
            QMessageBox.warning(self, "Invalid extension", "Use only .html, .css or .js")
            return

        full_path = os.path.join(self.project_root, name)
        if os.path.exists(full_path):
            QMessageBox.warning(self, "Already exists", "A file with this name already exists.")
            return

        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "w", encoding="utf-8") as f:
            f.write("")
        self.open_file(full_path)

    def _save_tab(self, tab: EditorTab) -> bool:
        if tab.file_path is None:
            return self.save_current_as()
        try:
            tab.save_to_disk()
            self.status.showMessage("Saved.", 2000)
            return True
        except Exception as e:
            QMessageBox.critical(self, "Save error", str(e))
            return False

    def save_current(self) -> None:
        tab = self.current_tab()
        if not tab:
            return
        self._save_tab(tab)

    def save_current_as(self) -> bool:
        tab = self.current_tab()
        if not tab:
            return False

        start_dir = self.project_root or os.getcwd()
        file_path, _ = QFileDialog.getSaveFileName(
            self,
            "Save As",
            start_dir,
            "Web Files (*.html *.css *.js)",
        )
        if not file_path:
            return False
        if not is_allowed_file(file_path):
            QMessageBox.warning(self, "Unsupported file", "ByHunIDE supports only HTML, CSS and JS.")
            return False

        tab.set_file_path(file_path)
        self.tabs.setTabText(self.tabs.currentIndex(), os.path.basename(file_path))
        return self._save_tab(tab)

    def build_project(self) -> None:
        if not self.project_root:
            QMessageBox.information(self, "Project", "Open a project folder first.")
            return

        out_path, _ = QFileDialog.getSaveFileName(
            self,
            "Save Build (ZIP)",
            os.path.join(self.project_root, "build.zip"),
            "ZIP (*.zip)",
        )
        if not out_path:
            return
        if not out_path.lower().endswith(".zip"):
            out_path += ".zip"

        try:
            compile_project(self.project_root, out_path)
            QMessageBox.information(self, "Build complete", f"Build saved to:\n{out_path}")
        except Exception as e:
            QMessageBox.critical(self, "Build error", str(e))
