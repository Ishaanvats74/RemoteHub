from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget


class PairPage(QWidget):
    generate_requested = Signal()
    decision_requested = Signal(bool)

    def __init__(self):
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        title = QLabel("Pair this laptop")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        self.code = QLabel()
        self.code.setObjectName("pairingCode")
        self.code.setAlignment(Qt.AlignCenter)
        self.code.setTextInteractionFlags(Qt.TextSelectableByMouse)

        self.message = QLabel()
        self.message.setTextFormat(Qt.PlainText)
        self.message.setWordWrap(True)
        self.message.setAlignment(Qt.AlignCenter)

        self.approve = QPushButton("Approve")
        self.approve.clicked.connect(lambda: self.decision_requested.emit(True))
        self.decline = QPushButton("Decline")
        self.decline.setObjectName("secondary")
        self.decline.clicked.connect(lambda: self.decision_requested.emit(False))
        self.generate = QPushButton("Generate new code")
        self.generate.clicked.connect(self.generate_requested.emit)

        actions = QHBoxLayout()
        actions.addWidget(self.decline)
        actions.addWidget(self.approve)
        layout.addWidget(title)
        layout.addWidget(self.code)
        layout.addWidget(self.message)
        layout.addLayout(actions)
        layout.addWidget(self.generate)
        self.show_state("Preparing pairing...")

    def show_state(self, message, *, code=None, approval=False, retry=False):
        self.message.setText(message)
        self.code.setText(code or "")
        self.code.setVisible(code is not None)
        self.approve.setVisible(approval)
        self.decline.setVisible(approval)
        self.generate.setVisible(retry)

    def set_decision_enabled(self, enabled):
        self.approve.setEnabled(enabled)
        self.decline.setEnabled(enabled)
