from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QLabel,
    QVBoxLayout,
    QHBoxLayout,
    QLineEdit,
    QPushButton,
    QStackedWidget,
)
from PySide6.QtCore import Qt


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("RemoteHub Agent")
        self.setFixedSize(420, 260)

        self.stack = QStackedWidget()
        self.stack.addWidget(self.create_pair_page())
        self.stack.addWidget(self.create_connected_page())

        self.setCentralWidget(self.stack)

        self.setStyleSheet("""
            QMainWindow {
                background: #F6F8FA;
            }

            QWidget {
                font-size: 13px;
                color: #24292F;
            }

            QLabel#title {
                font-size: 22px;
                font-weight: 700;
                color: #111827;
            }

            QLabel#subtitle {
                color: #6B7280;
                font-size: 13px;
            }

            QLabel#status {
                color: #16A34A;
                font-weight: 600;
                font-size: 14px;
            }

            QLineEdit {
                padding: 8px;
                border: 1px solid #D0D7DE;
                border-radius: 6px;
                background: white;
            }

            QLineEdit:focus {
                border: 2px solid #2563EB;
            }

            QPushButton {
                background: #2563EB;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 8px;
                font-weight: 600;
                min-height: 34px;
            }

            QPushButton:hover {
                background: #1D4ED8;
            }

            QPushButton:pressed {
                background: #1E40AF;
            }

            QPushButton#disconnect {
                background: #DC2626;
            }

            QPushButton#disconnect:hover {
                background: #B91C1C;
            }
        """)

    def create_pair_page(self):
        page = QWidget()

        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(14)

        title = QLabel("RemoteHub Agent")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        subtitle = QLabel("Pair your computer")
        subtitle.setObjectName("subtitle")

        row = QHBoxLayout()
        row.setSpacing(10)

        row.addWidget(QLabel("Pairing Code"))

        self.line_edit = QLineEdit()
        self.line_edit.setPlaceholderText("Enter 6-digit code")
        row.addWidget(self.line_edit)

        connect_btn = QPushButton("Connect")
        connect_btn.clicked.connect(self.connect)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(row)
        layout.addSpacing(6)
        layout.addWidget(connect_btn)
        layout.addStretch()

        return page

    def create_connected_page(self):
        page = QWidget()

        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        title = QLabel("RemoteHub Agent")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        status = QLabel("● Connected")
        status.setObjectName("status")

        device = QLabel("Device: Ishaan-PC")
        online = QLabel("Status: Online")
        background = QLabel("Running in background")

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.setObjectName("disconnect")
        disconnect_btn.clicked.connect(self.disconnect)

        layout.addWidget(title)
        layout.addWidget(status)
        layout.addWidget(device)
        layout.addWidget(online)
        layout.addWidget(background)
        layout.addSpacing(8)
        layout.addWidget(disconnect_btn)
        layout.addStretch()

        return page

    def connect(self):
        print("Pairing Code:", self.line_edit.text())
        self.stack.setCurrentIndex(1)

    def disconnect(self):
        self.line_edit.clear()
        self.stack.setCurrentIndex(0)


app = QApplication([])

window = MainWindow()
window.show()

app.exec()