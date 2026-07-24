from PySide6.QtWidgets import QWidget,QLabel,QVBoxLayout,QHBoxLayout,QLineEdit,QPushButton
from PySide6.QtGui import QIntValidator
from PySide6.QtCore import Qt


class PairPage(QWidget):
    def __init__(self,controller):
        super().__init__()
        self.controller = controller

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
        self.code_input.returnPressed.connect(self.pair_device)

        row.addWidget(self.code_input)

        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.pair_device)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(row)
        layout.addWidget(self.connect_btn)
        layout.addStretch()

    def pair_device(self):
        code = self.code_input.text().strip()
        
        if not code:
            self.controller.show_error("Please enter the pairing code.")
            return

        if len(code) != 6:
            self.controller.show_error("Pairing code must contain exactly 6 digits.")
            return

        self.connect_btn.setEnabled(False)
        self.controller.pair_device(code)
        self.connect_btn.setEnabled(True)
