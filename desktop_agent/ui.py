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
    QMessageBox,
)
from PySide6.QtGui import QIntValidator
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
                font-weight: bold;
                color: #111827;
            }

            QLabel#subtitle {
                color: #6B7280;
            }

            QLabel#status {
                color: #16A34A;
                font-weight: bold;
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
                font-weight: bold;
                min-height: 34px;
            }

            QPushButton:hover {
                background: #1D4ED8;
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
        row.addWidget(QLabel("Pairing Code"))

        self.code_input = QLineEdit()
        self.code_input.setPlaceholderText("Enter 6-digit code")
        self.code_input.setMaxLength(6)
        self.code_input.setValidator(QIntValidator(0, 999999, self))
        self.code_input.returnPressed.connect(self.pair_device)

        row.addWidget(self.code_input)

        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.pair_device)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(row)
        layout.addWidget(self.connect_btn)
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

        layout.addWidget(title)
        layout.addWidget(status)
        layout.addWidget(QLabel("Device: Ishaan-PC"))
        layout.addWidget(QLabel("Status: Online"))
        layout.addWidget(QLabel("Running in background"))

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.setObjectName("disconnect")
        disconnect_btn.clicked.connect(self.disconnect)

        layout.addWidget(disconnect_btn)
        layout.addStretch()

        return page

    def show_error(self, message):
        QMessageBox.warning(self, "Validation Error", message)

    def pair_device(self):
        code = self.code_input.text().strip()

        if not code:
            self.show_error("Please enter the pairing code.")
            return

        if len(code) != 6:
            self.show_error("Pairing code must contain exactly 6 digits.")
            return

        self.connect_btn.setEnabled(False)

        print(f"Pairing Code: {code}")

        # TODO: Call backend API here

        self.stack.setCurrentIndex(1)
        self.connect_btn.setEnabled(True)

    def disconnect(self):
        self.code_input.clear()
        self.code_input.setFocus()
        self.stack.setCurrentIndex(0)


app = QApplication([])

window = MainWindow()
window.show()

app.exec()