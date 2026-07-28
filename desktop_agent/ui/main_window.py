from .pages.pairPage import PairPage
from .pages.connectedPage import ConnectedPage
from pathlib import Path
from PySide6.QtWidgets import QMainWindow,QStackedWidget

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.stack = QStackedWidget()

        self.stylesheet_path = Path("stylesheet.css")

        self.setWindowTitle("RemoteHub Agent")
        self.setFixedSize(420, 260)

        self.pair_page = PairPage()
        self.connected_page = ConnectedPage()

        self.stack.addWidget(self.pair_page)
        self.stack.addWidget(self.connected_page)

        self.setCentralWidget(self.stack)
        self.setStyleSheet(self.stylesheet_path.read_text())

    def show_pair_page(self):
        print("Switching to pair page")
        self.stack.setCurrentWidget(self.pair_page)

    def show_connected_page(self):
        print("Switching to connected page")
        self.stack.setCurrentWidget(self.connected_page)
