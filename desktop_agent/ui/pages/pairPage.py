from PySide6.QtWidgets import (
    QWidget,
    QLabel,
    QVBoxLayout,
    QHBoxLayout,
    QLineEdit,
    QPushButton,
    QMessageBox,
)
from PySide6.QtGui import QIntValidator
from PySide6.QtCore import Qt, Signal


class PairPage(QWidget):
    # Emitted when the user enters a valid pairing code
    pair_requested = Signal(str)

    def __init__(self):
        super().__init__()

        layout = QVBoxLayout(self)
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
        self.code_input.returnPressed.connect(self.on_connect_clicked)

        row.addWidget(self.code_input)

        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.on_connect_clicked)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(row)
        layout.addWidget(self.connect_btn)
        layout.addStretch()

    def on_connect_clicked(self):
        code = self.code_input.text().strip()

        if not code:
            QMessageBox.warning(
                self,
                "Validation Error",
                "Please enter the pairing code.",
            )
            return

        if len(code) != 6:
            QMessageBox.warning(
                self,
                "Validation Error",
                "Pairing code must contain exactly 6 digits.",
            )
            return

        # Disable UI while controller processes pairing
        self.set_loading(True)

        # Notify the controller
        self.pair_requested.emit(code)

    def set_loading(self, loading: bool):
        """Enable/Disable the page while pairing."""

        self.connect_btn.setEnabled(not loading)
        self.code_input.setEnabled(not loading)

        if loading:
            self.connect_btn.setText("Connecting...")
        else:
            self.connect_btn.setText("Connect")

    def clear_code(self):
        self.code_input.clear()

    def focus_input(self):
        self.code_input.setFocus()