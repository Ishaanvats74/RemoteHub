from .pages.pairPage import PairPage
from .pages.connectedPage import ConnectedPage
from pathlib import Path
from PySide6.QtWidgets import QMainWindow,QStackedWidget

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.stack = QStackedWidget()

        self.stylesheet_path = Path(__file__).resolve().parents[1] / "stylesheet.css"

        self.setWindowTitle("RemoteHub Agent")
        self.setMinimumSize(420, 280)
        self.resize(460, 320)

        self.pair_page = PairPage()
        self.connected_page = ConnectedPage()

        self.stack.addWidget(self.pair_page)
        self.stack.addWidget(self.connected_page)

        self.setCentralWidget(self.stack)
        self.setStyleSheet(self.stylesheet_path.read_text(encoding="utf-8"))

    def show_pair_page(self):
        self.stack.setCurrentWidget(self.pair_page)

    def show_connected_page(self):
        self.stack.setCurrentWidget(self.connected_page)
